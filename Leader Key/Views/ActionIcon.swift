import Defaults
import SwiftUI

func actionIcon(item: ActionOrGroup, iconSize: NSSize) -> some View {
  // MARK: - Custom icons
  var iconPath: String? {
    switch item {
    case .action(let action):
      return action.iconPath
    case .group(let group):
      return group.iconPath
    }
  }

  if iconPath != nil && !iconPath!.isEmpty {
    if iconPath!.hasSuffix(".app") {
      return AnyView(AppIconImage(appPath: iconPath!, size: iconSize))
    } else {
      // SF Symbol
      return AnyView(
        Image(systemName: iconPath!)
          .foregroundStyle(.secondary)
          .frame(width: iconSize.width, height: iconSize.height, alignment: .center)
      )
    }
  }

  // MARK: - Default for applications

  var type: Type? {
    switch item {
    case .action(let action):
      return action.type
    default:
      return nil
    }
  }

  if type == .application {
    var view: AnyView? {
      switch item {
      case .action(let action):
        return AnyView(AppIconImage(appPath: action.value, size: iconSize))
      default:
        return nil  // should never be invoked
      }
    }
    return view!
  }

  // MARK: - Default SF symbols
  var icon: String {
    switch item {
    case .action(let action):
      switch action.type {
      case .application: return "macwindow"
      case .url: return "link"
      case .command: return "terminal"
      case .folder: return "folder"
      default: return "questionmark"
      }
    case .group:
      return "folder"
    }
  }

  return AnyView(
    Image(systemName: icon)
      .foregroundStyle(.secondary)
      .frame(width: iconSize.width, height: iconSize.height, alignment: .center)
  )
}

struct AppIconImage: View {
  let appPath: String
  let size: NSSize
  let defaultSystemName: String = "questionmark.circle"

  init(appPath: String, size: NSSize = NSSize(width: 24, height: 24)) {
    self.appPath = appPath
    self.size = size
  }

  var body: some View {
    let image =
      if let icon = getAppIcon(path: appPath) {
        Image(nsImage: icon)
      } else {
        Image(systemName: defaultSystemName)
      }
    image.resizable()
      .scaledToFit()
      .frame(width: size.width, height: size.height)
  }

  private func getAppIcon(path: String) -> NSImage? {
    guard FileManager.default.fileExists(atPath: path) else {
      return nil
    }

    let icon = NSWorkspace.shared.icon(forFile: path)
    let resizedIcon = NSImage(size: size, flipped: false) { rect in
      let iconRect = NSRect(origin: .zero, size: icon.size)
      icon.draw(in: rect, from: iconRect, operation: .sourceOver, fraction: 1)
      return true
    }
    return resizedIcon
  }
}

struct AppImagePreview: PreviewProvider {
  static var previews: some View {
    let appPaths = ["/Applications/Xcode.app", "/Applications/Safari.app", "/invalid/path"]
    VStack {
      ForEach(appPaths, id: \.self) { path in
        AppIconImage(appPath: path)
      }
    }
    .padding()
  }
}
