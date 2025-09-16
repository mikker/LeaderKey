import Defaults
import KeyboardShortcuts
import LaunchAtLogin
import Settings
import SwiftUI

struct GeneralPane: View {
  private let contentWidth = 720.0
  @EnvironmentObject private var config: UserConfig
  @Default(.configDir) var configDir
  @Default(.theme) var theme

  var body: some View {
    Settings.Container(contentWidth: contentWidth) {
      Settings.Section(
        title: "Config", bottomDivider: true, verticalAlignment: .top
      ) {
        VStack(alignment: .leading, spacing: 8) {
          // AppKit-backed editor for maximum smoothness
          ConfigOutlineEditorView(root: $config.root)
            .frame(height: 500)
            .overlay(
              RoundedRectangle(cornerRadius: 12)
                .inset(by: 1)
                .stroke(Color.primary, lineWidth: 1)
                .opacity(0.1)
            )

          if !config.validationErrors.isEmpty {
            ValidationWarningView(errors: config.validationErrors)
              .transition(.opacity)
          }

          HStack {
            // Left-aligned buttons
            HStack(spacing: 8) {
              Button(action: {
                config.root.actions.append(.action(Action(key: "", type: .application, value: "")))
              }) {
                Image(systemName: "rays")
                Text("Add Action")
              }

              Button(action: {
                config.root.actions.append(.group(Group(key: "", actions: [])))
              }) {
                Image(systemName: "folder")
                Text("Add Group")
              }

              Divider()
                .frame(height: 20)

              Button("Read from file") {
                config.reloadFromFile()
              }
            }

            Spacer()

            // Right-aligned buttons
            HStack(spacing: 8) {
              Button(action: {
                NotificationCenter.default.post(name: .lkExpandAll, object: nil)
              }) {
                Image(systemName: "chevron.down")
                Text("All")
              }

              Button(action: {
                NotificationCenter.default.post(name: .lkCollapseAll, object: nil)
              }) {
                Image(systemName: "chevron.right")
                Text("All")
              }

              Button(action: {
                NotificationCenter.default.post(name: .lkSortAZ, object: nil)
              }) {
                Image(systemName: "arrow.up.arrow.down")
                Text("Sort")
              }
            }
          }
        }
      }

      Settings.Section(title: "Shortcut") {
        KeyboardShortcuts.Recorder(for: .activate)
      }

      Settings.Section(title: "Theme") {
        Picker("Theme", selection: $theme) {
          ForEach(Theme.all, id: \.self) { value in
            Text(Theme.name(value)).tag(value)
          }
        }.frame(maxWidth: 170).labelsHidden()
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

/// Compact banner that surfaces validation issues directly in the settings UI.
private struct ValidationWarningView: View {
  private let errors: [ValidationError]
  private let maxVisibleErrors = 3

  init(errors: [ValidationError]) {
    self.errors = errors
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(warningTitle)
        .font(.callout)
        .fontWeight(.semibold)

      VStack(alignment: .leading, spacing: 2) {
        ForEach(Array(errors.prefix(maxVisibleErrors))) { error in
          Text("• \(error.message)")
            .font(.caption)
        }

        if errors.count > maxVisibleErrors {
          Text("• …and \(errors.count - maxVisibleErrors) more issues")
            .font(.caption)
        }

        Text(
          "Configuration saves continue, but shortcuts tied to these keys may misbehave until fixed."
        )
        .font(.caption)
        .padding(.top, 4)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(nsColor: .textBackgroundColor))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color.red.opacity(0.6), lineWidth: 1)
    )
    .cornerRadius(8)
    .foregroundColor(.red)
  }

  private var warningTitle: String {
    let count = errors.count
    let issueText = count == 1 ? "1 issue" : "\(count) issues"
    let pronoun = count == 1 ? "it" : "they"
    return "Configuration has \(issueText). Some shortcuts may not work until \(pronoun) are fixed."
  }
}
