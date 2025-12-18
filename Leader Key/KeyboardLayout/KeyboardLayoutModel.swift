import Defaults
import Foundation

/// Defines a single key on the keyboard
struct KeyDefinition: Identifiable {
  let id = UUID()
  let label: String  // Display label ("Q", "Tab", "Space")
  let key: String  // Config key for binding lookup ("q", "tab", "space")
  let width: CGFloat  // Key width multiplier (1.0 = standard key)
  let isModifier: Bool  // Whether this is a non-bindable modifier key

  init(label: String, key: String, width: CGFloat = 1.0, isModifier: Bool = false) {
    self.label = label
    self.key = key
    self.width = width
    self.isModifier = isModifier
  }
}

/// Keyboard layout definition supporting multiple layouts
enum KeyboardLayout {
  static let keySize: CGFloat = 40
  static let keySpacing: CGFloat = 4
  static let rowSpacing: CGFloat = 4

  /// Scale factor for centered cheatsheet mode (larger display)
  static let centeredScale: CGFloat = 1.4

  /// Get scaled key size
  static func scaledKeySize(_ scale: CGFloat) -> CGFloat {
    keySize * scale
  }

  /// Get scaled key spacing
  static func scaledKeySpacing(_ scale: CGFloat) -> CGFloat {
    keySpacing * scale
  }

  /// Get scaled row spacing
  static func scaledRowSpacing(_ scale: CGFloat) -> CGFloat {
    rowSpacing * scale
  }

  // MARK: - Shifted Keys Mappings

  /// QWERTY shifted keys mapping
  static let shiftedKeysQWERTY: [String: String] = [
    "`": "~",
    "1": "!",
    "2": "@",
    "3": "#",
    "4": "$",
    "5": "%",
    "6": "^",
    "7": "&",
    "8": "*",
    "9": "(",
    "0": ")",
    "-": "_",
    "=": "+",
    "[": "{",
    "]": "}",
    "\\": "|",
    ";": ":",
    "'": "\"",
    ",": "<",
    ".": ">",
    "/": "?",
  ]

  /// QWERTZ shifted keys mapping (German keyboard)
  static let shiftedKeysQWERTZ: [String: String] = [
    "^": "°",
    "1": "!",
    "2": "\"",
    "3": "§",
    "4": "$",
    "5": "%",
    "6": "&",
    "7": "/",
    "8": "(",
    "9": ")",
    "0": "=",
    "ß": "?",
    "´": "`",
    "ü": "Ü",
    "+": "*",
    "ö": "Ö",
    "ä": "Ä",
    "#": "'",
    ",": ";",
    ".": ":",
    "-": "_",
  ]

  /// Get shifted keys mapping for the current layout
  static var shiftedKeys: [String: String] {
    shiftedKeys(for: Defaults[.keyboardLayoutType])
  }

  /// Get shifted keys mapping for a specific layout
  static func shiftedKeys(for layout: KeyboardLayoutType) -> [String: String] {
    switch layout {
    case .qwerty:
      return shiftedKeysQWERTY
    case .qwertz:
      return shiftedKeysQWERTZ
    }
  }

  /// Get the shifted version of a key (for both display and binding lookup)
  static func shiftedKey(for key: String) -> String {
    shiftedKey(for: key, layout: Defaults[.keyboardLayoutType])
  }

  /// Get the shifted version of a key for a specific layout
  static func shiftedKey(for key: String, layout: KeyboardLayoutType) -> String {
    // Letters just uppercase
    if key.count == 1, let char = key.first, char.isLetter {
      return key.uppercased()
    }
    // Special characters use the mapping
    let mapping = shiftedKeys(for: layout)
    return mapping[key] ?? key
  }

  /// Calculate total keyboard width based on widest row
  static var totalWidth: CGFloat {
    let widestRow = rows.max(by: { rowWidth($0) < rowWidth($1) }) ?? []
    return rowWidth(widestRow)
  }

  /// Calculate width of a row
  static func rowWidth(_ row: [KeyDefinition]) -> CGFloat {
    let totalUnits = row.reduce(0) { $0 + $1.width }
    return totalUnits * keySize + (totalUnits - 1) * keySpacing
  }

  // MARK: - Layout-Aware Rows

  /// All keyboard rows for the current layout preference
  static var rows: [[KeyDefinition]] {
    rows(for: Defaults[.keyboardLayoutType])
  }

  /// Get rows for a specific layout
  static func rows(for layout: KeyboardLayoutType) -> [[KeyDefinition]] {
    switch layout {
    case .qwerty:
      return rowsQWERTY
    case .qwertz:
      return rowsQWERTZ
    }
  }

  // MARK: - QWERTY Layout Rows

  static let rowsQWERTY: [[KeyDefinition]] = [
    row0QWERTY, row1QWERTY, row2QWERTY, row3QWERTY, row4,
  ]

