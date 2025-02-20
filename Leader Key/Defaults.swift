import Cocoa
import Defaults

let CONFIG_DIR_EMPTY = "CONFIG_DIR_EMPTY"

var SUITE =
  ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
  ? UserDefaults(suiteName: UUID().uuidString)!
  : .standard

extension Defaults.Keys {
  static let watchConfigFile = Key<Bool>(
    "watchConfigFile", default: false, suite: SUITE)
  static let configDir = Key<String>(
    "configDir", default: UserConfig.defaultDirectory(), suite: SUITE)
  static let showMenuBarIcon = Key<Bool>(
    "showInMenubar", default: true, suite: SUITE)
  static let forceEnglishKeyboardLayout = Key<Bool>(
    "forceEnglishKeyboardLayout", default: false, suite: SUITE)

  static let alwaysShowCheatsheet = Key<Bool>(
    "alwaysShowCheatsheet", default: false, suite: SUITE)
  static let expandGroupsInCheatsheet = Key<Bool>(
    "expandGroupsInCheatsheet", default: false, suite: SUITE)
  static let showAppIconsInCheatsheet = Key<Bool>(
    "showAppIconsInCheatsheet", default: true, suite: SUITE)
  static let modifierKeyForGroupSequence = Key<ModifierKey>(
    "modifierKeyForGroupSequence", default: .none, suite: SUITE)
}
