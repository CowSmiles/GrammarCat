import AppKit
import Carbon

/// Coordinates `@`-mention path completion: watches the editor for an active
/// `@`-token, drives the list panel, and handles navigation + acceptance.
///
/// Owned by `EditorView`. Holds `textView` weakly, and `textView` holds this
/// controller weakly — no retain cycle.
final class CompletionController {
    private weak var textView: GrammarTextView?
    private let panel = CompletionListPanel()

    private var candidates: [PathCandidate] = []
    private var selectedIndex = 0
    private var activeToken: ATokenContext?
    /// The query last scanned — lets us skip the duplicate scan when one
    /// keystroke fires both `textDidChange` and `textViewDidChangeSelection`.
    private var lastQuery: String?
    /// Guards against the `textDidChange` / selection notifications that our
    /// own acceptance edit triggers.
    private var isApplyingAcceptance = false
    private var observers: [NSObjectProtocol] = []

    var isListVisible: Bool { panel.isVisible }

    init(textView: GrammarTextView) {
        self.textView = textView
        panel.onRowClicked = { [weak self] row in self?.accept(rowIndex: row) }

        // Dismiss if the popup window goes away or is resized underneath us.
        let center = NotificationCenter.default
        for name in [NSWindow.didResignKeyNotification, NSWindow.didResizeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) {
                [weak self] note in
                guard let self, note.object as? NSWindow === self.textView?.window else { return }
                self.dismiss()
            })
        }
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        panel.orderOut(nil)
    }

    // MARK: - Text watching

    /// Re-evaluates the `@`-token at the caret and refreshes or hides the list.
    func textOrSelectionChanged() {
        guard !isApplyingAcceptance, let textView else { return }
        let selection = textView.selectedRange()
        guard selection.length == 0,
              let token = PathCompletionEngine.activeToken(
                  in: textView.string, caret: selection.location)
        else {
            dismiss()
            return
        }
        activeToken = token
        // Skip the duplicate scan from the paired change/selection events.
        if isListVisible, token.query == lastQuery { return }

        candidates = PathCompletionEngine.candidates(for: token.query)
        lastQuery = token.query
        guard !candidates.isEmpty else {
            dismiss()
            return
        }
        selectedIndex = 0
        showPanel()
    }

    // MARK: - Key handling

    /// Handles a key while the list is visible. Returns true if consumed.
    func handleKeyDown(_ event: NSEvent) -> Bool {
        guard isListVisible else { return false }
        switch Int(event.keyCode) {
        case kVK_Escape:
            dismiss()
        case kVK_UpArrow:
            moveSelection(by: -1)
        case kVK_DownArrow:
            moveSelection(by: 1)
        case kVK_Return, kVK_ANSI_KeypadEnter, kVK_Tab:
            accept(rowIndex: selectedIndex)
        default:
            return false
        }
        return true
    }

    func dismiss() {
        panel.hide()
        activeToken = nil
        candidates = []
        lastQuery = nil
    }

    // MARK: - Private

    private func moveSelection(by delta: Int) {
        guard !candidates.isEmpty else { return }
        selectedIndex = (selectedIndex + delta + candidates.count) % candidates.count
        panel.updateSelection(selectedIndex)
    }

    private func accept(rowIndex: Int) {
        guard let textView, let token = activeToken,
              candidates.indices.contains(rowIndex) else { return }
        let (replacement, keepListOpen) = PathCompletionEngine.acceptance(of: candidates[rowIndex])

        isApplyingAcceptance = true
        let didReplace = textView.shouldChangeText(in: token.tokenRange,
                                                   replacementString: replacement)
        if didReplace {
            textView.replaceCharacters(in: token.tokenRange, with: replacement)
            textView.didChangeText()
            let caret = token.tokenRange.location + (replacement as NSString).length
            textView.setSelectedRange(NSRange(location: caret, length: 0))
        }
        isApplyingAcceptance = false

        if didReplace && keepListOpen {
            textOrSelectionChanged()   // drill into the just-accepted directory
        } else {
            dismiss()
        }
    }

    private func showPanel() {
        guard let textView, let token = activeToken else { return }
        panel.show(candidates: candidates,
                   selectedIndex: selectedIndex,
                   at: anchorRect(in: textView, tokenRange: token.tokenRange))
    }

    /// Screen rect of the `@` that begins the active token.
    private func anchorRect(in textView: GrammarTextView, tokenRange: NSRange) -> NSRect {
        let atRange = NSRange(location: tokenRange.location, length: 1)
        var rect = textView.firstRect(forCharacterRange: atRange, actualRange: nil)
        if rect == .zero {
            rect = textView.firstRect(forCharacterRange: textView.selectedRange(),
                                      actualRange: nil)
        }
        if rect == .zero, let window = textView.window {
            rect = window.convertToScreen(textView.convert(textView.bounds, to: nil))
        }
        return rect
    }
}
