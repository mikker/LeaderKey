import Cocoa
import QuartzCore
import SwiftUI

class Window: PanelWindow, NSWindowDelegate {
  override var acceptsFirstResponder: Bool { return true }
  override var canBecomeKey: Bool { return true }
  override var canBecomeMain: Bool { return true }

  var controller: Controller

  init(controller: Controller) {
    self.controller = controller

    super.init(contentRect: NSRect(x: 0, y: 0, width: 500, height: 550))

    center()

    let view = MainView().environmentObject(self.controller.userState)
    contentView = NSHostingView(rootView: view)

    delegate = self
  }

  func windowWillClose(_: Notification) {}

  // Hide when focus shifts elsewhere
  func windowDidResignKey(_ notification: Notification) {
    controller.hide()
  }

  override func makeKeyAndOrderFront(_ sender: Any?) {
    super.makeKeyAndOrderFront(sender)
  }

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    if event.modifierFlags.contains(.command) {
      controller.keyDown(with: event)
      return true
    }
    return false
  }

  override func keyDown(with event: NSEvent) {
    controller.keyDown(with: event)
  }

  func show(afterOpen: (() -> Void)? = nil) {
    center()

    makeKeyAndOrderFront(nil)

    fadeInAndUp {
      afterOpen?()
    }
  }

  func hide(afterClose: (() -> Void)? = nil) {
    fadeOutAndDown {
      self.close()
      afterClose?()
    }
  }
}
