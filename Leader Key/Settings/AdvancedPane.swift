import Defaults
import KeyboardShortcuts
import LaunchAtLogin
import Settings
import SwiftUI

struct AdvancedPane: View {
  private let contentWidth = 640.0

  @EnvironmentObject private var config: UserConfig

  @Default(.configDir) var configDir
  @Default(.modifierKeyForGroupSequence) var modifierKeyForGroupSequence
  @Default(.autoOpenCheatsheet) var autoOpenCheatsheet
  @Default(.cheatsheetDelayMS) var cheatsheetDelayMS

  var body: some View {
    Settings.Container(contentWidth: contentWidth) {
      Settings.Section(
        title: "Config directory",
        bottomDivider: true
      ) {
        HStack {
          Text(configDir).lineLimit(1).truncationMode(.middle)
        }
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
          Button("Reveal") {
            NSWorkspace.shared.activateFileViewerSelecting([
              config.url
            ])
          }

          Button("Reset") {
            configDir = UserConfig.defaultDirectory()
          }
        }
      }

      Settings.Section(
        title: "Run Group Modifier", bottomDivider: true
      ) {
        Picker("Modifier", selection: $modifierKeyForGroupSequence) {
          ForEach(ModifierKey.allCases, id: \.self) { key in
            Text(key.rawValue.capitalized).tag(key)
          }
        }.labelsHidden()
          .pickerStyle(MenuPickerStyle())
          .frame(width: 120)
        Text(
          "When held while pressing a group key, run all actions in that group and its sub-groups."
        )
        .padding(.top, 2)
      }

      Settings.Section(title: "Cheatsheet", bottomDivider: true) {
        HStack(alignment: .firstTextBaseline) {
          Picker("Show", selection: $autoOpenCheatsheet) {
            Text("Always").tag(AutoOpenCheatsheetSetting.always)
            Text("After …").tag(AutoOpenCheatsheetSetting.delay)
            Text("Never").tag(AutoOpenCheatsheetSetting.never)
          }.frame(width: 120)

          if autoOpenCheatsheet == .delay {
            TextField(
              "", value: $cheatsheetDelayMS, formatter: NumberFormatter()
            )
            .frame(width: 50)
            Text("milliseconds")
          }

          Spacer()
        }

        Text(
          "The cheatsheet can always be manually shown by \"?\" when Leader Key is activated."
        )
        .padding(.vertical, 2)

        Defaults.Toggle(
          "Show expanded groups in cheatsheet", key: .expandGroupsInCheatsheet)
        Defaults.Toggle(
          "Show application icons", key: .showAppIconsInCheatsheet)
      }

      Settings.Section(title: "Other") {
        Defaults.Toggle("Show Leader Key in menubar", key: .showMenuBarIcon)
        Defaults.Toggle(
          "Force English keyboard layout", key: .forceEnglishKeyboardLayout)
      }
    }
  }
}

struct AdvancedPane_Previews: PreviewProvider {
  static var previews: some View {
    return AdvancedPane()
    //      .environmentObject(UserConfig())
  }
}
