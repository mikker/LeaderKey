import Defaults
import Kingfisher
import SwiftUI

enum Cheatsheet {
  static func createWindow(for userState: UserState) -> NSWindow {
    let view = CheatsheetView().environmentObject(userState)
    let controller = NSHostingController(rootView: view)
    controller.sizingOptions = .preferredContentSize
    let cheatsheet = PanelWindow(
      contentRect: NSRect(x: 0, y: 0, width: 700, height: 640)
    )
    cheatsheet.contentViewController = controller
    return cheatsheet
  }
}

struct CheatsheetView: SwiftUI.View {
  @EnvironmentObject var userState: UserState
  @Default(.cheatsheetStyle) var cheatsheetStyle
  @State private var contentHeight: CGFloat = 0

  var maxHeight: CGFloat {
    if let screen = NSScreen.main {
      return screen.visibleFrame.height - 40
    }
    return 640
  }

  // Constrain to edge of screen
  static var preferredWidth: CGFloat {
    if let screen = NSScreen.main {
      let screenHalf = screen.visibleFrame.width / 2
      let desiredWidth: CGFloat = 700
      let margin: CGFloat = 20
      return desiredWidth > screenHalf ? screenHalf - margin : desiredWidth
    }
    return 700
  }

  var actions: [ActionOrGroup] {
    (userState.currentGroup != nil)
      ? userState.currentGroup!.actions : userState.userConfig.root.actions
  }

  var body: some SwiftUI.View {
    switch cheatsheetStyle {
    case .list:
      listView
    case .keyboard:
      KeyboardCheatsheetView()
        .fixedSize()
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
  }

  var listView: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 4) {
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
            ActionRow(action: action, indent: 0)
          case .group(let group):
            GroupRow(group: group, indent: 0)
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
    .frame(width: CheatsheetView.preferredWidth)
    .frame(height: min(contentHeight, maxHeight))
    .background(
      ZStack {
        VisualEffectView(material: .popover, blendingMode: .behindWindow)
        Color(NSColor.windowBackgroundColor).opacity(0.7)
      }
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

struct CheatsheetView_Previews: PreviewProvider {
  static var previews: some View {
    CheatsheetView()
      .environmentObject(UserState(userConfig: UserConfig()))
  }
}