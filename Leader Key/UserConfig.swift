import Cocoa
import Combine
import CryptoKit
import Defaults

let emptyRoot = Group(key: "🚫", label: "Config error", actions: [])

/// Configuration file format
enum ConfigFormat {
  case json
  case toml

  var fileExtension: String {
    switch self {
    case .json: return "json"
    case .toml: return "toml"
    }
  }

  var fileName: String {
    "config.\(fileExtension)"
  }
}

class UserConfig: ObservableObject {
  @Published var root = emptyRoot {
    didSet {
      if !isLoading && root != emptyRoot && root != oldValue {
        saveConfigAsync()
      }
    }
  }
  @Published var validationErrors: [ValidationError] = []
  // O(1) lookup for row validation; keys are path strings like "1/0/3"
  @Published var validationErrorsByPath: [String: ValidationErrorType] = [:]

  /// Current configuration format (detected on load)
  @Published private(set) var configFormat: ConfigFormat = .toml

  private let alertHandler: AlertHandler
  private let fileManager: FileManager
  private var lastReadChecksum: String?
  private var isLoading = false
  private let configIOQueue = DispatchQueue(label: "ConfigIO", qos: .userInitiated)
  private var saveWorkItem: DispatchWorkItem?

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

  func reloadFromFile() {
    Events.send(.willReload)
    loadConfig(suppressAlerts: true)
    Events.send(.didReload)
  }

  func saveConfig() {
    // Check for file conflicts before saving
    if let lastChecksum = lastReadChecksum, exists {
      let currentChecksum = getCurrentFileChecksum()
      if currentChecksum != lastChecksum {
        let result = alertHandler.showAlert(
          style: .warning,
          message: "Configuration file changed on disk",
          informativeText:
            "The configuration file has been modified outside of the app. Choose 'Read from File' to load the external changes, or 'Overwrite' to save your current changes.",
          buttons: ["Overwrite", "Cancel", "Read from File"]
        )

        switch result {
        case .alertThirdButtonReturn:  // Read from File (rightmost, default)
          reloadFromFile()
          return
        case .alertFirstButtonReturn:  // Overwrite
          break  // Continue with save
        default:  // Cancel
          return
        }
      }
    }

    setValidationErrors(ConfigValidator.validate(group: root))

    do {
      let data = try encodeConfigData(for: root, format: configFormat)

      try writeFile(data: data)

      // Update checksum after successful write using data directly
      lastReadChecksum = calculateChecksum(data)
    } catch {
      handleError(error, critical: true)
    }
  }

  private func saveConfigAsync() {
    // Cancel any pending save
    saveWorkItem?.cancel()

    // Create a new debounced save work item
    let currentRoot = root
    let currentFormat = configFormat
    let workItem = DispatchWorkItem { [weak self] in
      guard let self = self else { return }

      do {
        let configData = try self.encodeConfigData(for: currentRoot, format: currentFormat)

        // Check conflicts on background queue first, then switch to main for UI
        if let lastChecksum = self.lastReadChecksum, self.exists {
          let currentChecksum = self.getCurrentFileChecksum()
          if currentChecksum != lastChecksum {
            DispatchQueue.main.async {
              let result = self.alertHandler.showAlert(
                style: .warning,
                message: "Configuration file changed on disk",
                informativeText:
                  "The configuration file has been modified outside of the app. Choose 'Read from File' to load the external changes, or 'Overwrite' to save your current changes.",
                buttons: ["Overwrite", "Cancel", "Read from File"]
              )

              switch result {
              case .alertThirdButtonReturn:  // Read from File
                self.reloadFromFile()
                return
              case .alertFirstButtonReturn:  // Overwrite
                break  // Continue with save
              default:  // Cancel
                return
              }

              // Continue with save after conflict resolution
              self.performSaveWithData(configData, currentRoot: currentRoot)
            }
            return
          }
        }

        DispatchQueue.main.async {
          self.performSaveWithData(configData, currentRoot: currentRoot)
        }
      } catch {
        DispatchQueue.main.async {
          self.handleError(error, critical: true)
        }
      }
    }

    saveWorkItem = workItem

    // Execute with 300ms debounce
    configIOQueue.asyncAfter(deadline: .now() + .milliseconds(300), execute: workItem)
  }

