import Cocoa
import Combine
import Defaults

class UserConfig: ObservableObject {
  @Published var root = Group(actions: [])

  let fileName = "config.json"
  let fileMonitor = FileMonitor()

  var afterReload: ((_ success: Bool) -> Void)?

  func fileURL() -> URL {
    let appSupportDir = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let path = (appSupportDir.path as NSString).appendingPathComponent("Leader Key")

    // Create directory if it doesn't exist
    try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)

    let filePath = (path as NSString).appendingPathComponent(fileName)
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

    // Verify the file was written
    guard FileManager.default.fileExists(atPath: url.path) else {
      throw NSError(
        domain: "UserConfig", code: 2,
        userInfo: [NSLocalizedDescriptionKey: "File was not created after write"])
    }
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
        root = Group(actions: [])
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
        root = Group(actions: [])
      }
    } else {
      root = Group(actions: [])
    }
  }

  private func handleConfigError(_ error: Error) {
    let alert = NSAlert()
    alert.alertStyle = .critical
    alert.messageText = "\(error)"
    alert.runModal()
    root = Group(actions: [])
  }

  func reloadConfig() {
    loadConfig()
    afterReload?(true)
  }

  func saveConfig() {
    // Stop monitoring temporarily
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

struct Action: Codable {
  var key: String
  var type: Type
  var value: String
}

struct Group: Codable {
  var key: String?
  var type: Type = .group
  var actions: [ActionOrGroup]
}

enum ActionOrGroup: Codable {
  case action(Action)
  case group(Group)

  private enum CodingKeys: String, CodingKey {
    case key, type, value, actions
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let key = try container.decode(String.self, forKey: .key)
    let type = try container.decode(Type.self, forKey: .type)
    switch type {
    case .group:
      let actions = try container.decode([ActionOrGroup].self, forKey: .actions)
      self = .group(Group(key: key, actions: actions))
    default:
      let value = try container.decode(String.self, forKey: .value)
      self = .action(Action(key: key, type: type, value: value))
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case let .action(action):
      try container.encode(action.key, forKey: .key)
      try container.encode(action.type, forKey: .type)
      try container.encode(action.value, forKey: .value)
    case let .group(group):
      try container.encode(group.key, forKey: .key)
      try container.encode(Type.group, forKey: .type)
      try container.encode(group.actions, forKey: .actions)
    }
  }
}
