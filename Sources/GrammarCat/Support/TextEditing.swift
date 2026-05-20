import Foundation

/// Abstraction over the editable area inside the popup.
///
/// The shipping implementation is a native `NSTextView` (so Grammarly Desktop
/// can hook it). If Grammarly ever fails to recognise the native view, a
/// `WKWebView`-backed editor can be swapped in behind this same protocol
/// without touching `PopupWindow` or `AppDelegate`.
protocol TextEditing: AnyObject {
    func currentText() -> String
    func setText(_ text: String)
    func clear()
    func focusEditor()
}
