//
//  MysteryBox.swift
//  Leader Key
//
//  Created by Mikkel Malmberg on 21/02/2025.
//

import SwiftUI

let mysteryBoxSize: CGFloat = 200

enum MysteryBox {
  class Window: MainWindow {
    init(controller: Controller) {
      super.init(
        controller: controller,
        contentRect: NSRect(x: 0, y: 0, width: 500, height: 550))
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
  }

  struct MainView: View {
    @EnvironmentObject var userState: UserState

    var body: some View {
      Text(userState.currentGroup?.key ?? userState.display ?? "●")
        .fontDesign(.rounded)
        .fontWeight(.semibold)
        .font(.system(size: 28, weight: .semibold, design: .rounded))
        .frame(width: mysteryBoxSize, height: mysteryBoxSize, alignment: .center)
        .background(
          VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
        )
        .clipShape(RoundedRectangle(cornerRadius: 25.0, style: .continuous))
    }
  }
}

struct MainView_Previews: PreviewProvider {
  static var previews: some View {
    MysteryBox.MainView().environmentObject(UserState(userConfig: UserConfig()))
  }
}
