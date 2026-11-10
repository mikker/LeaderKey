import Carbon.HIToolbox
import Defaults
import Foundation

/// Defines a single key on the keyboard
struct KeyDefinition: Identifiable {
  let id = UUID()
  let label: String  // Display label ("Q", "Tab", "Space")
  let key: String  // US QWERTY config key for binding lookup ("q", "tab", "space")
  let keyCode: UInt16  // Virtual key code of the physical key
  let width: CGFloat  // Key width multiplier (1.0 = standard key)
  let isModifier: Bool  // Whether this is a non-bindable modifier key

  init(label: String, key: String, keyCode: Int, width: CGFloat = 1.0, isModifier: Bool = false) {
    self.label = label
    self.key = key
    self.keyCode = UInt16(keyCode)
    self.width = width
    self.isModifier = isModifier
  }

  /// Keys whose character depends on the input source. Tab, enter, space and
  /// the modifiers all have multi-character static keys.
  var isCharacterKey: Bool {
    !isModifier && key.count == 1
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

  /// The key string the controller produces for a physical key, and so the key
  /// its binding is stored under. Mirrors `Controller.charForEvent`: character
  /// keys follow the active input source unless `forceEnglishKeyboardLayout` is
  /// on; everything else, and any failed translation, uses the static key.
  /// `inputSource` defaults to the active keyboard layout.
  static func bindingKey(
    for keyDef: KeyDefinition, shifted: Bool, inputSource: TISInputSource? = nil
  ) -> String {
    let staticKey = shifted ? shiftedKey(for: keyDef.key) : keyDef.key

    guard keyDef.isCharacterKey, !Defaults[.forceEnglishKeyboardLayout],
      let translated = translatedCharacter(
        keyCode: keyDef.keyCode, shifted: shifted, inputSource: inputSource)
    else {
      return staticKey
    }

    if translated.unicodeScalars.first?.isASCII ?? false {
      return translated
    }

    // The controller only accepts ASCII from the input source. Otherwise it
    // uses the KeyMaps glyph (letters and digits), or the character itself.
    guard let entry = KeyMaps.entry(for: keyDef.keyCode) else {
      return translated
    }
    if entry.glyph.first?.isLetter == true && !entry.isReserved {
      return shifted ? entry.glyph.uppercased() : entry.glyph
    }
    return entry.glyph
  }

  /// `bindingKey` for a key identified by its static key ("q", "shift_r")
  static func bindingKey(forStaticKey key: String, shifted: Bool) -> String {
    for row in rows {
      if let keyDef = row.first(where: { $0.key == key }) {
        return bindingKey(for: keyDef, shifted: shifted)
      }
    }
    return shifted ? shiftedKey(for: key) : key
  }

  /// What a keyboard layout types for a key code, or nil if it can't be
  /// translated or isn't printable. Dead keys yield their own character, as
  /// `NSEvent.charactersIgnoringModifiers` does.
  private static func translatedCharacter(
    keyCode: UInt16, shifted: Bool, inputSource: TISInputSource?
  ) -> String? {
    guard
      let source = inputSource ?? TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
      let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
    else {
      return nil
    }
    let layoutData = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue() as Data

    var deadKeyState: UInt32 = 0
    var length = 0
    var chars = [UniChar](repeating: 0, count: 4)
    let modifiers = shifted ? UInt32(shiftKey >> 8) & 0xFF : 0

    let status = layoutData.withUnsafeBytes { buffer -> OSStatus in
      guard let layout = buffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else {
        return OSStatus(paramErr)
      }
      return UCKeyTranslate(
        layout, keyCode, UInt16(kUCKeyActionDisplay), modifiers, UInt32(LMGetKbdType()),
        OptionBits(kUCKeyTranslateNoDeadKeysMask), &deadKeyState, chars.count, &length, &chars)
    }

    guard status == noErr, length > 0 else { return nil }
    let result = String(utf16CodeUnits: chars, count: length)
    guard let first = result.unicodeScalars.first,
      !CharacterSet.controlCharacters.union(.whitespacesAndNewlines).contains(first)
    else {
      return nil
    }
    return result
  }

  /// Rendered width of a key in points
  static func keyWidth(for keyDef: KeyDefinition, scale: CGFloat = 1.0) -> CGFloat {
    // A wide key also covers the gaps between the unit keys it spans
    keyDef.width * scaledKeySize(scale) + (keyDef.width - 1) * scaledKeySpacing(scale)
  }

  /// Calculate total keyboard width based on widest row
  static var totalWidth: CGFloat {
    rows.map { rowWidth($0) }.max() ?? 0
  }

  /// Rendered width of a row in points
  static func rowWidth(_ row: [KeyDefinition], scale: CGFloat = 1.0) -> CGFloat {
    let keys = row.reduce(0) { $0 + keyWidth(for: $1, scale: scale) }
    let gaps = CGFloat(max(0, row.count - 1))
    return keys + gaps * scaledKeySpacing(scale)
  }

  /// All keyboard rows
  static let rows: [[KeyDefinition]] = [
    row0, row1, row2, row3, row4,
  ]

  // Row 0: ` 1 2 3 4 5 6 7 8 9 0 - = Backspace (total: 15u)
  static let row0: [KeyDefinition] = [
    KeyDefinition(label: "`", key: "`", keyCode: kVK_ANSI_Grave),
    KeyDefinition(label: "1", key: "1", keyCode: kVK_ANSI_1),
    KeyDefinition(label: "2", key: "2", keyCode: kVK_ANSI_2),
    KeyDefinition(label: "3", key: "3", keyCode: kVK_ANSI_3),
    KeyDefinition(label: "4", key: "4", keyCode: kVK_ANSI_4),
    KeyDefinition(label: "5", key: "5", keyCode: kVK_ANSI_5),
    KeyDefinition(label: "6", key: "6", keyCode: kVK_ANSI_6),
    KeyDefinition(label: "7", key: "7", keyCode: kVK_ANSI_7),
    KeyDefinition(label: "8", key: "8", keyCode: kVK_ANSI_8),
    KeyDefinition(label: "9", key: "9", keyCode: kVK_ANSI_9),
    KeyDefinition(label: "0", key: "0", keyCode: kVK_ANSI_0),
    KeyDefinition(label: "-", key: "-", keyCode: kVK_ANSI_Minus),
    KeyDefinition(label: "=", key: "=", keyCode: kVK_ANSI_Equal),
    KeyDefinition(label: "⌫", key: "backspace", keyCode: kVK_Delete, width: 2.0, isModifier: true),
  ]

  // Row 1: Tab Q W E R T Y U I O P [ ] \ (total: 15u)
  static let row1: [KeyDefinition] = [
    KeyDefinition(label: "⇥", key: "tab", keyCode: kVK_Tab, width: 1.5),
    KeyDefinition(label: "Q", key: "q", keyCode: kVK_ANSI_Q),
    KeyDefinition(label: "W", key: "w", keyCode: kVK_ANSI_W),
    KeyDefinition(label: "E", key: "e", keyCode: kVK_ANSI_E),
    KeyDefinition(label: "R", key: "r", keyCode: kVK_ANSI_R),
    KeyDefinition(label: "T", key: "t", keyCode: kVK_ANSI_T),
    KeyDefinition(label: "Y", key: "y", keyCode: kVK_ANSI_Y),
    KeyDefinition(label: "U", key: "u", keyCode: kVK_ANSI_U),
    KeyDefinition(label: "I", key: "i", keyCode: kVK_ANSI_I),
    KeyDefinition(label: "O", key: "o", keyCode: kVK_ANSI_O),
    KeyDefinition(label: "P", key: "p", keyCode: kVK_ANSI_P),
    KeyDefinition(label: "[", key: "[", keyCode: kVK_ANSI_LeftBracket),
    KeyDefinition(label: "]", key: "]", keyCode: kVK_ANSI_RightBracket),
    KeyDefinition(label: "\\", key: "\\", keyCode: kVK_ANSI_Backslash, width: 1.5),
  ]

  // Row 2: Caps A S D F G H J K L ; ' Enter (total: 15u)
  static let row2: [KeyDefinition] = [
    KeyDefinition(label: "⇪", key: "caps", keyCode: kVK_CapsLock, width: 1.75, isModifier: true),
    KeyDefinition(label: "A", key: "a", keyCode: kVK_ANSI_A),
    KeyDefinition(label: "S", key: "s", keyCode: kVK_ANSI_S),
    KeyDefinition(label: "D", key: "d", keyCode: kVK_ANSI_D),
    KeyDefinition(label: "F", key: "f", keyCode: kVK_ANSI_F),
    KeyDefinition(label: "G", key: "g", keyCode: kVK_ANSI_G),
    KeyDefinition(label: "H", key: "h", keyCode: kVK_ANSI_H),
    KeyDefinition(label: "J", key: "j", keyCode: kVK_ANSI_J),
    KeyDefinition(label: "K", key: "k", keyCode: kVK_ANSI_K),
    KeyDefinition(label: "L", key: "l", keyCode: kVK_ANSI_L),
    KeyDefinition(label: ";", key: ";", keyCode: kVK_ANSI_Semicolon),
    KeyDefinition(label: "'", key: "'", keyCode: kVK_ANSI_Quote),
    KeyDefinition(label: "⏎", key: "enter", keyCode: kVK_Return, width: 2.25),
  ]

  // Row 3: Shift Z X C V B N M , . / Shift (total: 15u)
  static let row3: [KeyDefinition] = [
    KeyDefinition(label: "⇧", key: "shift", keyCode: kVK_Shift, width: 2.25, isModifier: true),
    KeyDefinition(label: "Z", key: "z", keyCode: kVK_ANSI_Z),
    KeyDefinition(label: "X", key: "x", keyCode: kVK_ANSI_X),
    KeyDefinition(label: "C", key: "c", keyCode: kVK_ANSI_C),
    KeyDefinition(label: "V", key: "v", keyCode: kVK_ANSI_V),
    KeyDefinition(label: "B", key: "b", keyCode: kVK_ANSI_B),
    KeyDefinition(label: "N", key: "n", keyCode: kVK_ANSI_N),
    KeyDefinition(label: "M", key: "m", keyCode: kVK_ANSI_M),
    KeyDefinition(label: ",", key: ",", keyCode: kVK_ANSI_Comma),
    KeyDefinition(label: ".", key: ".", keyCode: kVK_ANSI_Period),
    KeyDefinition(label: "/", key: "/", keyCode: kVK_ANSI_Slash),
    KeyDefinition(label: "⇧", key: "shift_r", keyCode: kVK_RightShift, width: 2.75, isModifier: true),
  ]

  // Row 4: Ctrl Opt Cmd Space Cmd Opt Ctrl (total: 15u)
  // Spacebar aligned with C key (left edge) and comma key (right edge)
  // Right Cmd and Opt meet under center of slash key
  static let row4: [KeyDefinition] = [
    KeyDefinition(label: "⌃", key: "ctrl", keyCode: kVK_Control, width: 1.5, isModifier: true),
    KeyDefinition(label: "⌥", key: "opt", keyCode: kVK_Option, width: 1.25, isModifier: true),
    KeyDefinition(label: "⌘", key: "cmd", keyCode: kVK_Command, width: 1.5, isModifier: true),
    KeyDefinition(label: "", key: "space", keyCode: kVK_Space, width: 6.0),
    KeyDefinition(label: "⌘", key: "cmd_r", keyCode: kVK_RightCommand, width: 1.5, isModifier: true),
    KeyDefinition(label: "⌥", key: "opt_r", keyCode: kVK_RightOption, width: 1.5, isModifier: true),
    KeyDefinition(
      label: "⌃", key: "ctrl_r", keyCode: kVK_RightControl, width: 1.75, isModifier: true),
  ]
}
