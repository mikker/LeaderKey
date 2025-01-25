import Cocoa

class MainMenu: NSMenu {
  init() {
    super.init(title: "MainMenu")

    let appMenu = NSMenuItem()
    appMenu.submenu = NSMenu()

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
