import Defaults
import SwiftUI

func actionIcon(actionOrGroup: ActionOrGroup, iconSize: NSSize) -> some View {
  if let iconPath = (actionOrGroup.item.iconPath != nil) && !iconPath.isEmpty {
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
  }

  switch type {
  case .group:
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
    switch actionOrGroup {
    case .action(let action):
      return action.type
    default:
      return nil
    }
  }

  if type == .application {
    var view: AnyView? {
      switch actionOrGroup {
      case .action(let action):
        return AnyView(AppIconImage(appPath: action.value, size: iconSize))
      default:
        return nil  // should never be invoked
      }
    }
    return view!
  }

  if type == .url {
    var view: AnyView? {
      switch actionOrGroup {
      case .action(let action):
        return AnyView(FavIconImage(url: action.value, icon: icon, size: iconSize))
      default:
        return nil  // should never be invoked
      }
    }
    return view!
  }

  // MARK: - Default SF symbols
  var icon: String {
    switch actionOrGroup {
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
