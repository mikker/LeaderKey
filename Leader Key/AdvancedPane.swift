import Defaults
import KeyboardShortcuts
import LaunchAtLogin
import Settings
import SwiftUI

struct AdvancedPane: View {
  private let contentWidth = 640.0
  @EnvironmentObject private var config: UserConfig
  @Default(.configDir) var configDir
  @Default(.requiredShakeCount) private var requiredShakeCount
  @State private var shakeSettingsChanged = false

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

      Settings.Section(title: "Shake Mouse", bottomDivider: true) {
        Defaults.Toggle("Enable shake to show menu", key: .enableShakeToShow)
          .help("Shake mouse cursor horizontally to show the menu")
          .onChange(of: Defaults[.enableShakeToShow]) { _ in
            shakeSettingsChanged = true
          }

        if Defaults[.enableShakeToShow] {
          HStack {
            Text("Required shakes:")
            Stepper("\(requiredShakeCount)", value: $requiredShakeCount, in: 2...9)
              .help("Number of direction changes needed to trigger the menu")
              .onChange(of: requiredShakeCount) { _ in
                shakeSettingsChanged = true
              }
          }
        }

        if shakeSettingsChanged {
          HStack {
            Text("Restart required to apply changes")
              .foregroundColor(.secondary)
            Button("Restart Now") {
              restartApp()
            }
            .buttonStyle(.borderedProminent)
          }
          .padding(.top, 8)
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

  private func restartApp() {
    let url = Bundle.main.bundleURL
    let configuration = NSWorkspace.OpenConfiguration()
    NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
      NSApp.terminate(nil)
    }
  }
}

struct AdvancedPane_Previews: PreviewProvider {
  static var previews: some View {
    return AdvancedPane()
      .environmentObject(UserConfig())
  }
}
