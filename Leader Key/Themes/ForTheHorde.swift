import SwiftUI

enum ForTheHorde {
  static let size: CGFloat = 250
  static let duration: CGFloat = 0.15
  static let rotationDuration: CGFloat = 0.3  // Slightly longer for rotation to complete

  class Window: MainWindow {
    private var animationState = AnimationState()

    required init(controller: Controller) {
      super.init(
        controller: controller,
        contentRect: NSRect(
          x: 0, y: 0, width: MysteryBox.size, height: MysteryBox.size))

      backgroundColor = .clear
      isOpaque = false
      hasShadow = false

      let view = MainView()
        .environmentObject(self.controller.userState)
        .environmentObject(animationState)
      contentView = NSHostingView(rootView: view)
    }

    override func show(on screen: NSScreen, after: (() -> Void)? = nil) {
      let center = screen.center()
      let newOriginX = center.x - MysteryBox.size / 2
      let newOriginY = center.y + MysteryBox.size / 8
      self.setFrameOrigin(NSPoint(x: newOriginX, y: newOriginY))

      // Trigger animation by updating the shared state
      animationState.isShowing = true

      makeKeyAndOrderFront(nil)
      alphaValue = 0

      NSAnimationContext.runAnimationGroup(
        { context in
          context.duration = ForTheHorde.rotationDuration
          context.timingFunction = CAMediaTimingFunction(name: .easeOut)
          animator().alphaValue = 1.0
        },
        completionHandler: {
          after?()
        })
    }

    override func hide(after: (() -> Void)? = nil) {
      // Reset animation state when hiding
      animationState.isShowing = false

      // Custom fade out animation to match the show animation
      NSAnimationContext.runAnimationGroup(
        { context in
          context.duration = ForTheHorde.rotationDuration
          context.timingFunction = CAMediaTimingFunction(name: .easeIn)
          animator().alphaValue = 0.0
        },
        completionHandler: {
          super.hide(after: after)
        })
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

  class AnimationState: ObservableObject {
    @Published var isShowing: Bool = false
  }

  struct MainView: View {
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var animationState: AnimationState
    @State private var bgRotation: Double = -15
    @State private var fgRotation: Double = 15
    @State private var scale: CGFloat = 0.95

    var body: some View {
      ZStack {
        // Background image
        Image("ForTheHorde-bg", bundle: .main)
          .rotationEffect(.degrees(bgRotation))
          .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 2)

        // Foreground image
        Image("ForTheHorde-fg", bundle: .main)
          .rotationEffect(.degrees(fgRotation))

        // Text in the middle
        let text = Text(userState.currentGroup?.key ?? userState.display ?? "●")
          .fontDesign(.rounded)
          .fontWeight(.semibold)
          .font(.system(size: 28, weight: .semibold, design: .rounded))
          .foregroundColor(Color(red: 1, green: 0.769, blue: 0))

        if userState.isShowingRefreshState {
          text.pulsate()
        } else {
          text
        }

      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
      .scaleEffect(scale)
      .onChange(of: animationState.isShowing) { newValue in
        if newValue {
          // Animate rotations and scale to 100% when showing
          withAnimation(.easeOut(duration: ForTheHorde.rotationDuration)) {
            bgRotation = 0
            fgRotation = 0
            scale = 1.0
          }
        } else {
          // Animate rotations the other way and scale down when hiding
          withAnimation(.easeIn(duration: ForTheHorde.rotationDuration)) {
            bgRotation = 15
            fgRotation = -15
            scale = 0.95
          }
        }
      }
      .onAppear {
        bgRotation = -15
        fgRotation = 15
        scale = 0.95
      }
    }
  }
}

struct Legacy_MainView_Previews: PreviewProvider {
  static var previews: some View {
    ForTheHorde.MainView()
      .environmentObject(UserState(userConfig: UserConfig()))
      .environmentObject(ForTheHorde.AnimationState())
      .frame(
        width: MysteryBox.size, height: MysteryBox.size, alignment: .center)
  }
}
