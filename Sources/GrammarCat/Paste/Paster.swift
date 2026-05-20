import AppKit
import Carbon
import CoreGraphics

/// Delivers corrected text to the previously-focused app.
///
/// The corrected text is left on the clipboard afterwards (no restore) — a
/// restore would race with the paste and risk pasting stale content.
enum Paster {
    /// Places `text` on the general pasteboard, replacing its contents.
    static func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Copies `text` to the pasteboard, re-activates `app`, then synthesises ⌘V.
    /// Requires Accessibility permission for the synthetic key events.
    static func paste(_ text: String, into app: NSRunningApplication?) {
        copyToClipboard(text)

        if let app, !app.isTerminated {
            _ = app.activate(options: [])
        }

        // Give the target app a moment to come forward before pasting.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            sendCommandV()
        }
    }

    private static func sendCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey = CGKeyCode(kVK_ANSI_V)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
