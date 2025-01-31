import Cocoa
import Combine
import SwiftUI

enum KeyHelpers: UInt16 {
  case Return = 36
  case Tab = 48
  case Space = 49
  case Backspace = 51
  case Escape = 53
}

class Controller {
  var userState: UserState
  var userConfig: UserConfig

  // Key map for English characters based on US QWERTY keyboard layout
  let englishKeyMap: [UInt16: String] = [
    // Letters a-z (verified)
    0x00: "a", 0x0B: "b", 0x08: "c", 0x02: "d", 0x0E: "e", 0x03: "f",
    0x05: "g", 0x04: "h", 0x22: "i", 0x26: "j", 0x28: "k", 0x25: "l",
    0x2E: "m", 0x2D: "n", 0x1F: "o", 0x23: "p", 0x0C: "q", 0x0F: "r",
    0x01: "s", 0x11: "t", 0x20: "u", 0x09: "v", 0x0D: "w", 0x07: "x",
    0x10: "y", 0x06: "z",
  ]

  var window: Window!
  var cheatsheetWindow: NSWindow?

  init(userState: UserState, userConfig: UserConfig) {
    self.userState = userState
    self.userConfig = userConfig
    self.cheatsheetWindow = Cheatsheet.createWindow(for: userState)
  }

  func show() {
    window.show()
  }

  func hide() {
    window.hide {
      self.clear()
    }
    cheatsheetWindow?.orderOut(nil)
  }

  func keyDown(with event: NSEvent) {
    if event.modifierFlags.contains(.command) {
      switch event.charactersIgnoringModifiers {
      case ",":
        NSApp.sendAction(
          #selector(AppDelegate.settingsMenuItemActionHandler(_:)), to: nil,
          from: nil)
        hide()
        return
      case "w":
        hide()
        return
      case "q":
        NSApp.terminate(nil)
        return
      default:
        break
      }
    }

    switch event.keyCode {
    case KeyHelpers.Backspace.rawValue:
      clear()
    case KeyHelpers.Escape.rawValue:
      hide()
    default:
      // Map key code to English character, ignoring the current input layout
      let keyCode = event.keyCode
      var char = (UserDefaults.standard.bool(forKey: "useEnglishKeyMap") ? englishKeyMap[keyCode] : event.charactersIgnoringModifiers) ?? event.charactersIgnoringModifiers ?? ""

      // Check if Shift is pressed and convert to uppercase if needed
      if event.modifierFlags.contains(.shift) {
        char = char.uppercased()
      }

      if char == "?" {
        showCheatsheet()
        return
      }

      let list =
        (userState.currentGroup != nil)
        ? userState.currentGroup : userConfig.root

      let hit = list?.actions.first { item in
        switch item {
        case let .group(group):
          if group.key == char {
            return true
          }
        case let .action(action):
          if action.key == char {
            return true
          }
        }
        return false
      }

      switch hit {
      case let .action(action):
        runAction(action)
        hide()
      case let .group(group):
        userState.display = group.key
        userState.currentGroup = group
      case .none:
        window.shake()
      }
    }

    // Why do we need to wait here?
    delay(1) {
      self.positionCheatsheetWindow()
    }
  }

  private func positionCheatsheetWindow() {
    guard let mainWindow = window, let cheatsheet = cheatsheetWindow else {
      return
    }
    let frame = mainWindow.frame
    let point = NSPoint(
      x: frame.maxX + 20,
      y: frame.midY - cheatsheet.frame.height / 2
    )
    cheatsheet.setFrameOrigin(point)
  }

  private func showCheatsheet() {
    positionCheatsheetWindow()
    cheatsheetWindow?.orderFront(nil)
  }

  private func runAction(_ action: Action) {
    switch action.type {
    case .application:
      NSWorkspace.shared.openApplication(
        at: URL(fileURLWithPath: action.value),
        configuration: NSWorkspace.OpenConfiguration())
    case .url:
      NSWorkspace.shared.open(
        URL(string: action.value)!,
        configuration: DontActivateConfiguration.shared.configuration)
    case .command:
      CommandRunner.run(action.value)
    case .folder:
      NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: action.value)
    default:
      print("\(action.type) unknown")
    }
  }

  private func clear() {
    userState.clear()
  }
}

class DontActivateConfiguration {
  let configuration = NSWorkspace.OpenConfiguration()

  static var shared = DontActivateConfiguration()

  init() {
    configuration.activates = false
  }
}
