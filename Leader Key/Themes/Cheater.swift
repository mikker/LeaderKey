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

    override func show(after: (() -> Void)?) {
      let size = NSScreen.main?.frame.size ?? NSSize()
      let width = contentView?.frame.width ?? Cheatsheet.CheatsheetView.preferredWidth
      let height = contentView?.frame.height ?? 0
      let x = size.width / 2 - width / 2
      let y = size.height / 2 - height / 2
      self.setFrame(CGRect(x: x, y: y, width: width, height: height), display: true)

      super.show(after: after)
    }

    override func notFound() {
      shake()
    }
  }
}
