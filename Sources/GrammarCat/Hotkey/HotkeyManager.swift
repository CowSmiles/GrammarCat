import AppKit
import Carbon

/// Registers a system-wide hotkey via Carbon's `RegisterEventHotKey`.
///
/// Carbon hotkeys are used (rather than `NSEvent` global monitors) because
/// they need no Accessibility permission, fire reliably while GrammarCat is
/// in the background, and consume the chord so it doesn't leak to other apps.
///
/// The chord itself is read live from `Settings`; call `reload()` after the
/// user changes it.
final class HotkeyManager {
    var onTrigger: (() -> Void)?

    private let hotKeyID = EventHotKeyID(signature: 0x47434154 /* 'GCAT' */, id: 1)
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var handlerInstalled = false
    private var registeredChord: (Int, Int)?

    /// Installs the event handler (once) and registers the current chord.
    func register() {
        if !handlerInstalled {
            installHandler()
            handlerInstalled = true
        }
        reload()
    }

    /// Registers the chord from current `Settings`. No-ops when the chord is
    /// unchanged, so it is safe to call on any settings change.
    func reload() {
        let chord = (Settings.hotKeyCode, Settings.hotKeyModifiers)
        if let registeredChord, registeredChord == chord { return }

        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(chord.0), UInt32(chord.1),
            hotKeyID, GetApplicationEventTarget(), 0, &ref
        )
        if status == noErr {
            hotKeyRef = ref
            registeredChord = chord
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
