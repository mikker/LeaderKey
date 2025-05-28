import SwiftUI

enum HAL9000 {
  static let size: CGFloat = 250
  // Adjusted for a smoother, perhaps slower HAL-like feel
  static let duration: CGFloat = 0.2
  // Slower, more ominous pulsing
  static let eyeGlowAnimationDuration: CGFloat = 2.5
  // Slight delay for dramatic effect
  static let glowAnimationDelay: CGFloat = 0.3

  // Enhanced color palette
  private static let colors = (
    darkMetallic: Color(white: 0.22),
    metallic: Color(white: 0.3),
    lightMetallic: Color(white: 0.45),
    veryLightMetallic: Color(white: 0.7),
    darkRed: Color(red: 0.25, green: 0, blue: 0),
    mediumRed: Color(red: 0.5, green: 0.05, blue: 0.05),
    brightRed: Color(red: 0.85, green: 0.1, blue: 0.1),
    glowRed: Color(red: 1.0, green: 0.3, blue: 0.2)
  )

  class Window: MainWindow {
    private var animationState = AnimationState()

    required init(controller: Controller) {
      super.init(
        controller: controller,
        contentRect: NSRect(
          x: 0, y: 0, width: HAL9000.size, height: HAL9000.size))

      backgroundColor = .clear
      isOpaque = false

      contentView?.wantsLayer = true
      if let layer = contentView?.layer {
        layer.shadowColor = NSColor.red.withAlphaComponent(0.3).cgColor
        layer.shadowOpacity = 1.0
        layer.shadowRadius = 12
        layer.shadowOffset = NSSize.zero
        layer.masksToBounds = false
      }

      let view = MainView()
        .environmentObject(self.controller.userState)
        .environmentObject(animationState)
      contentView = NSHostingView(rootView: view)
    }

    override func show(on screen: NSScreen, after: (() -> Void)? = nil) {
      let center = screen.center()
      // Center HAL more directly, perhaps slightly higher like an eye
      let newOriginX = center.x - HAL9000.size / 2
      let newOriginY = center.y - HAL9000.size / 2 + HAL9000.size / 8
      self.setFrameOrigin(NSPoint(x: newOriginX, y: newOriginY))

      animationState.isShowing = true

      makeKeyAndOrderFront(nil)
      alphaValue = 0

      NSAnimationContext.runAnimationGroup(
        { context in
          context.duration = HAL9000.duration
          context.timingFunction = CAMediaTimingFunction(name: .easeOut)
          animator().alphaValue = 1.0
        },
        completionHandler: {
          after?()
        })
    }

    override func hide(after: (() -> Void)? = nil) {
      animationState.isShowing = false

      NSAnimationContext.runAnimationGroup(
        { context in
          context.duration = HAL9000.duration
          context.timingFunction = CAMediaTimingFunction(name: .easeIn)
          animator().alphaValue = 0.0
        },
        completionHandler: {
          super.hide(after: after)
        })
    }

    override func notFound() {
      // HAL might not 'shake', perhaps a more subtle indication like a brief dimming or color change
      // For now, let's keep shake, can be customized later
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
    // For the eye's pulsating glow
    @Published var pulsateGlow: Bool = false
  }
}

extension HAL9000 {
  struct MainView: View {
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var animationState: AnimationState
    @State private var scale: CGFloat = 0.9
    @State private var glowOpacity: Double = 0.7
    @State private var innerGlowOpacity: Double = 0.0

