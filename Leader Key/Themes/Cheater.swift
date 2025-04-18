import Foundation
import SwiftUI

enum Cheater {
  class Window: MainWindow {
    override var hasCheatsheet: Bool { return false }

    required init(controller: Controller) {
      super.init(controller: controller, contentRect: NSRect(x: 0, y: 0, width: 0, height: 0))
      let view = Cheatsheet.CheatsheetView()
      contentView = NSHostingView(rootView: view.environmentObject(self.controller.userState))
    }

    override func show(on screen: NSScreen, after: (() -> Void)?) {
      let center = screen.center()
      let newOriginX = center.x - frame.width / 2
      let newOriginY = center.y - frame.height / 2 + frame.height / 8
      self.setFrameOrigin(NSPoint(x: newOriginX, y: newOriginY))

      makeKeyAndOrderFront(nil)

      fadeInAndUp {
        after?()
      }
    }

    override func hide(after: (() -> Void)?) {
      fadeOutAndDown {
        self.close()
        after?()
      }
    }

    override func notFound() {
      shake()
    }
  }
}
