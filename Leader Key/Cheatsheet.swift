//
//  CheatsheetView.swift
//  Leader Key
//
//  Created by Mikkel Malmberg on 26/01/2025.
//

import SwiftUI

enum Cheatsheet {
  struct KeyBadge: SwiftUI.View {
    let key: String

    var body: some SwiftUI.View {
      Text(key.uppercased())
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

    var icon: String {
      switch action.type {
      case .application: return "macwindow"
      case .url: return "link"
      case .command: return "terminal"
      case .folder: return "folder"
      default: return "questionmark"
      }
    }

    var body: some SwiftUI.View {
      HStack {
        HStack {
          ForEach(0..<indent, id: \.self) { _ in
            Text("  ")
          }
          KeyBadge(key: action.key ?? "●")
          Image(systemName: icon)
            .foregroundStyle(.secondary)
          Text(action.displayName)
            .lineLimit(1)
            .truncationMode(.middle)
        }
        Spacer()
        Text(action.value)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
      }
    }
  }

  struct GroupRow: SwiftUI.View {
    let group: Group
    let indent: Int

    var body: some SwiftUI.View {
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          ForEach(0..<indent, id: \.self) { _ in
            Text("  ")
          }
          KeyBadge(key: group.key ?? "")
          Image(systemName: "folder")
            .foregroundStyle(.secondary)
          Text(group.displayName)
          Spacer()
          Text("\(group.actions.count.description) item(s)")
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
        }
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

  struct CheatsheetView: SwiftUI.View {
    @EnvironmentObject var userState: UserState
    @State private var contentHeight: CGFloat = 0

    var maxHeight: CGFloat {
      if let screen = NSScreen.main {
        return screen.visibleFrame.height - 40  // Leave some margin
      }
      return 640
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
              KeyBadge(key: group.key ?? "")
              Text(group.displayName)
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
      .frame(width: 580)
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
