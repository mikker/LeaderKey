import Cocoa

class MainMenu: NSMenu {
  init() {
    super.init(title: "MainMenu")

    let appMenu = NSMenuItem()
    appMenu.submenu = NSMenu(title: "Leader Key")
    appMenu.submenu?.items = [
      NSMenuItem(
        title: "About Leader Key",
        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""),
      .separator(),
      NSMenuItem(
        title: "Preferences...", action: #selector(AppDelegate.settingsMenuItemActionHandler(_:)),
        keyEquivalent: ","),
      .separator(),
      NSMenuItem(
        title: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"),
      .separator(),
      NSMenuItem(
        title: "Quit Leader Key", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"
      ),
    ]

    let editMenu = NSMenuItem()
    editMenu.submenu = NSMenu(title: "Edit")
    editMenu.submenu?.items = [
      NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"),
      NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"),
      .separator(),
      NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"),
      NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"),
      NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"),
      NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"),
    ]

    items = [appMenu, editMenu]
  }

  required init(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
