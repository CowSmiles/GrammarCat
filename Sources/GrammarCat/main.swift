import AppKit

// Entry point. GrammarCat runs as an accessory app (no Dock icon); see
// LSUIElement in Info.plist. The delegate is held by this top-level binding
// for the lifetime of the process.
let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