  private func performSaveWithData(_ configData: Data, currentRoot: Group) {
    // Validation on main queue
    let validationErrors = ConfigValidator.validate(group: currentRoot)
    setValidationErrors(validationErrors)

    // Back to background for file write
    configIOQueue.async { [weak self] in
      guard let self = self else { return }

      do {
        try self.writeFile(data: configData)

        DispatchQueue.main.async {
          // Update checksum on main queue using data directly
          self.lastReadChecksum = self.calculateChecksum(configData)
        }
      } catch {
        DispatchQueue.main.async {
          self.handleError(error, critical: true)
        }
      }
    }
  }

  private func encodeConfigData(for root: Group, format: ConfigFormat) throws -> Data {
    switch format {
    case .json:
      let encoder = JSONEncoder()
      encoder.outputFormatting = [
        .prettyPrinted, .withoutEscapingSlashes, .sortedKeys,
      ]
      return try encoder.encode(root)

    case .toml:
      let tomlString = TOMLConfig.serialize(root)
      guard let tomlData = tomlString.data(using: .utf8) else {
        throw NSError(
          domain: "UserConfig",
          code: 1,
          userInfo: [NSLocalizedDescriptionKey: "Failed to encode TOML as UTF-8"]
        )
      }
      return tomlData
    }
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

  /// Path to the current config file (TOML preferred, falls back to JSON)
  var path: String {
    path(for: configFormat)
  }

  /// Path for a specific format
  func path(for format: ConfigFormat) -> String {
    (Defaults[.configDir] as NSString).appendingPathComponent(format.fileName)
  }

  var url: URL {
    URL(fileURLWithPath: path)
  }

  var exists: Bool {
    fileManager.fileExists(atPath: path(for: .toml))
      || fileManager.fileExists(atPath: path(for: .json))
  }

  /// Detect which config format exists (TOML preferred)
  func detectConfigFormat() -> ConfigFormat {
    let tomlPath = path(for: .toml)
    let jsonPath = path(for: .json)

    if fileManager.fileExists(atPath: tomlPath) {
      return .toml
    } else if fileManager.fileExists(atPath: jsonPath) {
      return .json
    }
    // Default to TOML for new configs
    return .toml
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
    // Create TOML config by default
    guard let data = defaultConfigTOML.data(using: .utf8) else {
      throw NSError(
        domain: "UserConfig",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Failed to encode default config"]
      )
    }
    configFormat = .toml
    let tomlPath = path(for: .toml)
    try data.write(to: URL(fileURLWithPath: tomlPath), options: .atomic)
  }

  private func writeFile(data: Data) throws {
    try data.write(to: url, options: .atomic)
  }

  private func readFile() throws -> String {
    try String(contentsOfFile: path, encoding: .utf8)
  }

  private func calculateChecksum(_ content: String) -> String {
    let data = Data(content.utf8)
    return calculateChecksum(data)
  }

  private func calculateChecksum(_ data: Data) -> String {
    let digest = SHA256.hash(data: data)
    return digest.compactMap { String(format: "%02x", $0) }.joined()
  }

  private func getCurrentFileChecksum() -> String? {
    guard exists else { return nil }
    do {
      let content = try readFile()
      return calculateChecksum(content)
    } catch {
      return nil
    }
  }

  // Background queue version
  private func getCurrentFileChecksumAsync(completion: @escaping (String?) -> Void) {
    configIOQueue.async { [weak self] in
      guard let self = self else {
        DispatchQueue.main.async { completion(nil) }
        return
      }

      let checksum = self.getCurrentFileChecksum()
      DispatchQueue.main.async { completion(checksum) }
    }
  }

  // MARK: - Config Loading

  private func loadConfig(suppressAlerts: Bool = false) {
    isLoading = true

    guard exists else {
      root = emptyRoot
      validationErrors = []
      isLoading = false
      return
    }

    let format = detectConfigFormat()

    configIOQueue.async { [weak self] in
      guard let self = self else { return }

      do {
        let configPath = self.path(for: format)
        let configString = try String(contentsOfFile: configPath, encoding: .utf8)

        let decodedRoot: Group

        switch format {
        case .json:
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
          decodedRoot = try decoder.decode(Group.self, from: jsonData)

        case .toml:
          decodedRoot = try TOMLConfig.parse(configString)
        }

        let checksum = self.calculateChecksum(configString)
        let validationErrors = ConfigValidator.validate(group: decodedRoot)

        DispatchQueue.main.async {
          self.configFormat = format
          self.root = decodedRoot
          self.lastReadChecksum = checksum
          self.setValidationErrors(validationErrors)
          self.isLoading = false
        }
      } catch {
        DispatchQueue.main.async {
          self.handleError(error, critical: false)
          self.isLoading = false
        }
      }
    }
  }

  /// Convert current JSON config to TOML
  func convertToTOML() {
    let tomlContent = TOMLConfig.serialize(root)
    let tomlPath = path(for: .toml)
    let jsonPath = path(for: .json)
    let backupPath = jsonPath + ".backup"
    let checksum = calculateChecksum(tomlContent)

    func finalizeConversion(style: NSAlert.Style, informativeText: String) {
      DispatchQueue.main.async {
        self.configFormat = .toml
        self.lastReadChecksum = checksum
        _ = self.alertHandler.showAlert(
          style: style,
          message: "Configuration converted",
          informativeText: informativeText,
          buttons: ["OK"]
        )
      }
    }

    do {
      // Write TOML file
      try tomlContent.write(toFile: tomlPath, atomically: true, encoding: .utf8)

      // Rename JSON file as backup
      if fileManager.fileExists(atPath: jsonPath) {
        if fileManager.fileExists(atPath: backupPath) {
          try fileManager.removeItem(atPath: backupPath)
        }
        try fileManager.moveItem(atPath: jsonPath, toPath: backupPath)
        finalizeConversion(
          style: .informational,
          informativeText:
            "Your configuration has been converted to TOML format.\nBackup saved as config.json.backup"
        )
      } else {
        finalizeConversion(
          style: .warning,
          informativeText:
            "Your configuration has been converted to TOML format.\nNo JSON config was found to back up."
        )
      }
    } catch {
      DispatchQueue.main.async {
        _ = self.alertHandler.showAlert(
          style: .warning,
          message: "Conversion failed",
          informativeText: "Failed to convert configuration: \(error.localizedDescription)",
          buttons: ["OK"]
        )
      }
    }
  }

  // MARK: - Validation

  func validateWithoutAlerts() {
    setValidationErrors(ConfigValidator.validate(group: root))
  }

  func finishEditingKey() {
    validateWithoutAlerts()
    // Config saves automatically via didSet on root
  }

  // MARK: - Error Handling

  private func handleError(_ error: Error, critical: Bool) {
    alertHandler.showAlert(
      style: critical ? .critical : .warning, message: "\(error)")
    if critical {
      root = emptyRoot
      validationErrors = []
    }
  }
}

// MARK: - Validation helpers
extension UserConfig {
  private func pathKey(_ path: [Int]) -> String { path.map(String.init).joined(separator: "/") }

