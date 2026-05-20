import Foundation

/// Resolves the Obsidian daily-note file for a given date.
///
/// Layout: `~/Documents/Notes/Daily/Journal/<YYYY>/<YYYY-MM-DD>.md`
enum DailyNotePath {
    /// Base directory, relative to the user's home directory.
    static let baseDirectory = "Documents/Notes/Daily/Journal"

    static func url(for date: Date = Date()) -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent(baseDirectory, isDirectory: true)
            .appendingPathComponent(string(from: date, format: "yyyy"), isDirectory: true)
            .appendingPathComponent(string(from: date, format: "yyyy-MM-dd") + ".md")
    }

    /// Formats `date` with a fixed, locale-independent formatter.
    static func string(from date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
