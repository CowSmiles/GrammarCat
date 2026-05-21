import Foundation

/// One file/folder candidate for `@`-mention completion.
struct PathCandidate: Equatable {
    /// Entry name (flat search) or path relative to the search root (recursive
    /// search); a trailing "/" marks a directory.
    let displayName: String
    let absolutePath: String
    let isDirectory: Bool
}

/// The `@`-token currently under the caret.
struct ATokenContext {
    let tokenRange: NSRange
    let query: String
}

/// One entry from a recursive project walk — cached once, then re-filtered in
/// memory on each keystroke. `lowerName` and `depth` are precomputed by the
/// walk so the re-filter does no per-entry string work.
struct RecursiveEntry {
    let relativePath: String
    let isDirectory: Bool
    let lowerName: String   // lowercased last path component
    let depth: Int          // count of "/" in relativePath
}

/// How a query should be searched, decided from the query string alone.
enum SearchMode {
    case flat(directory: URL, partial: String)
    case recursive(root: URL, nameTerm: String)
}

/// Pure logic for `@`-mention path completion: token detection, path
/// resolution, and filesystem matching. No UI, no AppKit.
enum PathCompletionEngine {
    /// Base for queries that are neither absolute (`/…`) nor home (`~/…`).
    static let baseDirectory = "~/code"
    /// `baseDirectory` with `~` expanded — resolved once.
    private static let expandedBase = NSString(string: baseDirectory).expandingTildeInPath

    private static let maxCandidates = 200
    private static let maxRecursiveEntries = 20_000
    private static let atSign = ("@" as NSString).character(at: 0)

    /// Non-hidden directories never worth walking into. Hidden (dot)
    /// directories are excluded separately via `.skipsHiddenFiles`.
    static let ignoredDirectoryNames: Set<String> = [
        "node_modules", "build", "dist", "target", "DerivedData",
        "Pods", "__pycache__", "venv", "vendor",
    ]

    // MARK: - Token detection

    /// Finds an active `@`-token ending exactly at `caret` (a UTF-16 offset).
    static func activeToken(in text: String, caret: Int) -> ATokenContext? {
        let ns = text as NSString
        guard caret >= 0, caret <= ns.length else { return nil }

        var start = caret
        while start > 0, !isBoundary(ns.character(at: start - 1)) {
            start -= 1
        }
        guard start < caret, ns.character(at: start) == atSign else { return nil }
        // The '@' must be at text start or right after whitespace (so email
        // addresses like `foo@bar` don't trigger completion).
        if start > 0, !isBoundary(ns.character(at: start - 1)) { return nil }

        return ATokenContext(
            tokenRange: NSRange(location: start, length: caret - start),
            query: ns.substring(with: NSRange(location: start + 1, length: caret - start - 1))
        )
    }

    private static func isBoundary(_ ch: unichar) -> Bool {
        guard let scalar = Unicode.Scalar(ch) else { return true }
        return CharacterSet.whitespacesAndNewlines.contains(scalar)
    }

    // MARK: - Path resolution

    /// Splits a query into the directory to list and the partial last segment.
    static func resolve(query: String) -> (directory: URL, partialSegment: String) {
        let base: String
        let pathPart: String
        if query.hasPrefix("/") {
            base = "/"
            pathPart = String(query.dropFirst())
        } else if query.hasPrefix("~/") || query == "~" {
            base = NSHomeDirectory()
            pathPart = query.hasPrefix("~/") ? String(query.dropFirst(2)) : ""
        } else {
            base = expandedBase
            pathPart = query
        }

        let segments = pathPart.components(separatedBy: "/")
        let partial = segments.last ?? ""
        var directory = URL(fileURLWithPath: base, isDirectory: true)
        for segment in segments.dropLast() where !segment.isEmpty {
            directory.appendPathComponent(segment)
        }
        return (directory.standardizedFileURL, partial)
    }

    /// Decides flat vs recursive search. Recursive only for a `~/code`-relative
    /// query that names a subdirectory (contains a `/`) and stays inside
    /// `~/code` — recursing an arbitrary root would be unbounded.
    static func searchMode(for query: String) -> SearchMode {
        let (directory, partial) = resolve(query: query)
        let isRelativeToBase = !query.hasPrefix("/") && !query.hasPrefix("~")
        let withinBase = directory.path == expandedBase
            || directory.path.hasPrefix(expandedBase + "/")

        if isRelativeToBase, query.contains("/"), withinBase {
            return .recursive(root: directory, nameTerm: partial)
        }
        return .flat(directory: directory, partial: partial)
    }

    // MARK: - Candidate construction

