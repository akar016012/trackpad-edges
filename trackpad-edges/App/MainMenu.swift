import AppKit

/// Builds the main menu in code. The Edit menu is what makes copy and paste work in text fields.
enum MainMenu {
    static func make() -> NSMenu {
        let main = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(
            NSMenuItem(
                title: "About Trackpad Edges",
                action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                keyEquivalent: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(
            NSMenuItem(
                title: "Hide Trackpad Edges", action: #selector(NSApplication.hide(_:)),
                keyEquivalent: "h"))
        appMenu.addItem(
            NSMenuItem(
                title: "Quit Trackpad Edges", action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"))
        add(appMenu, title: "Trackpad Edges", to: main)

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(
            NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(
            NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(.separator())
        editMenu.addItem(
            NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(
            NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(
            NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(
            NSMenuItem(
                title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        add(editMenu, title: "Edit", to: main)

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(
            NSMenuItem(
                title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        windowMenu.addItem(
            NSMenuItem(
                title: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)),
                keyEquivalent: "m"))
        add(windowMenu, title: "Window", to: main)
        NSApp.windowsMenu = windowMenu
        return main
    }

    private static func add(_ menu: NSMenu, title: String, to main: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = menu
        main.addItem(item)
    }
}