  // Row 0: ` 1 2 3 4 5 6 7 8 9 0 - = Backspace (total: 15u)
  static let row0QWERTY: [KeyDefinition] = [
    KeyDefinition(label: "`", key: "`"),
    KeyDefinition(label: "1", key: "1"),
    KeyDefinition(label: "2", key: "2"),
    KeyDefinition(label: "3", key: "3"),
    KeyDefinition(label: "4", key: "4"),
    KeyDefinition(label: "5", key: "5"),
    KeyDefinition(label: "6", key: "6"),
    KeyDefinition(label: "7", key: "7"),
    KeyDefinition(label: "8", key: "8"),
    KeyDefinition(label: "9", key: "9"),
    KeyDefinition(label: "0", key: "0"),
    KeyDefinition(label: "-", key: "-"),
    KeyDefinition(label: "=", key: "="),
    KeyDefinition(label: "⌫", key: "backspace", width: 2.0, isModifier: true),
  ]

  // Row 1: Tab Q W E R T Y U I O P [ ] \ (total: 15u)
  static let row1QWERTY: [KeyDefinition] = [
    KeyDefinition(label: "⇥", key: "tab", width: 1.5),
    KeyDefinition(label: "Q", key: "q"),
    KeyDefinition(label: "W", key: "w"),
    KeyDefinition(label: "E", key: "e"),
    KeyDefinition(label: "R", key: "r"),
    KeyDefinition(label: "T", key: "t"),
    KeyDefinition(label: "Y", key: "y"),
    KeyDefinition(label: "U", key: "u"),
    KeyDefinition(label: "I", key: "i"),
    KeyDefinition(label: "O", key: "o"),
    KeyDefinition(label: "P", key: "p"),
    KeyDefinition(label: "[", key: "["),
    KeyDefinition(label: "]", key: "]"),
    KeyDefinition(label: "\\", key: "\\", width: 1.5),
  ]

  // Row 2: Caps A S D F G H J K L ; ' Enter (total: 15u)
  static let row2QWERTY: [KeyDefinition] = [
    KeyDefinition(label: "⇪", key: "caps", width: 1.75, isModifier: true),
    KeyDefinition(label: "A", key: "a"),
    KeyDefinition(label: "S", key: "s"),
    KeyDefinition(label: "D", key: "d"),
    KeyDefinition(label: "F", key: "f"),
    KeyDefinition(label: "G", key: "g"),
    KeyDefinition(label: "H", key: "h"),
    KeyDefinition(label: "J", key: "j"),
    KeyDefinition(label: "K", key: "k"),
    KeyDefinition(label: "L", key: "l"),
    KeyDefinition(label: ";", key: ";"),
    KeyDefinition(label: "'", key: "'"),
    KeyDefinition(label: "⏎", key: "enter", width: 2.25),
  ]

  // Row 3: Shift Z X C V B N M , . / Shift (total: 15u)
  static let row3QWERTY: [KeyDefinition] = [
    KeyDefinition(label: "⇧", key: "shift", width: 2.25, isModifier: true),
    KeyDefinition(label: "Z", key: "z"),
    KeyDefinition(label: "X", key: "x"),
    KeyDefinition(label: "C", key: "c"),
    KeyDefinition(label: "V", key: "v"),
    KeyDefinition(label: "B", key: "b"),
    KeyDefinition(label: "N", key: "n"),
    KeyDefinition(label: "M", key: "m"),
    KeyDefinition(label: ",", key: ","),
    KeyDefinition(label: ".", key: "."),
    KeyDefinition(label: "/", key: "/"),
    KeyDefinition(label: "⇧", key: "shift_r", width: 2.75, isModifier: true),
  ]

  // MARK: - QWERTZ Layout Rows (German)

  static let rowsQWERTZ: [[KeyDefinition]] = [
    row0QWERTZ, row1QWERTZ, row2QWERTZ, row3QWERTZ, row4,
  ]

  // Row 0: ^ 1 2 3 4 5 6 7 8 9 0 ß ´ Backspace (total: 15u)
  static let row0QWERTZ: [KeyDefinition] = [
    KeyDefinition(label: "^", key: "^"),
    KeyDefinition(label: "1", key: "1"),
    KeyDefinition(label: "2", key: "2"),
    KeyDefinition(label: "3", key: "3"),
    KeyDefinition(label: "4", key: "4"),
    KeyDefinition(label: "5", key: "5"),
    KeyDefinition(label: "6", key: "6"),
    KeyDefinition(label: "7", key: "7"),
    KeyDefinition(label: "8", key: "8"),
    KeyDefinition(label: "9", key: "9"),
    KeyDefinition(label: "0", key: "0"),
    KeyDefinition(label: "ß", key: "ß"),
    KeyDefinition(label: "´", key: "´"),
    KeyDefinition(label: "⌫", key: "backspace", width: 2.0, isModifier: true),
  ]

