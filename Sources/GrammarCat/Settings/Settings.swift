import Foundation
import Carbon

/// All persisted user preferences, backed by `UserDefaults`.
///
/// Launch-at-login is intentionally *not* stored here — that state is owned by
/// the system and is queried/changed through `LoginItem`.
enum Settings {
    private static let store = UserDefaults.standard

    /// Posted whenever any setting changes.
    static let didChange = Notification.Name("GrammarCatSettingsDidChange")

    private enum Key {
        static let writeToNote = "writeToNote"
        static let noteBaseDir = "noteBaseDir"
        static let hotKeyCode = "hotKeyCode"
        static let hotKeyModifiers = "hotKeyModifiers"
        static let hotKeyDisplay = "hotKeyDisplay"
        static let autoPaste = "autoPaste"
        static let showFloatingButton = "showFloatingButton"
    }

    /// Default daily-note folder: `~/Documents/Notes/Daily/Journal`.
    static var defaultNoteBaseDirectory: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/Notes/Daily/Journal").path
    }

    static func registerDefaults() {
        store.register(defaults: [
            Key.writeToNote: true,
            Key.noteBaseDir: defaultNoteBaseDirectory,
            Key.hotKeyCode: kVK_ANSI_I,
            Key.hotKeyModifiers: cmdKey | shiftKey,
            Key.hotKeyDisplay: "⌘⇧I",
            Key.autoPaste: true,
            Key.showFloatingButton: true,
        ])
    }

    // MARK: - Daily note

    static var writeToNote: Bool {
        get { store.bool(forKey: Key.writeToNote) }
        set { store.set(newValue, forKey: Key.writeToNote); notifyChange() }
    }

    static var noteBaseDirectory: String {
        get { store.string(forKey: Key.noteBaseDir) ?? defaultNoteBaseDirectory }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            store.set(trimmed.isEmpty ? defaultNoteBaseDirectory : trimmed,
                      forKey: Key.noteBaseDir)
            notifyChange()
        }
    }

    // MARK: - Hotkey (Carbon key code + Carbon modifier mask)

    static var hotKeyCode: Int { store.integer(forKey: Key.hotKeyCode) }
    static var hotKeyModifiers: Int { store.integer(forKey: Key.hotKeyModifiers) }
    static var hotKeyDisplay: String { store.string(forKey: Key.hotKeyDisplay) ?? "⌘⇧I" }

    static func setHotKey(code: Int, modifiers: Int, display: String) {
        store.set(code, forKey: Key.hotKeyCode)
        store.set(modifiers, forKey: Key.hotKeyModifiers)
        store.set(display, forKey: Key.hotKeyDisplay)
        notifyChange()
    }

    // MARK: - Behaviour

    static var autoPaste: Bool {
        get { store.bool(forKey: Key.autoPaste) }
        set { store.set(newValue, forKey: Key.autoPaste); notifyChange() }
    }

    static var showFloatingButton: Bool {
        get { store.bool(forKey: Key.showFloatingButton) }
        set { store.set(newValue, forKey: Key.showFloatingButton); notifyChange() }
    }

    private static func notifyChange() {
        NotificationCenter.default.post(name: didChange, object: nil)
    }
}
