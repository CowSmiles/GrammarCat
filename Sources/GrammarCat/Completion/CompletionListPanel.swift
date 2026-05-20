import AppKit

/// One row of the completion list: an icon plus the file/folder name.
private final class CompletionRowView: NSTableCellView {
    private let icon = NSImageView()
    private let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        icon.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        label.lineBreakMode = .byTruncatingMiddle
        label.font = .systemFont(ofSize: 13)
        addSubview(icon)
        addSubview(label)
        imageView = icon
        textField = label
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 15),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("created in code only") }

    func configure(with candidate: PathCandidate) {
        let symbol = candidate.isDirectory ? "folder" : "doc"
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        label.stringValue = candidate.displayName
    }
}

/// A floating, non-activating list of completion candidates.
///
/// It is display-only: it never becomes key or first responder, so the editor
/// keeps focus (and Grammarly keeps correcting). Selection is driven entirely
/// by `CompletionController`.
final class CompletionListPanel: NSPanel, NSTableViewDataSource, NSTableViewDelegate {
    /// Called with the row index when a row is clicked.
    var onRowClicked: ((Int) -> Void)?

    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private var candidates: [PathCandidate] = []

    private static let rowHeight: CGFloat = 22
    private let maxVisibleRows = 8
    private static let panelWidth: CGFloat = 380
    private let verticalInset: CGFloat = 4
    private static let cellID = NSUserInterfaceItemIdentifier("CompletionRow")

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Self.panelWidth, height: Self.rowHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .popUpMenu          // strictly above the popup's `.floating`
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        buildContent()
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // MARK: - Public API

    func show(candidates: [PathCandidate], selectedIndex: Int, at anchor: NSRect) {
        self.candidates = candidates
        tableView.reloadData()
        updateSelection(selectedIndex)

        let rows = min(max(candidates.count, 1), maxVisibleRows)
        let height = CGFloat(rows) * Self.rowHeight + verticalInset * 2
        setContentSize(NSSize(width: Self.panelWidth, height: height))
        setFrameOrigin(origin(anchor: anchor, height: height))
        orderFrontRegardless()
    }

    func updateSelection(_ index: Int) {
        guard index >= 0, index < candidates.count else { return }
        tableView.selectRowIndexes([index], byExtendingSelection: false)
        tableView.scrollRowToVisible(index)
    }

    func hide() {
        orderOut(nil)
    }

    // MARK: - Layout

    private func buildContent() {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = Self.rowHeight
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .regular
        tableView.refusesFirstResponder = true   // never steal first responder
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.action = #selector(rowClicked)

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let backing = NSVisualEffectView()
        backing.material = .menu
        backing.state = .active
        backing.wantsLayer = true
        backing.layer?.cornerRadius = 8
        backing.layer?.masksToBounds = true
        backing.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: backing.topAnchor, constant: verticalInset),
            scrollView.bottomAnchor.constraint(equalTo: backing.bottomAnchor, constant: -verticalInset),
            scrollView.leadingAnchor.constraint(equalTo: backing.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: backing.trailingAnchor),
        ])
        contentView = backing
    }

    /// Places the panel just below the anchor, flipping above if it would clip.
    private func origin(anchor: NSRect, height: CGFloat) -> NSPoint {
        let screen = NSScreen.screens.first { $0.frame.contains(anchor.origin) }
            ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero
        let gap: CGFloat = 4

        var y = anchor.minY - gap - height
        if y < visible.minY {
            y = anchor.maxY + gap
        }
        let x = min(max(anchor.minX, visible.minX), visible.maxX - Self.panelWidth)
        return NSPoint(x: x, y: y)
    }

    @objc private func rowClicked() {
        let row = tableView.clickedRow
        if row >= 0 { onRowClicked?(row) }
    }

    // MARK: - Table

    func numberOfRows(in tableView: NSTableView) -> Int { candidates.count }

    func tableView(_ tableView: NSTableView,
                   viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: Self.cellID, owner: self) as? CompletionRowView
            ?? {
                let view = CompletionRowView()
                view.identifier = Self.cellID
                return view
            }()
        cell.configure(with: candidates[row])
        return cell
    }
}
