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

    // Recursive search — a project's tree is walked once off the main thread,
    // cached, then re-filtered in memory. The cache is dropped when the editor
    // window regains key focus (see the observer below).
    private var cachedRoot: URL?
    private var cachedEntries: [RecursiveEntry] = []
    private let searchQueue = DispatchQueue(
        label: "com.klniu.grammarcat.completion-search", qos: .userInitiated)
    private var debounceWorkItem: DispatchWorkItem?
    /// Bumped to supersede an in-flight walk; a walk whose captured id no
    /// longer matches is discarded.
    private var inFlightSearchID = 0

    var isListVisible: Bool { panel.isVisible }

    init(textView: GrammarTextView) {
        self.textView = textView
        panel.onRowClicked = { [weak self] row in self?.accept(rowIndex: row) }

        let center = NotificationCenter.default
        for name in [NSWindow.didResignKeyNotification, NSWindow.didResizeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) {
                [weak self] note in
                guard let self, note.object as? NSWindow === self.textView?.window else { return }
                self.dismiss()
            })
        }
        // Drop the walk cache when the editor window regains focus, so files
        // created since the last session show up.
        observers.append(center.addObserver(
            forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let self, note.object as? NSWindow === self.textView?.window else { return }
            self.cachedRoot = nil
            self.cachedEntries = []
        })
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        debounceWorkItem?.cancel()
        panel.orderOut(nil)
    }

    // MARK: - Text watching

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
        lastQuery = token.query

        switch PathCompletionEngine.searchMode(for: token.query) {
        case let .flat(directory, partial):
            cancelPendingSearch()
            applyCandidates(
                PathCompletionEngine.flatCandidates(directory: directory, partial: partial))

        case let .recursive(root, nameTerm):
            if cachedRoot == root {
                cancelPendingSearch()
                applyCandidates(PathCompletionEngine.rankedCandidates(
                    from: cachedEntries, nameTerm: nameTerm, root: root))
            } else {
                scheduleRecursiveWalk(root: root, nameTerm: nameTerm, query: token.query)
            }
        }
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
        cancelPendingSearch()
        panel.hide()
        activeToken = nil
        candidates = []
        lastQuery = nil
    }

    // MARK: - Recursive search

    private func scheduleRecursiveWalk(root: URL, nameTerm: String, query: String) {
        debounceWorkItem?.cancel()
        inFlightSearchID += 1
        let id = inFlightSearchID

        let work = DispatchWorkItem { [weak self] in
            let entries = PathCompletionEngine.recursiveWalk(root: root) {
                self?.isStale(id) ?? true
            }
            DispatchQueue.main.async {
                self?.finishRecursiveWalk(id: id, query: query, root: root,
                                          nameTerm: nameTerm, entries: entries)
            }
        }
        debounceWorkItem = work
        searchQueue.asyncAfter(deadline: .now() + 0.13, execute: work)
    }

    private func finishRecursiveWalk(id: Int, query: String, root: URL,
                                     nameTerm: String, entries: [RecursiveEntry]) {
        // Discard a superseded walk, or one whose token has moved on.
        guard id == inFlightSearchID, activeToken?.query == query else { return }
        cachedRoot = root
        cachedEntries = entries
        applyCandidates(PathCompletionEngine.rankedCandidates(
            from: entries, nameTerm: nameTerm, root: root))
    }

    /// Read off the search queue — a benign `Int` race; the authoritative
    /// check is the main-thread re-compare in `finishRecursiveWalk`.
    private func isStale(_ id: Int) -> Bool {
        inFlightSearchID != id
    }

    private func cancelPendingSearch() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        inFlightSearchID += 1   // invalidate any walk still running
    }

    // MARK: - Panel

    private func applyCandidates(_ newCandidates: [PathCandidate]) {
        guard !newCandidates.isEmpty else {
            dismiss()
            return
        }
        // An unchanged list — e.g. typing deeper into an already-unique prefix
        // — needs no panel reload, and keeps the current selection.
        if isListVisible, newCandidates == candidates { return }
        candidates = newCandidates
        selectedIndex = 0
        showPanel()
    }

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
