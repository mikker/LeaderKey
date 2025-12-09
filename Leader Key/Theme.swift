import Defaults

enum Theme: String, Defaults.Serializable {
  case mysteryBox
  case mini
  case breadcrumbs
  case menlo
  case forTheHorde
  case cheater

  static var all: [Theme] {
    return [.mysteryBox, .mini, .breadcrumbs, .menlo, .forTheHorde, .cheater]
  }

  static func classFor(_ value: Theme) -> MainWindow.Type {
    switch value {
    case .mysteryBox:
      return MysteryBox.Window.self
    case .mini:
      return Mini.Window.self
    case .breadcrumbs:
      return Breadcrumbs.Window.self
    case .menlo:
      return Menlo.Window.self
    case .forTheHorde:
      return ForTheHorde.Window.self
    case .cheater:
      return Cheater.Window.self
    }
  }

  static func name(_ value: Theme) -> String {
    switch value {
    case .mysteryBox: return "Mystery Box"
    case .mini: return "Mini"
    case .breadcrumbs: return "Breadcrumbs"
    case .menlo: return "Menlo"
    case .forTheHorde: return "For The Horde"
    case .cheater: return "Cheater"
    }
  }
}