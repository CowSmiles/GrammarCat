import AppKit

/// Owns every long-lived component and wires the submit flow together.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let focusTracker = FocusTracker()
    private let hotkey = HotkeyManager()
    private var popup: PopupWindow!
    private var floatingButton: FloatingButton!
    private lazy var settingsWindow = SettingsWindow()

    private var appliedHotKey: (Int, Int)?
    private var appliedButtonVisible: Bool?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Settings.registerDefaults()

        // A real menu so ⌘C/⌘V/⌘X/⌘A/⌘Z work in the popup, and ⌘, opens Settings.
        AppMenu.install(settingsTarget: self)

        // Ask for Accessibility permission up front (needed for auto-paste).
        AccessibilityGate.ensure(prompt: true)

        focusTracker.start()

        popup = PopupWindow()
        popup.onSubmit = { [weak self] text in self?.handleSubmit(text) }
        popup.onCancel = { [weak self] in self?.hidePopup() }

        floatingButton = FloatingButton()
        floatingButton.onClick = { [weak self] in self?.togglePopup() }
        floatingButton.onShowSettings = { [weak self] in self?.openSettings(nil) }

        hotkey.onTrigger = { [weak self] in self?.togglePopup() }
        hotkey.register()

        NotificationCenter.default.addObserver(
            self, selector: #selector(applySettings),
            name: Settings.didChange, object: nil
        )

        applySettings()
    }

    // MARK: - Settings

    @objc func openSettings(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow.present()
    }

    /// Re-applies settings — but only the parts that actually changed, so
    /// toggling an unrelated setting doesn't tear down and re-register the
    /// global hotkey. (Note writing and auto-paste are read at submit time.)
    @objc private func applySettings() {
        let chord = (Settings.hotKeyCode, Settings.hotKeyModifiers)
        if appliedHotKey == nil || appliedHotKey! != chord {
            appliedHotKey = chord
            hotkey.reload()
        }
        if appliedButtonVisible != Settings.showFloatingButton {
            appliedButtonVisible = Settings.showFloatingButton
            floatingButton.setVisible(Settings.showFloatingButton)
        }
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

        if Settings.writeToNote {
            DispatchQueue.global(qos: .utility).async {
                do {
                    try NoteWriter.append(trimmed)
                } catch {
                    NSLog("GrammarCat: note append failed — \(error)")
                }
            }
        }

        if Settings.autoPaste {
            if AccessibilityGate.isTrusted {
                // Paster re-activates the previous app, then synthesises ⌘V.
                Paster.paste(trimmed, into: focusTracker.previousApp)
            } else {
                focusTracker.restore()
                AccessibilityGate.ensure(prompt: true)
            }
        } else {
            // Auto-paste off: just leave it on the clipboard for a manual ⌘V.
            Paster.copyToClipboard(trimmed)
            focusTracker.restore()
        }

        popup.clearEditor()
    }
}
