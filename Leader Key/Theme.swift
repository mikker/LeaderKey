import Defaults

enum Theme: String, Defaults.Serializable {
  case mysteryBox
  case mini

  static func classFor(_ value: Theme) -> MainWindow.Type {
    switch value {
    case .mysteryBox:
      return MysteryBox.Window.self
    case .mini:
      return Mini.Window.self
    }
  }
}
