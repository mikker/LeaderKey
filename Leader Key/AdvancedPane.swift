import Defaults
import KeyboardShortcuts
import LaunchAtLogin
import Settings
import SwiftUI

struct AdvancedPane: View {
  private let contentWidth = 640.0
  @EnvironmentObject private var config: UserConfig
  @Default(.configDir) var configDir

  var body: some View {
    Settings.Container(contentWidth: contentWidth) {
      Settings.Section(
        title: "Config directory",
        bottomDivider: true
      ) {
        HStack {
          Button("Choose…") {
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            if panel.runModal() != .OK { return }
            guard let selectedPath = panel.url else { return }
            configDir = selectedPath.path
          }

          Text(configDir).lineLimit(1).truncationMode(.middle)

          Spacer()

          Button("Reveal") {
            NSWorkspace.shared.activateFileViewerSelecting([
              config.fileURL()
            ])
          }

          Button("Reset") {
            configDir = UserConfig.defaultDirectory()
          }
        }
      }

      Settings.Section(title: "Cheatsheet", bottomDivider: true) {
        Defaults.Toggle("Always show cheatsheet", key: .alwaysShowCheatsheet)
        Defaults.Toggle("Show expanded groups in cheatsheet", key: .expandGroupsInCheatsheet)
      }

      Settings.Section(title: "Other") {
        Defaults.Toggle("Show Leader Key in menubar", key: .showMenuBarIcon)
        Defaults.Toggle("Force English keyboard layout", key: .forceEnglishKeyboardLayout)
      }
    }
  }
}

struct AdvancedPane_Previews: PreviewProvider {
  static var previews: some View {
    return AdvancedPane()
      .environmentObject(UserConfig())
  }
}