    /// Builds a candidate, applying the trailing-"/" display convention for
    /// directories. `displayBase` is the entry name (flat search) or the
    /// root-relative path (recursive search).
    private static func makeCandidate(displayBase: String,
                                      absolutePath: String,
                                      isDirectory: Bool) -> PathCandidate {
        PathCandidate(
            displayName: isDirectory ? displayBase + "/" : displayBase,
            absolutePath: absolutePath,
            isDirectory: isDirectory)
    }

    // MARK: - Flat matching (immediate children)

    static func flatCandidates(directory: URL, partial: String) -> [PathCandidate] {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else {
            return []
        }

        let wantsHidden = partial.hasPrefix(".")
        let lowerPartial = partial.lowercased()

        return entries.compactMap { url -> PathCandidate? in
            let name = url.lastPathComponent
            if name.hasPrefix(".") && !wantsHidden { return nil }
            if !lowerPartial.isEmpty && !name.lowercased().hasPrefix(lowerPartial) { return nil }
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            return makeCandidate(displayBase: name,
                                 absolutePath: url.standardizedFileURL.path,
                                 isDirectory: isDir)
        }.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    // MARK: - Recursive walk + ranking

    /// Walks `root` once, pruning hidden and known-junk directories. Returns
    /// every surviving entry (NOT name-filtered) so the result can be cached.
    /// Polls `isCancelled` periodically and stops early when it returns true.
    static func recursiveWalk(root: URL, isCancelled: () -> Bool) -> [RecursiveEntry] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else {
            return []
        }

        let rootPath = root.standardizedFileURL.path
        var entries: [RecursiveEntry] = []
        var visited = 0

        for case let url as URL in enumerator {
            visited += 1
            if visited & 0xFF == 0, isCancelled() { break }

            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir, ignoredDirectoryNames.contains(url.lastPathComponent) {
                enumerator.skipDescendants()
                continue
            }
            // The enumerator started from a standardized root, so `url.path`
            // is already normalized — no need to re-standardize per entry.
            let relative = relativePath(of: url.path, under: rootPath)
            entries.append(RecursiveEntry(
                relativePath: relative,
                isDirectory: isDir,
                lowerName: (relative as NSString).lastPathComponent.lowercased(),
                depth: relative.reduce(0) { $1 == "/" ? $0 + 1 : $0 }
            ))
            if entries.count >= maxRecursiveEntries { break }
        }
        return entries
    }

    private static func relativePath(of absolute: String, under root: String) -> String {
        let prefix = root + "/"
        return absolute.hasPrefix(prefix) ? String(absolute.dropFirst(prefix.count)) : absolute
    }

    /// Filters and ranks cached entries by `nameTerm` (matched against each
    /// entry's last path component). Pure and synchronous — no I/O, and no
    /// per-entry string work, since `lowerName`/`depth` were precomputed by the
    /// walk. Tiers: exact → prefix → substring; within a tier, shallower →
    /// directories first → path.
    static func rankedCandidates(from entries: [RecursiveEntry],
                                 nameTerm: String,
                                 root: URL) -> [PathCandidate] {
        let term = nameTerm.lowercased()

        let scored = entries.compactMap { entry -> (entry: RecursiveEntry, tier: Int)? in
            let tier: Int
            if term.isEmpty || entry.lowerName == term {
                tier = 0
            } else if entry.lowerName.hasPrefix(term) {
                tier = 1
            } else if entry.lowerName.contains(term) {
                tier = 2
            } else {
                return nil
            }
            return (entry, tier)
        }.sorted { lhs, rhs in
            if lhs.tier != rhs.tier { return lhs.tier < rhs.tier }
            if lhs.entry.depth != rhs.entry.depth { return lhs.entry.depth < rhs.entry.depth }
            if lhs.entry.isDirectory != rhs.entry.isDirectory { return lhs.entry.isDirectory }
            return lhs.entry.relativePath < rhs.entry.relativePath
        }

        let rootPath = root.standardizedFileURL.path
        return scored.prefix(maxCandidates).map { item in
            makeCandidate(displayBase: item.entry.relativePath,
                          absolutePath: rootPath + "/" + item.entry.relativePath,
                          isDirectory: item.entry.isDirectory)
        }
    }

    // MARK: - Acceptance

    /// The text to replace the whole `@`-token with, and whether the list
    /// should stay open afterwards (true when drilling into a directory).
    static func acceptance(of candidate: PathCandidate) -> (replacement: String, keepListOpen: Bool) {
        let path = candidate.isDirectory ? candidate.absolutePath + "/" : candidate.absolutePath
        return ("@" + path, candidate.isDirectory)
    }
}
