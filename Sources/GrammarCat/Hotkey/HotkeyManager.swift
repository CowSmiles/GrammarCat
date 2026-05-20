import AppKit
import Carbon

/// Registers a system-wide hotkey via Carbon's `RegisterEventHotKey`.
///
/// Carbon hotkeys are used (rather than `NSEvent` global monitors) because
/// they need no Accessibility permission, fire reliably while GrammarCat is
/// in the background, and consume the chord so it doesn't leak to other apps.
final class HotkeyManager {
    var onTrigger: (() -> Void)?

    // Default chord: ⌘⇧I. Rebind by editing keyCode / modifiers here.
    private let keyCode = UInt32(kVK_ANSI_I)
    private let modifiers = UInt32(cmdKey | shiftKey)
    private let hotKeyID = EventHotKeyID(signature: 0x47434154 /* 'GCAT' */, id: 1)

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    func register() {
        installHandler()

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode, modifiers, hotKeyID,
            GetApplicationEventTarget(), 0, &ref
        )
        if status == noErr {
            hotKeyRef = ref
        } else {
            NSLog("GrammarCat: hotkey registration failed (status \(status))")
        }
    }

    private func installHandler() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let context = Unmanaged.passUnretained(self).toOpaque()
        var ref: EventHandlerRef?
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData -> OSStatus in
                guard let userData else { return noErr }
                let manager = Unmanaged<HotkeyManager>
                    .fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { manager.onTrigger?() }
                return noErr
            },
            1, &spec, context, &ref
        )
        handlerRef = ref
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
