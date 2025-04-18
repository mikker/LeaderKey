import SwiftUI

enum MysteryBox {
  static let size: CGFloat = 200

  class Window: MainWindow {
    required init(controller: Controller) {
      super.init(
        controller: controller,
        contentRect: NSRect(x: 0, y: 0, width: MysteryBox.size, height: MysteryBox.size))

      let view = MainView().environmentObject(self.controller.userState)
      contentView = NSHostingView(rootView: view)
    }

    override func show(on screen: NSScreen, after: (() -> Void)? = nil) {
      let center = screen.center()
      let newOriginX = center.x - MysteryBox.size / 2
      let newOriginY = center.y + MysteryBox.size / 8
      self.setFrameOrigin(NSPoint(x: newOriginX, y: newOriginY))

      makeKeyAndOrderFront(nil)

      fadeInAndUp {
        after?()
      }
    }

    override func hide(after: (() -> Void)? = nil) {
      fadeOutAndDown {
        super.hide(after: after)
      }
    }

    override func notFound() {
      shake()
    }

    override func cheatsheetOrigin(cheatsheetSize: NSSize) -> NSPoint {
      return NSPoint(
        x: frame.maxX + 20,
        y: frame.midY - cheatsheetSize.height / 2
      )
    }
  }

  struct MainView: View {
    @EnvironmentObject var userState: UserState

    var body: some View {
      ZStack {
        let text = Text(userState.currentGroup?.key ?? userState.display ?? "●")
          .fontDesign(.rounded)
          .fontWeight(.semibold)
          .font(.system(size: 28, weight: .semibold, design: .rounded))

        if userState.isShowingRefreshState {
          text.pulsate()
        } else {
          text
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
      .background(
        VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
      )
      .clipShape(RoundedRectangle(cornerRadius: 25.0, style: .continuous))
    }
  }
}

struct MysteryBox_MainView_Previews: PreviewProvider {
  static var previews: some View {
    MysteryBox.MainView().environmentObject(UserState(userConfig: UserConfig()))
      .frame(width: MysteryBox.size, height: MysteryBox.size, alignment: .center)
  }
}
