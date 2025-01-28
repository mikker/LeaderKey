import Cocoa
import Combine
import Defaults

let emptyRoot = Group(key: "🚫", label: "Config error", actions: [])

class UserConfig: ObservableObject {
  @Published var root = emptyRoot

  let fileName = "config.json"
  let fileMonitor = FileMonitor()

  var afterReload: ((_ success: Bool) -> Void)?

  static func defaultDirectory() -> String {
    let appSupportDir = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let path = (appSupportDir.path as NSString).appendingPathComponent("Leader Key")
    do {
      try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
    } catch {
      fatalError("Failed to create config directory")
    }
    return path
  }

  func fileURL() -> URL {
    let dir = Defaults[.configDir]
    let filePath = (dir as NSString).appendingPathComponent(fileName)
    return URL(fileURLWithPath: filePath)
  }

  func configExists() -> Bool {
    let path = fileURL().path
    return FileManager.default.fileExists(atPath: path)
  }

  func bootstrapConfig() throws {
    guard let data = defaultConfig.data(using: .utf8) else {
      throw NSError(
        domain: "UserConfig", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Failed to encode default config"])
    }
    let url = fileURL()
    try data.write(to: url, options: [.atomic])
  }

  func readConfigFile() -> String {
    do {
      let path = fileURL().path
      let str = try String(contentsOfFile: path, encoding: .utf8)
      return str
    } catch {
      let alert = NSAlert()
      alert.alertStyle = .critical
      alert.messageText = "\(error)"
      alert.runModal()
      return "{}"
    }
  }

  func loadAndWatch() {
    if !configExists() {
      do {
        try bootstrapConfig()
      } catch {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "\(error)"
        alert.runModal()
        root = emptyRoot
      }
    }

    loadConfig()
    startWatching()
  }

  private func startWatching() {
    self.fileMonitor.startMonitoring(fileURL: fileURL()) {
      self.reloadConfig()
    }
  }

  func loadConfig() {
    if FileManager.default.fileExists(atPath: fileURL().path) {
      if let jsonData = readConfigFile().data(using: .utf8) {
        let decoder = JSONDecoder()
        do {
          let root_ = try decoder.decode(Group.self, from: jsonData)
          root = root_
        } catch {
          handleConfigError(error)
        }
      } else {
        root = emptyRoot
      }
    } else {
      root = emptyRoot
    }
  }

  private func handleConfigError(_ error: Error) {
    let alert = NSAlert()
    alert.alertStyle = .critical
    alert.messageText = "\(error)"
    alert.runModal()
    root = emptyRoot
  }

  func reloadConfig() {
    loadConfig()
    afterReload?(true)
  }

  func saveConfig() {
    fileMonitor.stopMonitoring()

    do {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
      let jsonData = try encoder.encode(root)
      try jsonData.write(to: fileURL())
    } catch {
      handleConfigError(error)
    }

    // Resume monitoring
    reloadConfig()
    startWatching()
  }
}

let defaultConfig = """
  {
      "type": "group",
      "actions": [
          { "key": "t", "type": "application", "value": "/System/Applications/Utilities/Terminal.app" },
          {
              "key": "o",
              "type": "group",
              "actions": [
                  { "key": "s", "type": "application", "value": "/Applications/Safari.app" },
                  { "key": "e", "type": "application", "value": "/Applications/Mail.app" },
                  { "key": "i", "type": "application", "value": "/System/Applications/Music.app" },
                  { "key": "m", "type": "application", "value": "/Applications/Messages.app" }
              ]
          },
          {
              "key": "r",
              "type": "group",
              "actions": [
                  { "key": "e", "type": "url", "value": "raycast://extensions/raycast/emoji-symbols/search-emoji-symbols" },
                  { "key": "p", "type": "url", "value": "raycast://confetti" },
                  { "key": "c", "type": "url", "value": "raycast://extensions/raycast/system/open-camera" }
              ]
          }
      ]
  }
  """

enum Type: String, Codable {
  case group
  case application
  case url
  case command
  case folder
}

protocol Item {
  var key: String? { get }
  var type: Type { get }
  var label: String? { get }
  var displayName: String { get }
}

struct Action: Item, Codable {
  var key: String?
  var type: Type
  var label: String?

  var value: String

  var displayName: String {
    guard let labelValue = label else { return bestGuessDisplayName }
    guard !labelValue.isEmpty else { return bestGuessDisplayName }
    return labelValue
  }

  var bestGuessDisplayName: String {
    switch type {
    case .application:
      return (value as NSString).lastPathComponent.replacingOccurrences(
        of: ".app", with: "")
    case .command:
      return value.components(separatedBy: " ").first ?? value
    case .folder:
      return (value as NSString).lastPathComponent
    case .url:
      return "URL"
    default:
      return value
    }
  }
}

struct Group: Item, Codable {
  var key: String?
  var type: Type = .group
  var label: String?
  var actions: [ActionOrGroup]

  var displayName: String {
    return label ?? "Group"
  }
}

enum ActionOrGroup: Codable {
  case action(Action)
  case group(Group)

  private enum CodingKeys: String, CodingKey {
    case key, type, value, actions, label
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let key = try container.decode(String?.self, forKey: .key)
    let type = try container.decode(Type.self, forKey: .type)
    let label = try container.decodeIfPresent(String.self, forKey: .label) ?? ""

    switch type {
    case .group:
      let actions = try container.decode([ActionOrGroup].self, forKey: .actions)
      self = .group(Group(key: key, label: label, actions: actions))
    default:
      let value = try container.decode(String.self, forKey: .value)
      self = .action(Action(key: key, type: type, label: label, value: value))
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case let .action(action):
      try container.encode(action.key, forKey: .key)
      try container.encode(action.type, forKey: .type)
      try container.encode(action.value, forKey: .value)
      try container.encode(action.label, forKey: .label)
    case let .group(group):
      try container.encode(group.key, forKey: .key)
      try container.encode(Type.group, forKey: .type)
      try container.encode(group.actions, forKey: .actions)
      try container.encode(group.label, forKey: .label)
    }
  }
}
