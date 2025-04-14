import Defaults
import Kingfisher
import SwiftUI

enum Cheatsheet {
  private static let iconSize = NSSize(width: 24, height: 24)

  struct KeyBadge: SwiftUI.View {
    let key: String

    var body: some SwiftUI.View {
      Text(key)
        .font(.system(.body, design: .rounded))
        .multilineTextAlignment(.center)
        .fontWeight(.bold)
        .padding(.vertical, 4)
        .frame(width: 24)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 5.0, style: .continuous))
    }
  }

  struct ActionRow: SwiftUI.View {
    let action: Action
    let indent: Int
    @Default(.showDetailsInCheatsheet) var showDetails
    @Default(.showAppIconsInCheatsheet) var showIcons

    var body: some SwiftUI.View {
      HStack {
        HStack {
          ForEach(0..<indent, id: \.self) { _ in
            Text("  ")
          }
          KeyBadge(key: action.key ?? "●")

          if showIcons {
            actionIcon(item: ActionOrGroup.action(action), iconSize: iconSize)
          }

          Text(action.displayName)
            .lineLimit(1)
            .truncationMode(.middle)
        }
        Spacer()
        if showDetails {
          Text(action.value)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
        }
      }
    }
  }

  struct GroupRow: SwiftUI.View {
    @Default(.expandGroupsInCheatsheet) var expand
    @Default(.showDetailsInCheatsheet) var showDetails
    @Default(.showAppIconsInCheatsheet) var showIcons

    let group: Group
    let indent: Int

    var body: some SwiftUI.View {
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          ForEach(0..<indent, id: \.self) { _ in
            Text("  ")
          }
          KeyBadge(key: group.key ?? "")

          if showIcons {
            actionIcon(item: ActionOrGroup.group(group), iconSize: iconSize)
          }

          Image(systemName: "chevron.right")
            .foregroundStyle(.secondary)

          Text(group.displayName)

          Spacer()
          if showDetails {
            Text("\(group.actions.count.description) item(s)")
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.middle)
          }
        }
        if expand {
          ForEach(Array(group.actions.enumerated()), id: \.offset) { _, item in
            switch item {
            case .action(let action):
              Cheatsheet.ActionRow(action: action, indent: indent + 1)
            case .group(let group):
              Cheatsheet.GroupRow(group: group, indent: indent + 1)
            }
          }
        }
      }
    }
  }

  struct CheatsheetView: SwiftUI.View {
    @EnvironmentObject var userState: UserState
    @State private var contentHeight: CGFloat = 0

    var maxHeight: CGFloat {
      if let screen = NSScreen.main {
        return screen.visibleFrame.height - 40  // Leave some margin
      }
      return 640
    }

    // Constrain to edge of screen
    static var preferredWidth: CGFloat {
      if let screen = NSScreen.main {
        let screenHalf = screen.visibleFrame.width / 2
        let desiredWidth: CGFloat = 580
        let margin: CGFloat = 20
        return desiredWidth > screenHalf ? screenHalf - margin : desiredWidth
      }
      return 580
    }

    var actions: [ActionOrGroup] {
      (userState.currentGroup != nil)
        ? userState.currentGroup!.actions : userState.userConfig.root.actions
    }

    var body: some SwiftUI.View {
      ScrollView {
        SwiftUI.VStack(alignment: .leading, spacing: 4) {
          if let group = userState.currentGroup {
            HStack {
              KeyBadge(key: group.key ?? "•")
              Text(group.key == nil ? "Leader Key" : group.displayName)
                .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)
            Divider()
              .padding(.bottom, 8)
          }

          ForEach(Array(actions.enumerated()), id: \.offset) { _, item in
            switch item {
            case .action(let action):
              Cheatsheet.ActionRow(action: action, indent: 0)
            case .group(let group):
              Cheatsheet.GroupRow(group: group, indent: 0)
            }
          }
        }
        .padding()
        .overlay(
          GeometryReader { geo in
            Color.clear.preference(
              key: HeightPreferenceKey.self,
              value: geo.size.height
            )
          }
        )
      }
      .frame(width: Cheatsheet.CheatsheetView.preferredWidth)
      .frame(height: min(contentHeight, maxHeight))
      .background(
        VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
      )
      .onPreferenceChange(HeightPreferenceKey.self) { height in
        self.contentHeight = height
      }
    }
  }

  struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
      value = nextValue()
    }
  }

  static func createWindow(for userState: UserState) -> NSWindow {
    let view = CheatsheetView().environmentObject(userState)
    let controller = NSHostingController(rootView: view)
    let cheatsheet = PanelWindow(
      contentRect: NSRect(x: 0, y: 0, width: 580, height: 640)
    )
    cheatsheet.contentViewController = controller
    return cheatsheet
  }
}

struct CheatsheetView_Previews: PreviewProvider {
  static var previews: some View {
    Cheatsheet.CheatsheetView()
      .environmentObject(UserState(userConfig: UserConfig()))
  }
}
