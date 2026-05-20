import AppKit

/// Remembers which app to return to after the popup closes.
final class FocusTracker {
    /// The app that was frontmost when the popup was opened.
    private(set) var previousApp: NSRunningApplication?

    /// Continuously-updated "last non-GrammarCat app" — a fallback for when
    /// the frontmost app at capture time is somehow GrammarCat itself.
    private var lastActiveApp: NSRunningApplication?

    func start() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        lastActiveApp = NSWorkspace.shared.frontmostApplication
    }

    /// Records the app to return to. Must be called the instant the popup is
    /// about to open — before GrammarCat steals focus.
    func capture() {
        if let front = NSWorkspace.shared.frontmostApplication, !isSelf(front) {
            previousApp = front
        } else {
            previousApp = lastActiveApp
        }
    }

    /// Brings the previously-frontmost app back to the foreground.
    func restore() {
        guard let app = previousApp, !isSelf(app), !app.isTerminated else { return }
        _ = app.activate(options: [])
    }

    @objc private func appActivated(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey]
            as? NSRunningApplication else { return }
        if !isSelf(app) {
            lastActiveApp = app
        }
    }

    private func isSelf(_ app: NSRunningApplication) -> Bool {
        app.processIdentifier == NSRunningApplication.current.processIdentifier
    }
}
