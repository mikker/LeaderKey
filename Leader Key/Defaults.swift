import Defaults

let CONFIG_DIR_EMPTY = "CONFIG_DIR_EMPTY"

extension Defaults.Keys {
  static let watchConfigFile = Key<Bool>("watchConfigFile", default: false)
  static let configDir = Key<String>("configDir", default: CONFIG_DIR_EMPTY)
  static let showMenuBarIcon = Key<Bool>("showInMenubar", default: true)
  static let forceEnglishKeyboardLayout = Key<Bool>("forceEnglishKeyboardLayout", default: false)

  static let alwaysShowCheatsheet = Key<Bool>("alwaysShowCheatsheet", default: false)
  static let expandGroupsInCheatsheet = Key<Bool>("expandGroupsInCheatsheet", default: false)
}
