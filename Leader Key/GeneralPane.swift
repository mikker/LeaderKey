import Defaults
import KeyboardShortcuts
import LaunchAtLogin
import Settings
import SwiftUI

struct GeneralPane: View {
  private let contentWidth = 720.0
  @EnvironmentObject private var config: UserConfig
  @Default(.configDir) var configDir

  var body: some View {
    Settings.Container(contentWidth: contentWidth) {
      Settings.Section(
        title: "Config", bottomDivider: true, verticalAlignment: .top
      ) {
        VStack(alignment: .leading, spacing: 8) {
          VStack {
            ConfigEditorView(group: $config.root)
              .frame(height: 500)
          }
          .padding(8)
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .inset(by: 1)
              .stroke(Color.primary, lineWidth: 1)
              .opacity(0.1)
          )

          HStack {
            Button("Save to file") {
              config.saveConfig()
            }

            Button("Reload from file") {
              config.reloadConfig()
            }
          }
        }
      }

      Settings.Section(title: "Directory", bottomDivider: true) {
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

      Settings.Section(title: "Shortcut") {
        KeyboardShortcuts.Recorder(for: .activate)
      }

      Settings.Section(title: "App") {
        LaunchAtLogin.Toggle()
        Defaults.Toggle("Show Leader Key in menubar", key: .showMenuBarIcon)
        Defaults.Toggle("Force English QWERTY keyboard layout", key: .useEnglishKeyMap)
      }
    }
  }
}

struct GeneralPane_Previews: PreviewProvider {
  static var previews: some View {
    return GeneralPane()
      .environmentObject(UserConfig())
  }
}