  // Row 1: Tab Q W E R T Z U I O P Ü + # (total: 15u)
  static let row1QWERTZ: [KeyDefinition] = [
    KeyDefinition(label: "⇥", key: "tab", width: 1.5),
    KeyDefinition(label: "Q", key: "q"),
    KeyDefinition(label: "W", key: "w"),
    KeyDefinition(label: "E", key: "e"),
    KeyDefinition(label: "R", key: "r"),
    KeyDefinition(label: "T", key: "t"),
    KeyDefinition(label: "Z", key: "z"),  // Z and Y are swapped in QWERTZ
    KeyDefinition(label: "U", key: "u"),
    KeyDefinition(label: "I", key: "i"),
    KeyDefinition(label: "O", key: "o"),
    KeyDefinition(label: "P", key: "p"),
    KeyDefinition(label: "Ü", key: "ü"),
    KeyDefinition(label: "+", key: "+"),
    KeyDefinition(label: "#", key: "#", width: 1.5),
  ]

  // Row 2: Caps A S D F G H J K L Ö Ä Enter (total: 15u)
  static let row2QWERTZ: [KeyDefinition] = [
    KeyDefinition(label: "⇪", key: "caps", width: 1.75, isModifier: true),
    KeyDefinition(label: "A", key: "a"),
    KeyDefinition(label: "S", key: "s"),
    KeyDefinition(label: "D", key: "d"),
    KeyDefinition(label: "F", key: "f"),
    KeyDefinition(label: "G", key: "g"),
    KeyDefinition(label: "H", key: "h"),
    KeyDefinition(label: "J", key: "j"),
    KeyDefinition(label: "K", key: "k"),
    KeyDefinition(label: "L", key: "l"),
    KeyDefinition(label: "Ö", key: "ö"),
    KeyDefinition(label: "Ä", key: "ä"),
    KeyDefinition(label: "⏎", key: "enter", width: 2.25),
  ]

  // Row 3: Shift < Y X C V B N M , . - Shift (total: 15u)
  // Note: ISO layout has extra < key, we adjust widths to maintain consistency
  static let row3QWERTZ: [KeyDefinition] = [
    KeyDefinition(label: "⇧", key: "shift", width: 1.25, isModifier: true),
    KeyDefinition(label: "<", key: "<"),  // Extra key on ISO layout
    KeyDefinition(label: "Y", key: "y"),  // Z and Y are swapped in QWERTZ
    KeyDefinition(label: "X", key: "x"),
    KeyDefinition(label: "C", key: "c"),
    KeyDefinition(label: "V", key: "v"),
    KeyDefinition(label: "B", key: "b"),
    KeyDefinition(label: "N", key: "n"),
    KeyDefinition(label: "M", key: "m"),
    KeyDefinition(label: ",", key: ","),
    KeyDefinition(label: ".", key: "."),
    KeyDefinition(label: "-", key: "-"),
    KeyDefinition(label: "⇧", key: "shift_r", width: 2.75, isModifier: true),
  ]

  // MARK: - Shared Bottom Row

  // Row 4: Ctrl Opt Cmd Space Cmd Opt Ctrl (total: 15u)
  // Spacebar aligned with C key (left edge) and comma key (right edge)
  // Right Cmd and Opt meet under center of slash key
  static let row4: [KeyDefinition] = [
    KeyDefinition(label: "⌃", key: "ctrl", width: 1.5, isModifier: true),
    KeyDefinition(label: "⌥", key: "opt", width: 1.25, isModifier: true),
    KeyDefinition(label: "⌘", key: "cmd", width: 1.5, isModifier: true),
    KeyDefinition(label: "", key: "space", width: 6.0),
    KeyDefinition(label: "⌘", key: "cmd_r", width: 1.5, isModifier: true),
    KeyDefinition(label: "⌥", key: "opt_r", width: 1.5, isModifier: true),
    KeyDefinition(label: "⌃", key: "ctrl_r", width: 1.75, isModifier: true),
  ]

  // MARK: - Backward Compatibility (aliases)

  /// Backward compatibility: row0 defaults to current layout
  static var row0: [KeyDefinition] {
    switch Defaults[.keyboardLayoutType] {
    case .qwerty: return row0QWERTY
    case .qwertz: return row0QWERTZ
    }
  }

  /// Backward compatibility: row1 defaults to current layout
  static var row1: [KeyDefinition] {
    switch Defaults[.keyboardLayoutType] {
    case .qwerty: return row1QWERTY
    case .qwertz: return row1QWERTZ
    }
  }

  /// Backward compatibility: row2 defaults to current layout
  static var row2: [KeyDefinition] {
    switch Defaults[.keyboardLayoutType] {
    case .qwerty: return row2QWERTY
    case .qwertz: return row2QWERTZ
    }
  }

  /// Backward compatibility: row3 defaults to current layout
  static var row3: [KeyDefinition] {
    switch Defaults[.keyboardLayoutType] {
    case .qwerty: return row3QWERTY
    case .qwertz: return row3QWERTZ
    }
  }
}
