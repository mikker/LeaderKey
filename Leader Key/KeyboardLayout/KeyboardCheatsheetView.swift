import SwiftUI

struct KeyboardCheatsheetView: View {
  @EnvironmentObject var userState: UserState
  // Observed so edits made while the cheatsheet is hidden are drawn on the next open
  @EnvironmentObject var userConfig: UserConfig

  // The keyboard cheatsheet is only ever shown centered. Keeping the scale fixed
  // means opening it reuses the existing layout instead of rebuilding every key.
  private let scale: CGFloat = KeyboardLayout.centeredScale

  var bindings: [String: ActionOrGroup] {
    var result: [String: ActionOrGroup] = [:]

    let actions =
      (userState.currentGroup != nil)
      ? userState.currentGroup!.actions
      : userConfig.root.actions

    for item in actions {
      switch item {
      case .action(let action):
        if let key = action.key {
          result[KeyMaps.text(for: key) ?? key] = item
        }
      case .group(let group):
        if let key = group.key {
          result[KeyMaps.text(for: key) ?? key] = item
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
        shiftHeld: userState.shiftHeld,
        scale: scale,
        showLabels: true
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
    .environmentObject(config)
    .frame(width: 700, height: 350)
}
