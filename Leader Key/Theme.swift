import Defaults

enum Theme: String, Defaults.Serializable {
  case mysteryBox
  case mini
  case breadcrumbs
  case forTheHorde
  case cheater
  case hal9000

  static var all: [Theme] {
    return [.mysteryBox, .mini, .breadcrumbs, .forTheHorde, .cheater, .hal9000]
  }

  static func classFor(_ value: Theme) -> MainWindow.Type {
    switch value {
    case .mysteryBox:
      return MysteryBox.Window.self
    case .mini:
      return Mini.Window.self
    case .breadcrumbs:
      return Breadcrumbs.Window.self
    case .forTheHorde:
      return ForTheHorde.Window.self
    case .cheater:
      return Cheater.Window.self
    case .hal9000:
      return HAL9000.Window.self
    }
  }

  static func name(_ value: Theme) -> String {
    switch value {
    case .mysteryBox: return "Mystery Box"
    case .mini: return "Mini"
    case .breadcrumbs: return "Breadcrumbs"
    case .forTheHorde: return "For The Horde"
    case .cheater: return "Cheater"
    case .hal9000: return "HAL 9000"
    }
  }
}
