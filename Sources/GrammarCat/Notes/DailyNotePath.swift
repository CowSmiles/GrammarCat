import Foundation

/// Resolves the Obsidian daily-note file for a given date.
///
/// Layout: `<base folder>/<YYYY>/<YYYY-MM-DD>.md`, where the base folder is
/// configurable in Settings (default `~/Documents/Notes/Daily/Journal`).
enum DailyNotePath {
    static func url(for date: Date = Date()) -> URL {
        let base = URL(fileURLWithPath: Settings.noteBaseDirectory, isDirectory: true)
        return base
            .appendingPathComponent(string(from: date, format: "yyyy"), isDirectory: true)
            .appendingPathComponent(string(from: date, format: "yyyy-MM-dd") + ".md")
    }

    /// One reusable, locale-independent formatter — `DateFormatter` is
    /// expensive to allocate, and note writes happen on a single queue.
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        return formatter
    }()

    static func string(from date: Date, format: String) -> String {
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
