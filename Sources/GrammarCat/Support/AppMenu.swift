import AppKit

/// Builds a minimal main menu.
///
/// An `LSUIElement` app has no visible menu bar, but the standard editing
/// shortcuts (⌘C/⌘V/⌘X/⌘A/⌘Z) are dispatched as menu key equivalents — so
/// without an Edit menu, *pasting into our own text view would not work*.
enum AppMenu {
    /// `settingsTarget` receives `openSettings(_:)` when ⌘, is pressed — this
    /// is the always-available way to reach Settings even if the floating
    /// button (its other entry point) is hidden.
    static func install(settingsTarget: AnyObject?) {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        let settingsItem = appMenu.addItem(
            withTitle: "Settings…",
            action: #selector(AppDelegate.openSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = settingsTarget
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Quit GrammarCat",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        // Edit menu — routes to the first responder (the focused NSTextView).
        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editItem.submenu = editMenu

        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(
            withTitle: "Select All",
            action: #selector(NSText.selectAll(_:)),
            keyEquivalent: "a"
        )

        NSApp.mainMenu = mainMenu
    }
}
