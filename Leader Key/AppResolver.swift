import AppKit
import Foundation

/// Resolves application names to their full paths
/// Supports:
/// - Full paths: /Applications/Safari.app
/// - App names: "Safari", "Terminal", "Visual Studio Code"
/// - Partial matches: "Code" → "Visual Studio Code.app"
struct AppResolver {

  /// Standard directories to search for applications
  private static let searchPaths: [String] = [
    "/Applications",
    "/System/Applications",
    "/System/Applications/Utilities",
    "~/Applications",
    "/Applications/Utilities",
  ]
  private static let expandedSearchPaths: [String] = searchPaths.map {
    ($0 as NSString).expandingTildeInPath
  }

  /// Resolve an app name or path to a full application path
  /// - Parameter value: App name (e.g., "Terminal") or path (e.g., "/Applications/Safari.app")
  /// - Returns: The resolved full path, or the original value if not resolvable
  static func resolve(_ value: String) -> String {
    // Already a full path
    if value.hasPrefix("/") || value.hasPrefix("~") {
      return (value as NSString).expandingTildeInPath
    }

    // If it ends with .app, search for it
    if value.hasSuffix(".app") {
      if let path = findApp(named: String(value.dropLast(4))) {
        return path
      }
      return value
    }

    // Try to find the app by name
    if let path = findApp(named: value) {
      return path
    }

    // Return original value (might be a command or URL)
    return value
  }

  /// Find an application by name in standard locations
  /// - Parameter name: The application name without .app extension
  /// - Returns: Full path to the application, or nil if not found
  static func findApp(named name: String) -> String? {
    let appName = name.hasSuffix(".app") ? name : "\(name).app"

    // First try exact match
    for searchPath in expandedSearchPaths {
      let fullPath = (searchPath as NSString).appendingPathComponent(appName)
      if FileManager.default.fileExists(atPath: fullPath) {
        return fullPath
      }
    }

    // Try case-insensitive match
    for searchPath in expandedSearchPaths {
      if let match = findCaseInsensitive(name: name, in: searchPath) {
        return match
      }
    }

    // Try using Launch Services to find the app
    if let bundleURL = NSWorkspace.shared.urlForApplication(
      withBundleIdentifier: bundleIdentifierGuess(for: name))
    {
      return bundleURL.path
    }

    return nil
  }

  /// Find app case-insensitively in a directory
  private static func findCaseInsensitive(name: String, in directory: String) -> String? {
    let lowercaseName = name.lowercased()

    guard
      let contents = try? FileManager.default.contentsOfDirectory(
        atPath: directory)
    else {
      return nil
    }

    var prefixMatch: (name: String, path: String)?
    var containsMatch: (name: String, path: String)?

    func updateMatch(
      _ match: inout (name: String, path: String)?,
      candidateName: String,
      candidatePath: String
    ) {
      if let current = match {
        if candidateName.count < current.name.count {
          match = (candidateName, candidatePath)
        }
      } else {
        match = (candidateName, candidatePath)
      }
    }

    for item in contents where item.hasSuffix(".app") {
      let itemName = String(item.dropLast(4))
      let lowercasedItemName = itemName.lowercased()
      if lowercasedItemName == lowercaseName {
        return (directory as NSString).appendingPathComponent(item)
      }

      let itemPath = (directory as NSString).appendingPathComponent(item)

      // Partial matching: exact (case-insensitive) is first, then prefix, then shortest contains.
      if lowercasedItemName.hasPrefix(lowercaseName) {
        updateMatch(&prefixMatch, candidateName: lowercasedItemName, candidatePath: itemPath)
      } else if lowercasedItemName.contains(lowercaseName) {
        updateMatch(&containsMatch, candidateName: lowercasedItemName, candidatePath: itemPath)
      }
    }

    if let prefixMatch = prefixMatch {
      return prefixMatch.path
    }

    if let containsMatch = containsMatch {
      return containsMatch.path
    }

    return nil
  }

  /// Guess the bundle identifier for common apps
  private static func bundleIdentifierGuess(for name: String) -> String {
    // Try a generic pattern
    return "com.apple.\(name.replacingOccurrences(of: " ", with: ""))"
  }
}
