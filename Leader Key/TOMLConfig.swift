import Foundation
import TOMLKit

/// TOML configuration parser and serializer for Leader Key
/// Uses TOMLKit for robust parsing, custom serialization for readable output
struct TOMLConfig {

  enum TOMLError: LocalizedError {
    case invalidValue(message: String)

    var errorDescription: String? {
      switch self {
      case .invalidValue(let message):
        return "Invalid TOML value: \(message)"
      }
    }
  }

  // MARK: - Parsing (using TOMLKit)

  /// Parse TOML string into a Group structure
  static func parse(_ content: String) throws -> Group {
    let table = try TOMLTable(string: content)
    return try parseTable(table, path: [])
  }

  private static func parseTable(_ table: TOMLTable, path: [String]) throws -> Group {
    try parseGroup(from: table, key: path.last)
  }

  private static func parseGroupTable(_ table: TOMLTable, key: String) throws -> Group {
    try parseGroup(from: table, key: key)
  }

  private static func parseGroup(from table: TOMLTable, key: String?) throws -> Group {
    let actions = try parseTableEntries(table)
    let label = extractString(from: table["label"])
    let iconPath = extractString(from: table["icon"])
    return Group(key: key, label: label, iconPath: iconPath, actions: actions)
  }

  /// Parse all entries in a TOML table, skipping metadata keys
  private static func parseTableEntries(_ table: TOMLTable) throws -> [ActionOrGroup] {
    var actions: [ActionOrGroup] = []

    for (key, value) in table {
      guard key != "label", key != "icon" else { continue }

      if let nestedTable = extractTable(from: value) {
        if nestedTable["value"] != nil {
          let action = try parseActionTable(nestedTable, key: key)
          actions.append(.action(action))
        } else {
          let group = try parseGroupTable(nestedTable, key: key)
          actions.append(.group(group))
        }
      } else {
        let action = try parseActionValue(value, key: key)
        actions.append(.action(action))
      }
    }

    return actions
  }

  /// Extract TOMLTable from either TOMLValue wrapper or direct TOMLTable
  private static func extractTable(from value: any TOMLValueConvertible) -> TOMLTable? {
    if let tomlValue = value as? TOMLValue {
      return tomlValue.table
    }
    return value as? TOMLTable
  }

  /// Extract String from either TOMLValue wrapper or direct String
  private static func extractString(from value: (any TOMLValueConvertible)?) -> String? {
    guard let value = value else { return nil }
    if let tomlValue = value as? TOMLValue {
      return tomlValue.string
    }
    return value as? String
  }

  /// Extract TOMLArray from either TOMLValue wrapper or direct TOMLArray
  private static func extractArray(from value: any TOMLValueConvertible) -> TOMLArray? {
    if let tomlValue = value as? TOMLValue {
      return tomlValue.array
    }
    return value as? TOMLArray
  }

  private static func parseActionTable(_ table: TOMLTable, key: String) throws -> Action {
    guard let value = extractString(from: table["value"]) else {
      throw TOMLError.invalidValue(message: "Action table '\(key)' missing 'value' key")
    }

    let label = extractString(from: table["label"])
    let iconPath = extractString(from: table["icon"])
    let explicitType = try extractType(from: table["type"], key: key)

    return createAction(
      key: key,
      value: value,
      label: label,
      iconPath: iconPath,
      explicitType: explicitType
    )
  }

  private static func parseActionValue(_ value: any TOMLValueConvertible, key: String) throws -> Action {
    // Array syntax: ["value", "label"]
    if let array = extractArray(from: value) {
      guard array.count > 0 else {
        throw TOMLError.invalidValue(message: "Empty array for key '\(key)'")
      }
      guard let actionValue = extractString(from: array[0]) else {
        throw TOMLError.invalidValue(message: "First array element must be a string for key '\(key)'")
      }
      let label = array.count > 1 ? extractString(from: array[1]) : nil
      return createAction(key: key, value: actionValue, label: label, iconPath: nil)
    }

    // Simple string value
    if let stringValue = extractString(from: value) {
      return createAction(key: key, value: stringValue, label: nil, iconPath: nil)
    }

    throw TOMLError.invalidValue(message: "Unsupported value type for key '\(key)': \(type(of: value))")
  }

  private static func createAction(
    key: String,
    value: String,
    label: String?,
    iconPath: String?,
    explicitType: Type? = nil
  )
    -> Action
  {
    let resolvedValue = AppResolver.resolve(value)
    let actionType = explicitType ?? inferType(resolvedValue)
    return Action(key: key, type: actionType, label: label, value: resolvedValue, iconPath: iconPath)
  }

  private static func inferType(_ value: String) -> Type {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

    if isURLWithScheme(trimmed) {
      return .url
    }

    if trimmed.hasPrefix("/") || trimmed.hasPrefix("~") {
      if trimmed.lowercased().hasSuffix(".app") {
        return .application
      }
      return .folder
    }

    if AppResolver.findApp(named: trimmed) != nil {
      return .application
    }

    return .command
  }

  // MARK: - Serialization (custom for readable output)

