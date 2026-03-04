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

/// QWERTY keyboard layout definition
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

  /// Maps keys to their shifted versions for display and binding lookup
  static let shiftedKeys: [String: String] = [
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

  /// Get the shifted version of a key (for both display and binding lookup)
  static func shiftedKey(for key: String) -> String {
    // Letters just uppercase
    if key.count == 1, let char = key.first, char.isLetter {
      return key.uppercased()
    }
    // Special characters use the mapping
    return shiftedKeys[key] ?? key
  }

  /// Calculate total keyboard width based on widest row
  static var totalWidth: CGFloat {
    let widestRow = rows.max(by: { rowWidth($0) < rowWidth($1) }) ?? []
    return rowWidth(widestRow)
  }

  /// Calculate width of a row
  static func rowWidth(_ row: [KeyDefinition]) -> CGFloat {
    let totalUnits = row.reduce(0) { $0 + $1.width }
    let totalGaps = CGFloat(max(0, row.count - 1))
    return totalUnits * keySize + totalGaps * keySpacing
  }

  /// All keyboard rows
  static let rows: [[KeyDefinition]] = [
    row0, row1, row2, row3, row4,
  ]

  // Row 0: ` 1 2 3 4 5 6 7 8 9 0 - = Backspace (total: 15u)
  static let row0: [KeyDefinition] = [
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
  static let row1: [KeyDefinition] = [
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
  static let row2: [KeyDefinition] = [
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
  static let row3: [KeyDefinition] = [
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
}
