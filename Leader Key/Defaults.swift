import Defaults

let CONFIG_DIR_EMPTY = "CONFIG_DIR_EMPTY"

extension Defaults.Keys {
  static let watchConfigFile = Key<Bool>("watchConfigFile", default: false)
  static let configDir = Key<String>("configDir", default: CONFIG_DIR_EMPTY)
}