    var body: some View {
      ZStack {
        // Outer metallic housing with gradient
        Circle()
          .fill(
            RadialGradient(
              gradient: Gradient(colors: [
                HAL9000.colors.metallic,
                HAL9000.colors.darkMetallic,
              ]),
              center: .center,
              startRadius: 0,
              endRadius: HAL9000.size * 0.45
            )
          )
          .frame(width: HAL9000.size * 0.9, height: HAL9000.size * 0.9)
          .shadow(color: .black.opacity(0.3), radius: 8, x: 2, y: 2)

        // Metallic ring detail
        Circle()
          .strokeBorder(
            LinearGradient(
              gradient: Gradient(colors: [
                HAL9000.colors.lightMetallic,
                HAL9000.colors.darkMetallic,
              ]),
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: HAL9000.size * 0.02
          )
          .frame(width: HAL9000.size * 0.85, height: HAL9000.size * 0.85)

        // Main lens assembly
        ZStack {
          // Base dark red lens
          Circle()
            .fill(HAL9000.colors.darkRed)
            .frame(width: HAL9000.size * 0.75, height: HAL9000.size * 0.75)
            .shadow(color: .black.opacity(0.5), radius: 15, x: 0, y: 0)

          // Medium red inner glow
          Circle()
            .fill(HAL9000.colors.mediumRed)
            .frame(width: HAL9000.size * 0.6, height: HAL9000.size * 0.6)
            .blur(radius: 8)
            .opacity(innerGlowOpacity)

          // Bright red core
          Circle()
            .fill(HAL9000.colors.brightRed)
            .frame(width: HAL9000.size * 0.45, height: HAL9000.size * 0.45)
            .blur(radius: 12)
            .opacity(innerGlowOpacity)

          // Central "eye" glow
          Circle()
            .fill(HAL9000.colors.glowRed)
            .frame(width: HAL9000.size * 0.25, height: HAL9000.size * 0.25)
            .blur(radius: 15)
            .opacity(glowOpacity)
            .shadow(color: HAL9000.colors.glowRed.opacity(0.8), radius: 20, x: 0, y: 0)
        }
        .clipShape(Circle())
        .frame(width: HAL9000.size * 0.75, height: HAL9000.size * 0.75)

        // Glare lines
        ForEach(0..<4) { index in
          GlareLineView(index: index, showing: animationState.isShowing)
        }

        // Text display
        if userState.isShowingRefreshState {
          KeyText(text: userState.currentGroup?.key ?? userState.display ?? " ")
            .opacity(0.5)
        } else {
          KeyText(text: userState.currentGroup?.key ?? userState.display ?? " ")
        }
      }
      .frame(width: HAL9000.size, height: HAL9000.size)
      .scaleEffect(scale)
      .onChange(of: animationState.isShowing) { newValue in
        if newValue {
          // Dramatic appearance sequence
          withAnimation(.easeOut(duration: HAL9000.duration)) {
            scale = 1.0
          }
          // Delayed glow effect
          DispatchQueue.main.asyncAfter(deadline: .now() + HAL9000.glowAnimationDelay) {
            withAnimation(.easeInOut(duration: HAL9000.duration * 2)) {
              innerGlowOpacity = 1.0
              glowOpacity = 1.0
            }
            animationState.pulsateGlow = true
          }
        } else {
          // Quick fadeout
          withAnimation(.easeIn(duration: HAL9000.duration)) {
            scale = 0.9
            innerGlowOpacity = 0.0
            glowOpacity = 0.7
          }
          animationState.pulsateGlow = false
        }
      }
      .onAppear {
        scale = animationState.isShowing ? 1.0 : 0.9
        innerGlowOpacity = animationState.isShowing ? 1.0 : 0.0
        glowOpacity = animationState.isShowing ? 1.0 : 0.7
        animationState.pulsateGlow = animationState.isShowing
      }
    }
  }

  struct KeyText: View {
    let text: String

    var body: some View {
      Text(text)
        .fontDesign(.monospaced)
        .fontWeight(.medium)
        .font(.system(size: 22, weight: .medium, design: .monospaced))
        .foregroundColor(Color.white.opacity(0.8))
        .shadow(color: .white.opacity(0.5), radius: 2, x: 0, y: 0)
    }
  }

  struct GlareLineView: View {
    let index: Int
    let showing: Bool

    var body: some View {
      let config = glareConfig(for: index)
      Capsule()
        .fill(
          LinearGradient(
            gradient: Gradient(colors: [
              HAL9000.colors.veryLightMetallic.opacity(0.1),
              HAL9000.colors.veryLightMetallic.opacity(0.4),
              HAL9000.colors.veryLightMetallic.opacity(0.1),
            ]),
            startPoint: .leading,
            endPoint: .trailing
          )
        )
        .frame(width: config.width, height: config.height)
        .rotationEffect(.degrees(config.rotation))
        .offset(x: config.offsetX, y: config.offsetY)
        .opacity(showing ? 1.0 : 0.0)
        .blur(radius: 0.3)
        .animation(
          .easeInOut(duration: HAL9000.duration * 2)
            // Staggered appearance
            .delay(Double(index) * 0.1),
          value: showing
        )
    }

    private func glareConfig(for index: Int) -> (width: CGFloat, height: CGFloat, rotation: Double, offsetX: CGFloat, offsetY: CGFloat) {
      switch index {
      case 0:
        return (HAL9000.size * 0.15, HAL9000.size * 0.012, -20, -HAL9000.size * 0.12, -HAL9000.size * 0.18)
      case 1:
        return (HAL9000.size * 0.08, HAL9000.size * 0.008, 0, HAL9000.size * 0.15, -HAL9000.size * 0.06)
      case 2:
        return (HAL9000.size * 0.08, HAL9000.size * 0.008, 0, HAL9000.size * 0.15, -HAL9000.size * 0.03)
      case 3:
        return (HAL9000.size * 0.1, HAL9000.size * 0.008, 30, HAL9000.size * 0.1, HAL9000.size * 0.2)
      default:
        return (0, 0, 0, 0, 0)
      }
    }
  }
}

struct HAL9000_MainView_Previews: PreviewProvider {
  static var previews: some View {
    HAL9000.MainView()
      .environmentObject(UserState(userConfig: UserConfig()))
      .environmentObject(HAL9000.AnimationState())
      .frame(width: HAL9000.size, height: HAL9000.size, alignment: .center)
      .background(Color.black)
  }
}
