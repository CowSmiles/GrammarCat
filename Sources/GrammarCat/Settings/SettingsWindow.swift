import AppKit

/// The Settings window — a small form bound live to `Settings`.
/// Every control writes its value the moment it changes.
final class SettingsWindow: NSWindow, NSTextFieldDelegate {
    private let writeToNoteCheck = NSButton(
        checkboxWithTitle: "Append submitted text to my daily note",
        target: nil, action: nil)
    private let notePathField = NSTextField()
    private let hotkeyField = HotkeyRecorderField()
    private let autoPasteCheck = NSButton(
        checkboxWithTitle: "Auto-paste into the previous app",
        target: nil, action: nil)
    private let showButtonCheck = NSButton(
        checkboxWithTitle: "Show the floating button",
        target: nil, action: nil)
    private let loginCheck = NSButton(
        checkboxWithTitle: "Launch GrammarCat at login",
        target: nil, action: nil)

    private var didPosition = false

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        title = "GrammarCat Settings"
        isReleasedWhenClosed = false
        buildLayout()
        wireActions()
    }

    /// Refreshes every control from current state, then shows the window.
    func present() {
        refresh()
        if !didPosition {
            center()
            didPosition = true
        }
        makeKeyAndOrderFront(nil)
    }

    // MARK: - Layout

    private func buildLayout() {
        notePathField.translatesAutoresizingMaskIntoConstraints = false
        notePathField.placeholderString = "Daily-note base folder"
        notePathField.widthAnchor.constraint(equalToConstant: 300).isActive = true

        let chooseButton = NSButton(title: "Choose…", target: self,
                                    action: #selector(chooseFolder))
        let pathRow = NSStackView(views: [notePathField, chooseButton])
        pathRow.orientation = .horizontal
        pathRow.spacing = 8

        let patternLabel = caption("Files are written to  <folder>/YYYY/YYYY-MM-DD.md")

        hotkeyField.widthAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true

        let grid = NSGridView(views: [
            [rowLabel("Daily note:"), writeToNoteCheck],
            [NSGridCell.emptyContentView, pathRow],
            [NSGridCell.emptyContentView, patternLabel],
            [rowLabel("Hotkey:"), hotkeyField],
            [rowLabel("Behaviour:"), autoPasteCheck],
            [NSGridCell.emptyContentView, showButtonCheck],
            [NSGridCell.emptyContentView, loginCheck],
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 12
        grid.columnSpacing = 12
        grid.column(at: 0).xPlacement = .trailing
        grid.rowAlignment = .firstBaseline

        let host = NSView()
        host.addSubview(grid)
        let inset: CGFloat = 22
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: host.topAnchor, constant: inset),
            grid.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: inset),
            grid.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -inset),
            grid.bottomAnchor.constraint(equalTo: host.bottomAnchor, constant: -inset),
        ])
        contentView = host
        layoutIfNeeded()
        setContentSize(host.fittingSize)
    }

    private func rowLabel(_ text: String) -> NSTextField {
        NSTextField(labelWithString: text)
    }

    private func caption(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: 11)
        field.textColor = .secondaryLabelColor
        return field
    }

    // MARK: - Actions

    private func wireActions() {
        writeToNoteCheck.target = self
        writeToNoteCheck.action = #selector(toggleWriteToNote)
        autoPasteCheck.target = self
        autoPasteCheck.action = #selector(toggleAutoPaste)
        showButtonCheck.target = self
        showButtonCheck.action = #selector(toggleShowButton)
        loginCheck.target = self
        loginCheck.action = #selector(toggleLogin)
        notePathField.delegate = self
        hotkeyField.onCapture = { code, modifiers, display in
            Settings.setHotKey(code: code, modifiers: modifiers, display: display)
        }
    }

    private func refresh() {
        writeToNoteCheck.state = Settings.writeToNote ? .on : .off
        notePathField.stringValue = Settings.noteBaseDirectory
        hotkeyField.setDisplay(Settings.hotKeyDisplay)
        autoPasteCheck.state = Settings.autoPaste ? .on : .off
        showButtonCheck.state = Settings.showFloatingButton ? .on : .off
        loginCheck.state = LoginItem.isEnabled ? .on : .off
    }

    @objc private func toggleWriteToNote() {
        Settings.writeToNote = writeToNoteCheck.state == .on
    }

    @objc private func toggleAutoPaste() {
        Settings.autoPaste = autoPasteCheck.state == .on
    }

    @objc private func toggleShowButton() {
        Settings.showFloatingButton = showButtonCheck.state == .on
    }

    @objc private func toggleLogin() {
        let result = LoginItem.setEnabled(loginCheck.state == .on)
        loginCheck.state = result ? .on : .off
    }

    @objc private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.directoryURL = URL(fileURLWithPath: Settings.noteBaseDirectory)
        if panel.runModal() == .OK, let url = panel.url {
            Settings.noteBaseDirectory = url.path
            notePathField.stringValue = Settings.noteBaseDirectory
        }
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard (obj.object as? NSTextField) === notePathField else { return }
        Settings.noteBaseDirectory = notePathField.stringValue
        notePathField.stringValue = Settings.noteBaseDirectory
    }
}
