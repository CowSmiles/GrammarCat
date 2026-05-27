import AppKit
import CoreGraphics

/// Delivers corrected text to the previously-focused app.
///
/// On the auto-paste path the text is typed via synthetic Unicode keyboard
/// events (`CGEvent.keyboardSetUnicodeString`) so the clipboard is never
/// touched. The clipboard write helper is kept for the fallback path used
/// when Accessibility is denied or the user disables auto-paste.
enum Paster {
    /// Places `text` on the general pasteboard, replacing its contents.
    /// Used only by the fallback path (auto-paste off or no Accessibility) so
    /// the user can manually ⌘V — never lose their text.
    static func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Re-activates `app`, then types `text` directly via synthetic Unicode
    /// keyboard events. Bypasses the clipboard entirely.
    /// Requires Accessibility permission for the synthetic events.
    static func paste(_ text: String, into app: NSRunningApplication?) {
        if let app, !app.isTerminated {
            _ = app.activate(options: [])
        }

        // Give the target app a moment to come forward before typing.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            typeUnicodeString(text)
        }
    }

    // MARK: - Private helpers

    /// Posts a sequence of synthetic keyboard events whose Unicode string is
    /// `text`. Each event carries up to `chunkSize` UTF-16 code units; chunks
    /// are split on character boundaries so surrogate pairs stay intact.
    ///
    /// Uses a private-state event source (no inherited modifier flags) and
    /// posts to the session event tap, matching what Hammerspoon / Karabiner /
    /// AppleScript `keystroke` do. The HID tap is the wrong layer for events
    /// whose payload is a Unicode string rather than a virtual key code.
    private static func typeUnicodeString(_ text: String) {
        // `.privateState` keeps the synthetic events isolated from whatever
        // modifier keys were down at submit time (e.g. ⌘ from a hotkey).
        let source = CGEventSource(stateID: .privateState)
        let utf16 = Array(text.utf16)
        guard !utf16.isEmpty else { return }

        let chunkSize = 20
        utf16.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            var index = 0
            while index < buf.count {
                var end = min(index + chunkSize, buf.count)
                // Don't split a surrogate pair across two events.
                if end < buf.count, isHighSurrogate(buf[end - 1]) {
                    end -= 1
                }

                let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
                let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
                // Defensive: clear any inherited modifier flags.
                keyDown?.flags = []
                keyUp?.flags = []
                keyDown?.keyboardSetUnicodeString(stringLength: end - index, unicodeString: base + index)
                keyUp?.keyboardSetUnicodeString(stringLength: end - index, unicodeString: base + index)
                keyDown?.post(tap: .cgSessionEventTap)
                keyUp?.post(tap: .cgSessionEventTap)

                index = end
            }
        }
    }

    private static func isHighSurrogate(_ unit: UniChar) -> Bool {
        unit >= 0xD800 && unit <= 0xDBFF
    }
}
