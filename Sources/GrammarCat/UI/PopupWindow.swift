import AppKit

/// The main popup: a titled `NSPanel` hosting the native text editor.
///
/// Unlike the floating button, this panel *does* activate GrammarCat and
/// become key — the text view must be first responder of the active app so
/// Grammarly Desktop attaches to it.
final class PopupWindow: NSPanel, NSWindowDelegate {
    private static let contentSize = NSSize(width: 540, height: 300)

    private let editor = EditorView(frame: NSRect(origin: .zero, size: PopupWindow.contentSize))
    private var didPosition = false

    /// Called with the editor's text when the user submits (⌘↩ or Send).
    var onSubmit: ((String) -> Void)?
    /// Called when the user cancels (esc or the close button).
    var onCancel: (() -> Void)?

    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.contentSize),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        title = "GrammarCat"
        isFloatingPanel = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        level = .floating
        minSize = NSSize(width: 380, height: 200)
        delegate = self
        contentView = editor

        editor.onSubmit = { [weak self] in
            guard let self else { return }
            self.onSubmit?(self.editor.currentText())
        }
        editor.onCancel = { [weak self] in self?.onCancel?() }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// Shows the popup, activates GrammarCat, and focuses the text view.
    func present() {
        if !didPosition {
            center()
            didPosition = true
        }
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        editor.focusEditor()
    }

    func clearEditor() {
        editor.clear()
    }

    // The close button hides the popup instead of destroying it.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        onCancel?()
        return false
    }
}
