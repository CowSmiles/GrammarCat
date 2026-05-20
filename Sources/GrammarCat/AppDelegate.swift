import AppKit

/// Owns every long-lived component and wires the submit flow together.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let focusTracker = FocusTracker()
    private let hotkey = HotkeyManager()
    private var popup: PopupWindow!
    private var floatingButton: FloatingButton!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // A real Edit menu so ⌘C/⌘V/⌘X/⌘A/⌘Z work inside the popup's text view.
        AppMenu.install()

        // Ask for Accessibility permission up front (needed for auto-paste).
        AccessibilityGate.ensure(prompt: true)

        focusTracker.start()

        popup = PopupWindow()
        popup.onSubmit = { [weak self] text in self?.handleSubmit(text) }
        popup.onCancel = { [weak self] in self?.hidePopup() }

        floatingButton = FloatingButton()
        floatingButton.onClick = { [weak self] in self?.togglePopup() }
        floatingButton.show()

        hotkey.onTrigger = { [weak self] in self?.togglePopup() }
        hotkey.register()
    }

    // MARK: - Popup control

    private func togglePopup() {
        if popup.isVisible {
            hidePopup()
        } else {
            showPopup()
        }
    }

    private func showPopup() {
        // Capture the app to return to *before* our popup steals focus.
        focusTracker.capture()
        popup.present()
    }

    private func hidePopup() {
        popup.orderOut(nil)
        focusTracker.restore()
    }

    // MARK: - Submit flow

    private func handleSubmit(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        popup.orderOut(nil)

        guard !trimmed.isEmpty else {
            focusTracker.restore()
            return
        }

        // Always log to the daily note, regardless of paste permission.
        DispatchQueue.global(qos: .utility).async {
            do {
                try NoteWriter.append(trimmed)
            } catch {
                NSLog("GrammarCat: note append failed — \(error)")
            }
        }

        if AccessibilityGate.isTrusted {
            // Paster re-activates the previous app, then synthesises ⌘V.
            Paster.paste(trimmed, into: focusTracker.previousApp)
        } else {
            focusTracker.restore()
            AccessibilityGate.ensure(prompt: true)
        }

        popup.clearEditor()
    }
}
