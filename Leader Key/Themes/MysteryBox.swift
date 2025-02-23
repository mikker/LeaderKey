import SwiftUI

enum MysteryBox {
  static let size: CGFloat = 200

  class Window: MainWindow {
    required init(controller: Controller) {
      super.init(
        controller: controller,
        contentRect: NSRect(x: 0, y: 0, width: MysteryBox.size, height: MysteryBox.size))
      center()

      let view = MainView().environmentObject(self.controller.userState)
      contentView = NSHostingView(rootView: view)
    }

    override func show(after: (() -> Void)? = nil) {
      center()

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
  }
}
