import AppKit

/// The on-screen content of the floating button: a rounded accent-coloured
/// tile with an icon, that can be clicked or dragged.
final class FloatingButtonView: NSView {
    var onClick: (() -> Void)?
    var onDragEnded: (() -> Void)?
    var onShowSettings: (() -> Void)?

    private var mouseDownLocation: NSPoint = .zero
    private var windowOriginAtMouseDown: NSPoint = .zero
    private var didDrag = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        let icon = NSImageView()
        icon.translatesAutoresizingMaskIntoConstraints = false
        let config = NSImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        icon.image = NSImage(systemSymbolName: "checkmark.bubble.fill",
                             accessibilityDescription: "GrammarCat")?
            .withSymbolConfiguration(config)
        icon.contentTintColor = .white
        addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        buildContextMenu()
    }

    required init?(coder: NSCoder) {
        fatalError("FloatingButtonView is created in code only")
    }

    private func buildContextMenu() {
        let contextMenu = NSMenu()
        contextMenu.addItem(menuItem("Open GrammarCat", #selector(menuOpen)))
        contextMenu.addItem(menuItem("Settings…", #selector(menuSettings)))
        contextMenu.addItem(.separator())
        contextMenu.addItem(menuItem("Quit GrammarCat", #selector(menuQuit)))
        menu = contextMenu
    }

    private func menuItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func menuOpen() { onClick?() }
    @objc private func menuSettings() { onShowSettings?() }
    @objc private func menuQuit() { NSApp.terminate(nil) }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        layer?.cornerRadius = 14
        layer?.masksToBounds = true
    }

    // Route every click to this view so a click over the icon still drags.
    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        return bounds.contains(local) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        didDrag = false
        mouseDownLocation = NSEvent.mouseLocation
        windowOriginAtMouseDown = window?.frame.origin ?? .zero
    }

    override func mouseDragged(with event: NSEvent) {
        let now = NSEvent.mouseLocation
        let dx = now.x - mouseDownLocation.x
        let dy = now.y - mouseDownLocation.y
        if abs(dx) > 3 || abs(dy) > 3 { didDrag = true }
        window?.setFrameOrigin(NSPoint(x: windowOriginAtMouseDown.x + dx,
                                       y: windowOriginAtMouseDown.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        if didDrag {
            onDragEnded?()
        } else {
            onClick?()
        }
    }
}

/// An always-on-top, non-activating, draggable button shown over every app.
final class FloatingButton: NSPanel {
    var onClick: (() -> Void)?
    var onShowSettings: (() -> Void)?

    private static let positionKey = "FloatingButtonOrigin"
    private static let size = NSSize(width: 52, height: 52)
    private let buttonView = FloatingButtonView(frame: NSRect(origin: .zero, size: FloatingButton.size))

    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .statusBar
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        // Visible on every Space, never cycled to with ⌘Tab.
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        contentView = buttonView

        buttonView.onClick = { [weak self] in self?.onClick?() }
        buttonView.onShowSettings = { [weak self] in self?.onShowSettings?() }
        buttonView.onDragEnded = { [weak self] in self?.savePosition() }

        restorePosition()
    }

    override var canBecomeKey: Bool { false }

    func setVisible(_ visible: Bool) {
        if visible {
            orderFrontRegardless()
        } else {
            orderOut(nil)
        }
    }

    private func restorePosition() {
        if let stored = UserDefaults.standard.dictionary(forKey: Self.positionKey),
           let x = stored["x"] as? Double, let y = stored["y"] as? Double {
            setFrameOrigin(NSPoint(x: x, y: y))
        } else if let screen = NSScreen.main {
            let area = screen.visibleFrame
            setFrameOrigin(NSPoint(x: area.maxX - 84, y: area.minY + 84))
        }
    }

    private func savePosition() {
        let origin = frame.origin
        UserDefaults.standard.set(["x": origin.x, "y": origin.y],
                                  forKey: Self.positionKey)
    }
}