  /// Serialize a Group to TOML format with readable table sections
  static func serialize(_ group: Group) -> String {
    var lines: [String] = ["# Leader Key Configuration", ""]

    let rootActions = group.actions.compactMap { item -> Action? in
      if case .action(let action) = item { return action }
      return nil
    }

    // Serialize inline actions (no icon)
    for action in rootActions where !actionUsesTable(action) {
      lines.append(serializeAction(action))
    }

    // Serialize table actions (with icon)
    for action in rootActions where actionUsesTable(action) {
      if lines.last?.isEmpty == false { lines.append("") }
      lines.append(contentsOf: serializeActionTable(action, path: []))
    }

    // Serialize groups
    for case .group(let subgroup) in group.actions {
      if lines.last?.isEmpty == false { lines.append("") }
      lines.append(contentsOf: serializeGroup(subgroup, path: []))
    }

    return lines.joined(separator: "\n")
  }

  private static func serializeAction(_ action: Action) -> String {
    let key = escapeKey(action.key ?? "?")
    let value = serializeValue(action.value)

    if let label = action.label, !label.isEmpty {
      return "\(key) = [\(value), \(escapeString(label))]"
    }
    return "\(key) = \(value)"
  }

  private static func serializeValue(_ value: String) -> String {
    if value.lowercased().hasSuffix(".app") {
      let appName = (value as NSString).lastPathComponent.replacingOccurrences(
        of: ".app", with: "")
      if AppResolver.resolve(appName) == value {
        return escapeString(appName)
      }
    }
    return escapeString(value)
  }

  private static let bareKeyScalars = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")

  private static func escapeKey(_ key: String) -> String {
    // TOML bare keys are limited to ASCII letters, digits, underscore, and dash.
    let isBareKey = !key.isEmpty && key.unicodeScalars.allSatisfy { bareKeyScalars.contains($0) }
    return isBareKey ? key : escapeString(key)
  }

  private static func escapeString(_ str: String) -> String {
    var escaped = str
    escaped = escaped.replacingOccurrences(of: "\\", with: "\\\\")
    escaped = escaped.replacingOccurrences(of: "\"", with: "\\\"")
    escaped = escaped.replacingOccurrences(of: "\n", with: "\\n")
    escaped = escaped.replacingOccurrences(of: "\r", with: "\\r")
    escaped = escaped.replacingOccurrences(of: "\t", with: "\\t")
    return "\"\(escaped)\""
  }

  private static func serializeGroup(_ group: Group, path: [String]) -> [String] {
    var lines: [String] = []
    let key = escapeKey(group.key ?? "")
    let currentPath = path + [key]

    lines.append("[\(currentPath.joined(separator: "."))]")

    if let label = group.label, !label.isEmpty {
      lines.append("label = \(escapeString(label))")
    }

    if let iconPath = group.iconPath {
      lines.append("icon = \(escapeString(iconPath))")
    }

    // Serialize inline actions
    for case .action(let action) in group.actions where !actionUsesTable(action) {
      lines.append(serializeAction(action))
    }

    lines.append("")

    // Serialize table actions
    for case .action(let action) in group.actions where actionUsesTable(action) {
      lines.append(contentsOf: serializeActionTable(action, path: currentPath))
    }

    // Serialize nested groups
    for case .group(let subgroup) in group.actions {
      lines.append(contentsOf: serializeGroup(subgroup, path: currentPath))
    }

    return lines
  }

  private static func actionUsesTable(_ action: Action) -> Bool {
    action.iconPath?.isEmpty == false || shouldSerializeType(action)
  }

  private static func serializeActionTable(_ action: Action, path: [String]) -> [String] {
    let key = escapeKey(action.key ?? "?")
    let tablePath = (path + [key]).joined(separator: ".")
    var lines: [String] = []
    lines.append("[\(tablePath)]")
    lines.append("value = \(serializeValue(action.value))")

    if shouldSerializeType(action) {
      lines.append("type = \(escapeString(action.type.rawValue))")
    }

    if let label = action.label, !label.isEmpty {
      lines.append("label = \(escapeString(label))")
    }

    if let iconPath = action.iconPath, !iconPath.isEmpty {
      lines.append("icon = \(escapeString(iconPath))")
    }

    lines.append("")
    return lines
  }

  private static func shouldSerializeType(_ action: Action) -> Bool {
    inferType(action.value) != action.type
  }

  private static func extractType(from value: (any TOMLValueConvertible)?, key: String) throws -> Type? {
    guard let stringValue = extractString(from: value) else { return nil }
    if let parsedType = Type(rawValue: stringValue) {
      return parsedType
    }
    throw TOMLError.invalidValue(message: "Invalid type '\(stringValue)' for key '\(key)'")
  }

  private static func isURLWithScheme(_ value: String) -> Bool {
    guard let colonIndex = value.firstIndex(of: ":") else { return false }
    let scheme = value[..<colonIndex]
    guard let firstChar = scheme.first, firstChar.isLetter else { return false }

    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "+.-"))
    guard scheme.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return false }

    let remainderStart = value.index(after: colonIndex)
    return remainderStart < value.endIndex
  }
}
