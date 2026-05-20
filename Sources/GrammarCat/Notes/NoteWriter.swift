import Foundation

/// Appends submitted text to the day's Obsidian note, creating a minimal note
/// file first if one does not exist yet.
enum NoteWriter {
    /// Appends `text` to the end of today's (or `date`'s) daily note.
    static func append(_ text: String, for date: Date = Date()) throws {
        let entry = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !entry.isEmpty else { return }

        let url = DailyNotePath.url(for: date)
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try minimalNote(for: date).write(to: url, atomically: true, encoding: .utf8)
        }

        var content = try String(contentsOf: url, encoding: .utf8)
        // Drop trailing newlines so the entry lands on the next line exactly —
        // no blank-line gap, and no doubling when the file already ends in \n\n.
        while content.hasSuffix("\n") {
            content.removeLast()
        }
        content += "\n" + entry + "\n"

        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    /// A minimal note matching the user's Obsidian frontmatter format.
    private static func minimalNote(for date: Date) -> String {
        let ymd = DailyNotePath.string(from: date, format: "yyyy-MM-dd")
        let weekday = DailyNotePath.string(from: date, format: "EEEE")

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        iso.timeZone = TimeZone.current
        let timestamp = iso.string(from: date)

        return """
        ---
        title: "\(ymd)"
        date: \(timestamp)
        tags: daily
        ---

        # \(ymd), \(weekday)

        """
    }
}
