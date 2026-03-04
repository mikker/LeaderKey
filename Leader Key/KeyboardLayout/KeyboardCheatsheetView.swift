import SwiftUI

struct KeyboardCheatsheetView: View {
  @EnvironmentObject var userState: UserState

  var scale: CGFloat {
    userState.cheatsheetCentered ? KeyboardLayout.centeredScale : 1.0
  }

  var bindings: [String: ActionOrGroup] {
    var result: [String: ActionOrGroup] = [:]

    let actions =
      (userState.currentGroup != nil)
      ? userState.currentGroup!.actions
      : userState.userConfig.root.actions

    for item in actions {
      switch item {
      case .action(let action):
        if let key = action.key {
          result[key] = item
        }
      case .group(let group):
        if let key = group.key {
          result[key] = item
        }
      }
    }

    return result
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8 * scale) {
      // Breadcrumbs navigation
      HStack(spacing: 4 * scale) {
        if !userState.navigationPath.isEmpty {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4 * scale) {
              // Path breadcrumbs
              ForEach(0..<userState.navigationPath.count, id: \.self) { index in
                if index > 0 {
                  Text(">")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12 * scale))
                }

                let group = userState.navigationPath[index]
                let isLast = index == userState.navigationPath.count - 1

                Text(group.displayName)
                  .font(.system(size: 12 * scale, weight: isLast ? .bold : .regular))
              }
            }
          }
        }
        Spacer()
      }
      .frame(height: 28 * scale)

      // Keyboard layout
      KeyboardLayoutView(
        bindings: bindings,
        isEditable: false,
        shiftHeld: userState.shiftHeld,
        scale: scale
      )
    }
    .padding(16 * scale)
    .background(
      ZStack {
        VisualEffectView(material: .popover, blendingMode: .behindWindow)
        Color(NSColor.windowBackgroundColor).opacity(0.7)
      }
    )
  }
}

#Preview {
  let config = UserConfig()
  let state = UserState(userConfig: config)

  return KeyboardCheatsheetView()
    .environmentObject(state)
    .frame(width: 700, height: 350)
}