  func setValidationErrors(_ errors: [ValidationError]) {
    validationErrors = errors
    var map: [String: ValidationErrorType] = [:]
    for e in errors {
      map[pathKey(e.path)] = e.type
    }
    validationErrorsByPath = map
  }

  func validationError(at path: [Int]) -> ValidationErrorType? {
    validationErrorsByPath[pathKey(path)]
  }
}

let defaultConfigTOML = """
  # Leader Key Configuration
  # Edit this file to customize your keyboard shortcuts

  # Simple shortcuts - just press the key after the leader key
  t = "Terminal"

  # Groups organize related shortcuts
  [o]
  label = "[apps]"
  s = "Safari"
  e = "Mail"
  i = "Music"
  m = "Messages"

  [r]
  label = "[raycast]"
  e = ["raycast://extensions/raycast/emoji-symbols/search-emoji-symbols", "emoji"]
  p = ["raycast://confetti", "confetti"]
  c = ["raycast://extensions/raycast/system/open-camera", "camera"]
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
  var iconPath: String? { get set }
}

struct Action: Item, Codable, Equatable {
  // UI-only stable identity. Not persisted to config.
  var uiid: UUID = UUID()

  var key: String?
  var type: Type
  var label: String?
  var value: String
  var iconPath: String?

  var displayName: String {
    if let labelValue = label, !labelValue.isEmpty {
      return labelValue
    }
    return bestGuessDisplayName
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
  private enum CodingKeys: String, CodingKey { case key, type, label, value, iconPath }

  init(
    uiid: UUID = UUID(), key: String?, type: Type, label: String? = nil, value: String,
    iconPath: String? = nil
  ) {
    self.uiid = uiid
    self.key = key
    self.type = type
    self.label = label
    self.value = value
    self.iconPath = iconPath
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.uiid = UUID()
    self.key = try c.decodeIfPresent(String.self, forKey: .key)
    self.type = try c.decode(Type.self, forKey: .type)
    self.label = try c.decodeIfPresent(String.self, forKey: .label)
    self.value = try c.decode(String.self, forKey: .value)
    self.iconPath = try c.decodeIfPresent(String.self, forKey: .iconPath)
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    // Always encode key in textual form for JSON
    if let keyValue = key {
      let textualKey = KeyMaps.text(for: keyValue) ?? keyValue
      try c.encode(textualKey, forKey: .key)
    }
    try c.encode(type, forKey: .type)
    try c.encode(value, forKey: .value)
    if let l = label, !l.isEmpty { try c.encode(l, forKey: .label) }
    try c.encodeIfPresent(iconPath, forKey: .iconPath)
  }
}

struct Group: Item, Codable, Equatable {
  // UI-only stable identity. Not persisted to JSON.
  var uiid: UUID = UUID()

  var key: String?
  var type: Type = .group
  var label: String?
  var iconPath: String?
  var actions: [ActionOrGroup]

  var displayName: String {
    if let labelValue = label, !labelValue.isEmpty {
      return labelValue
    }
    return "Group"
  }

  static func == (lhs: Group, rhs: Group) -> Bool {
    return lhs.key == rhs.key && lhs.type == rhs.type && lhs.label == rhs.label
      && lhs.iconPath == rhs.iconPath && lhs.actions == rhs.actions
  }
  private enum CodingKeys: String, CodingKey { case key, type, label, iconPath, actions }

  init(
    uiid: UUID = UUID(), key: String?, type: Type = .group, label: String? = nil,
    iconPath: String? = nil, actions: [ActionOrGroup]
  ) {
    self.uiid = uiid
    self.key = key
    self.type = type
    self.label = label
    self.iconPath = iconPath
    self.actions = actions
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.uiid = UUID()
    self.key = try c.decodeIfPresent(String.self, forKey: .key)
    self.type = .group
    self.label = try c.decodeIfPresent(String.self, forKey: .label)
    self.iconPath = try c.decodeIfPresent(String.self, forKey: .iconPath)
    self.actions = try c.decode([ActionOrGroup].self, forKey: .actions)
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    // Always encode key in textual form for JSON
    if let keyValue = key {
      let textualKey = KeyMaps.text(for: keyValue) ?? keyValue
      try c.encode(textualKey, forKey: .key)
    }
    try c.encode(Type.group, forKey: .type)
    try c.encode(actions, forKey: .actions)
    if let l = label, !l.isEmpty { try c.encode(l, forKey: .label) }
    try c.encodeIfPresent(iconPath, forKey: .iconPath)
  }
}

enum ActionOrGroup: Codable, Equatable {
  case action(Action)
  case group(Group)

  var item: Item {
    switch self {
    case .group(let group): return group
    case .action(let action): return action
    }
  }

  private enum CodingKeys: String, CodingKey {
    case key, type, value, actions, label, iconPath
  }

  var uiid: UUID {
    switch self {
    case .action(let a): return a.uiid
    case .group(let g): return g.uiid
    }
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let key = try container.decode(String?.self, forKey: .key)
    let type = try container.decode(Type.self, forKey: .type)
    let label = try container.decodeIfPresent(String.self, forKey: .label)
    let iconPath = try container.decodeIfPresent(String.self, forKey: .iconPath)

    switch type {
    case .group:
      let actions = try container.decode([ActionOrGroup].self, forKey: .actions)
      self = .group(Group(key: key, label: label, iconPath: iconPath, actions: actions))
    default:
      let value = try container.decode(String.self, forKey: .value)
      self = .action(Action(key: key, type: type, label: label, value: value, iconPath: iconPath))
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .action(let action):
      // Always encode key in textual form for JSON
      if let keyValue = action.key {
        let textualKey = KeyMaps.text(for: keyValue) ?? keyValue
        try container.encode(textualKey, forKey: .key)
      } else {
        try container.encodeIfPresent(action.key, forKey: .key)
      }
      try container.encode(action.type, forKey: .type)
      try container.encode(action.value, forKey: .value)
      if let label = action.label, !label.isEmpty {
        try container.encode(label, forKey: .label)
      }
      try container.encodeIfPresent(action.iconPath, forKey: .iconPath)
    case .group(let group):
      // Always encode key in textual form for JSON
      if let keyValue = group.key {
        let textualKey = KeyMaps.text(for: keyValue) ?? keyValue
        try container.encode(textualKey, forKey: .key)
      } else {
        try container.encodeIfPresent(group.key, forKey: .key)
      }
      try container.encode(Type.group, forKey: .type)
      try container.encode(group.actions, forKey: .actions)
      if let label = group.label, !label.isEmpty {
        try container.encode(label, forKey: .label)
      }
      try container.encodeIfPresent(group.iconPath, forKey: .iconPath)
    }
  }
}
