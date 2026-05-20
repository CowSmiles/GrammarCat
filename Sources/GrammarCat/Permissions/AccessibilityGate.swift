import ApplicationServices

/// Thin wrapper over the macOS Accessibility-trust API.
///
/// Accessibility permission is required to synthesise the ⌘V keystroke that
/// pastes into the previous app. Note logging works without it.
enum AccessibilityGate {
    /// Whether GrammarCat currently has Accessibility (synthetic input) rights.
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Checks the permission. When `prompt` is true and it is missing, macOS
    /// shows the system dialog that deep-links into System Settings.
    @discardableResult
    static func ensure(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
