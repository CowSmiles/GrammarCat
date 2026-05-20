import AppKit
import Carbon

/// A native `NSTextView` that reports ⌘↩ (submit) and `esc` (cancel).
///
/// Being a genuine `NSTextView` is the whole point: Grammarly Desktop hooks
/// native text views, which is how corrections appear inline.
final class GrammarTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var onCancel: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        let isReturn = event.keyCode == UInt16(kVK_Return)
            || event.keyCode == UInt16(kVK_ANSI_KeypadEnter)
        if isReturn && event.modifierFlags.contains(.command) {
            onSubmit?()
            return
        }
        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}

/// The popup's content view: the text editor plus a bottom bar
/// (hint + Clear + Send).
final class EditorView: NSView {
    let textView: GrammarTextView
    private let scrollView = NSScrollView()
    private let clearButton = NSButton()
    private let sendButton = NSButton()

    var onSubmit: (() -> Void)?
    var onCancel: (() -> Void)?

    override init(frame frameRect: NSRect) {
        textView = GrammarTextView(frame: NSRect(x: 0, y: 0, width: 480, height: 240))
        super.init(frame: frameRect)
        buildTextView()
        buildLayout()
        wireKeys()
    }

    required init?(coder: NSCoder) {
        fatalError("EditorView is created in code only")
    }

    // MARK: - Text access

    func currentText() -> String { textView.string }
    func clear() { textView.string = "" }
    func focusEditor() { window?.makeFirstResponder(textView) }

    // MARK: - Setup

    private func buildTextView() {
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = .systemFont(ofSize: 15)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        // Plain text in / out — no smart quotes or auto-substitution that
        // would fight with what Grammarly does.
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                  height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0,
                                                       height: CGFloat.greatestFiniteMagnitude)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.documentView = textView
    }

    private func buildLayout() {
        let hint = NSTextField(labelWithString: "⌘↩  submit       esc  cancel")
        hint.translatesAutoresizingMaskIntoConstraints = false
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor

        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.title = "Clear"
        clearButton.bezelStyle = .rounded
        clearButton.target = self
        clearButton.action = #selector(clearTapped)

        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.title = "Send"
        sendButton.bezelStyle = .rounded
        sendButton.target = self
        sendButton.action = #selector(sendTapped)

        addSubview(scrollView)
        addSubview(hint)
        addSubview(clearButton)
        addSubview(sendButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),

            sendButton.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 8),
            sendButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            sendButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),

            clearButton.centerYAnchor.constraint(equalTo: sendButton.centerYAnchor),
            clearButton.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),

            hint.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            hint.centerYAnchor.constraint(equalTo: sendButton.centerYAnchor),
        ])
    }

    private func wireKeys() {
        textView.onSubmit = { [weak self] in self?.onSubmit?() }
        textView.onCancel = { [weak self] in self?.onCancel?() }
    }

    @objc private func sendTapped() {
        onSubmit?()
    }

    @objc private func clearTapped() {
        clear()
        focusEditor()
    }
}
