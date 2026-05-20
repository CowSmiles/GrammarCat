import Foundation

/// One file/folder candidate for `@`-mention completion.
struct PathCandidate {
    let displayName: String   // entry name, with a trailing "/" for directories
    let absolutePath: String  // fully resolved absolute path
    let isDirectory: Bool
}

/// The `@`-token currently under the caret.
struct ATokenContext {
    let tokenRange: NSRange   // UTF-16 range of "@…" in the text view's string
    let query: String         // the text after "@", up to the caret
}

/// Pure logic for `@`-mention path completion: token detection, path
/// resolution, and filesystem matching. No UI, no AppKit.
enum PathCompletionEngine {
    /// Base for queries that are neither absolute (`/…`) nor home (`~/…`).
    static let baseDirectory = "~/code"

    /// Cap on candidates returned for one query (the list scrolls anyway).
    private static let maxCandidates = 200

    private static let atSign = ("@" as NSString).character(at: 0)

    // MARK: - Token detection

    /// Finds an active `@`-token ending exactly at `caret` (a UTF-16 offset),
    /// or nil if the caret is not inside one.
    static func activeToken(in text: String, caret: Int) -> ATokenContext? {
        let ns = text as NSString
        guard caret >= 0, caret <= ns.length else { return nil }

        // Walk back from the caret over non-whitespace characters.
        var start = caret
        while start > 0, !isBoundary(ns.character(at: start - 1)) {
            start -= 1
        }
        // The run must begin with '@'…
        guard start < caret, ns.character(at: start) == atSign else { return nil }
        // …and that '@' must be at text start or right after whitespace
        // (so email addresses like `foo@bar` don't trigger completion).
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
            base = NSString(string: "~").expandingTildeInPath
            pathPart = query.hasPrefix("~/") ? String(query.dropFirst(2)) : ""
        } else {
            base = NSString(string: baseDirectory).expandingTildeInPath
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

    // MARK: - Matching

    /// Files and folders matching `query`, directories first.
    static func candidates(for query: String) -> [PathCandidate] {
        let (directory, partial) = resolve(query: query)
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else {
            return []
        }

        let wantsHidden = partial.hasPrefix(".")
        let lowerPartial = partial.lowercased()

        let matched = entries.compactMap { url -> PathCandidate? in
            let name = url.lastPathComponent
            if name.hasPrefix(".") && !wantsHidden { return nil }
            if !lowerPartial.isEmpty && !name.lowercased().hasPrefix(lowerPartial) { return nil }
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            return PathCandidate(
                displayName: isDir ? name + "/" : name,
                absolutePath: url.standardizedFileURL.path,
                isDirectory: isDir
            )
        }.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }

        return Array(matched.prefix(maxCandidates))
    }

    // MARK: - Acceptance

    /// The text to replace the whole `@`-token with, and whether the list
    /// should stay open afterwards (true when drilling into a directory).
    static func acceptance(of candidate: PathCandidate) -> (replacement: String, keepListOpen: Bool) {
        let path = candidate.isDirectory ? candidate.absolutePath + "/" : candidate.absolutePath
        return ("@" + path, candidate.isDirectory)
    }
}
