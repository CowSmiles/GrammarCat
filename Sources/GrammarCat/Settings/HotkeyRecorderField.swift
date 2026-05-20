import AppKit
import Carbon

/// A click-to-record keyboard-shortcut control.
///
/// Click it, then press a chord (which must include at least one modifier).
/// The captured shortcut is reported via `onCapture` as a Carbon key code, a
/// Carbon modifier mask (ready for `RegisterEventHotKey`), and a display
/// string. `esc` cancels recording.
final class HotkeyRecorderField: NSButton {
    /// (carbonKeyCode, carbonModifierMask, displayString)
    var onCapture: ((Int, Int, String) -> Void)?

    private var recording = false { didSet { refreshTitle() } }
    private var monitor: Any?
    private var displayString = ""

    init() {
        super.init(frame: .zero)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(toggleRecording)
        refreshTitle()
    }

    required init?(coder: NSCoder) {
        fatalError("HotkeyRecorderField is created in code only")
    }

    /// Shows `display` as the current shortcut (when not recording).
    func setDisplay(_ display: String) {
        displayString = display
        refreshTitle()
    }

    @objc private func toggleRecording() {
        recording ? endRecording() : beginRecording()
    }

    private func beginRecording() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.handle(event) ?? event
        }
    }

    private func endRecording() {
        recording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
    }

    /// Returns `nil` to consume the event.
    private func handle(_ event: NSEvent) -> NSEvent? {
        if event.keyCode == UInt16(kVK_Escape) {
            endRecording()
            return nil
        }
        let cocoa = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let carbon = Self.carbonModifiers(from: cocoa)
        guard carbon != 0 else {
            // A global hotkey needs a modifier — ignore bare keys, keep recording.
            return nil
        }
        let display = Self.displayString(keyCode: Int(event.keyCode),
                                          modifiers: cocoa, event: event)
        displayString = display
        endRecording()
        onCapture?(Int(event.keyCode), carbon, display)
        return nil
    }

    private func refreshTitle() {
        if recording {
            title = "Recording…  (esc)"
        } else {
            title = displayString.isEmpty ? "Click to record" : displayString
        }
    }

    // MARK: - Cocoa ⇄ Carbon conversion

    /// Modifiers in canonical display order (⌃⌥⇧⌘), each paired with its
    /// Carbon mask bit and symbol.
    private static let modifierTable: [(flag: NSEvent.ModifierFlags, carbon: Int, symbol: String)] = [
        (.control, controlKey, "⌃"),
        (.option, optionKey, "⌥"),
        (.shift, shiftKey, "⇧"),
        (.command, cmdKey, "⌘"),
    ]

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> Int {
        modifierTable.reduce(0) { flags.contains($1.flag) ? $0 | $1.carbon : $0 }
    }

    static func displayString(keyCode: Int, modifiers: NSEvent.ModifierFlags,
                              event: NSEvent) -> String {
        let symbols = modifierTable
            .filter { modifiers.contains($0.flag) }
            .map(\.symbol)
            .joined()
        return symbols + keyName(keyCode: keyCode, event: event)
    }

    private static let specialKeys: [Int: String] = [
        49: "Space", 36: "↩", 76: "⌅", 48: "⇥", 51: "⌫", 117: "⌦",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ]

    private static func keyName(keyCode: Int, event: NSEvent) -> String {
        if let name = specialKeys[keyCode] { return name }
        if let chars = event.charactersIgnoringModifiers, let first = chars.first,
           first.isLetter || first.isNumber || first.isPunctuation || first.isSymbol {
            return chars.uppercased()
        }
        return "Key\(keyCode)"
    }
}
