import Cocoa
import Combine
import Defaults

let emptyRoot = Group(key: "🚫", label: "Config error", actions: [])

class UserConfig: ObservableObject {
  @Published var root = emptyRoot

  let fileName = "config.json"
  private let alertHandler: AlertHandler
  private let fileManager: FileManager

  var afterReload: ((_ success: Bool) -> Void)?

  init(
    alertHandler: AlertHandler = DefaultAlertHandler(),
    fileManager: FileManager = .default
  ) {
    self.alertHandler = alertHandler
    self.fileManager = fileManager
  }

  // MARK: - Public Interface

  func ensureAndLoad() {
    ensureValidConfigDirectory()
    ensureConfigFileExists()
    loadConfig()
  }

  func reloadConfig() {
    loadConfig()
    afterReload?(true)
  }

  func saveConfig() {
    do {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [
        .prettyPrinted, .withoutEscapingSlashes, .sortedKeys,
      ]
      let jsonData = try encoder.encode(root)
      try writeFile(data: jsonData)
    } catch {
      handleError(error, critical: true)
    }

    reloadConfig()
  }

  // MARK: - Directory Management

  static func defaultDirectory() -> String {
    let appSupportDir = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let path = (appSupportDir.path as NSString).appendingPathComponent(
      "Leader Key")
    do {
      try FileManager.default.createDirectory(
        atPath: path, withIntermediateDirectories: true)
    } catch {
      fatalError("Failed to create config directory")
    }
    return path
  }

  private func ensureValidConfigDirectory() {
    let dir = Defaults[.configDir]
    let defaultDir = Self.defaultDirectory()

    if !fileManager.fileExists(atPath: dir) {
      alertHandler.showAlert(
        style: .warning,
        message:
          "Config directory does not exist: \(dir)\nResetting to default location."
      )
      Defaults[.configDir] = defaultDir
    }
  }

  // MARK: - File Operations

  /// The path to the config file
  var path: String {
    (Defaults[.configDir] as NSString).appendingPathComponent(fileName)
  }

  /// The URL to the config file
  var url: URL {
    URL(fileURLWithPath: path)
  }

  /// Whether the config file exists
  var exists: Bool {
    fileManager.fileExists(atPath: path)
  }

  private func ensureConfigFileExists() {
    guard !exists else { return }

    do {
      try bootstrapConfig()
    } catch {
      handleError(error, critical: true)
    }
  }

  private func bootstrapConfig() throws {
    guard let data = defaultConfig.data(using: .utf8) else {
      throw NSError(
        domain: "UserConfig",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Failed to encode default config"]
      )
    }
    try writeFile(data: data)
  }

  private func writeFile(data: Data) throws {
    try data.write(to: url, options: [.atomic])
  }

  private func readFile() throws -> String {
    try String(contentsOfFile: path, encoding: .utf8)
  }

  // MARK: - Config Loading

  private func loadConfig() {
    guard exists else {
      root = emptyRoot
      return
    }

    do {
      let configString = try readFile()

      guard let jsonData = configString.data(using: .utf8) else {
        throw NSError(
          domain: "UserConfig",
          code: 1,
          userInfo: [
            NSLocalizedDescriptionKey: "Failed to encode config file as UTF-8"
          ]
        )
      }

      let decoder = JSONDecoder()
      root = try decoder.decode(Group.self, from: jsonData)
    } catch {
      handleError(error, critical: true)
    }
  }

  // MARK: - Error Handling

  private func handleError(_ error: Error, critical: Bool) {
    alertHandler.showAlert(
      style: critical ? .critical : .warning, message: "\(error)")
    if critical {
      root = emptyRoot
    }
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

struct Action: Item, Codable, Equatable {
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

struct Group: Item, Codable, Equatable {
  var key: String?
  var type: Type = .group
  var label: String?
  var actions: [ActionOrGroup]

  var displayName: String {
    guard let labelValue = label else { return "Group" }
    if labelValue.isEmpty { return "Group" }
    return labelValue
  }

  static func == (lhs: Group, rhs: Group) -> Bool {
    return lhs.key == rhs.key && lhs.type == rhs.type && lhs.label == rhs.label
      && lhs.actions == rhs.actions
  }
}

enum ActionOrGroup: Codable, Equatable {
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
    case .action(let action):
      try container.encode(action.key, forKey: .key)
      try container.encode(action.type, forKey: .type)
      try container.encode(action.value, forKey: .value)
      try container.encode(action.label, forKey: .label)
    case .group(let group):
      try container.encode(group.key, forKey: .key)
      try container.encode(Type.group, forKey: .type)
      try container.encode(group.actions, forKey: .actions)
      try container.encode(group.label, forKey: .label)
    }
  }
}

enum ModifierKey: String, Codable, Defaults.Serializable, CaseIterable,
  Identifiable
{
  case none
  case control
  case option

  var id: Self { self }

  var flag: NSEvent.ModifierFlags? {
    switch self {
    case .control: return .control
    case .option: return .option
    default: return nil
    }
  }
}
