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

      Settings.Section(title: "Shortcut") {
        KeyboardShortcuts.Recorder(for: .activate)
      }

      Settings.Section(title: "App") {
        LaunchAtLogin.Toggle()
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
