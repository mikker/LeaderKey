import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
  static let activate = Self("navigate")
}

// MARK: - Three-Way Key Mapping System

/// A centralized key mapping entry that provides three representations of a key
struct KeyMapEntry: Hashable, Codable {
  let code: UInt16  // Hardware scancode (49)
  let glyph: String  // Visual symbol for UI ("␣")
  let text: String  // Text identifier for config file ("space")
  let reserved: Bool  // Whether this key can be bound by users
}

/// Centralized key mapping system that replaces scattered hardcoded mappings
enum KeyMaps {
  // Primary lookup tables; built once and cached
  private static let dicts = Self.build()
  static let byCode: [UInt16: KeyMapEntry] = dicts.byCode
  static let byGlyph: [String: KeyMapEntry] = dicts.byGlyph
  static let byText: [String: KeyMapEntry] = dicts.byText

  private static func build() -> (
    byCode: [UInt16: KeyMapEntry],
    byGlyph: [String: KeyMapEntry],
    byText: [String: KeyMapEntry]
  ) {
    let entries: [KeyMapEntry] = [
      // Letters (US English QWERTY)
      .init(code: 0x00, glyph: "a", text: "a", reserved: false),
      .init(code: 0x0B, glyph: "b", text: "b", reserved: false),
      .init(code: 0x08, glyph: "c", text: "c", reserved: false),
      .init(code: 0x02, glyph: "d", text: "d", reserved: false),
      .init(code: 0x0E, glyph: "e", text: "e", reserved: false),
      .init(code: 0x03, glyph: "f", text: "f", reserved: false),
      .init(code: 0x05, glyph: "g", text: "g", reserved: false),
      .init(code: 0x04, glyph: "h", text: "h", reserved: false),
      .init(code: 0x22, glyph: "i", text: "i", reserved: false),
      .init(code: 0x26, glyph: "j", text: "j", reserved: false),
      .init(code: 0x28, glyph: "k", text: "k", reserved: false),
      .init(code: 0x25, glyph: "l", text: "l", reserved: false),
      .init(code: 0x2E, glyph: "m", text: "m", reserved: false),
      .init(code: 0x2D, glyph: "n", text: "n", reserved: false),
      .init(code: 0x1F, glyph: "o", text: "o", reserved: false),
      .init(code: 0x23, glyph: "p", text: "p", reserved: false),
      .init(code: 0x0C, glyph: "q", text: "q", reserved: false),
      .init(code: 0x0F, glyph: "r", text: "r", reserved: false),
      .init(code: 0x01, glyph: "s", text: "s", reserved: false),
      .init(code: 0x11, glyph: "t", text: "t", reserved: false),
      .init(code: 0x20, glyph: "u", text: "u", reserved: false),
      .init(code: 0x09, glyph: "v", text: "v", reserved: false),
      .init(code: 0x0D, glyph: "w", text: "w", reserved: false),
      .init(code: 0x07, glyph: "x", text: "x", reserved: false),
      .init(code: 0x10, glyph: "y", text: "y", reserved: false),
      .init(code: 0x06, glyph: "z", text: "z", reserved: false),

      // Uppercase letters (same keycodes but different glyphs/text for case sensitivity)
      .init(code: 0x00, glyph: "A", text: "A", reserved: false),
      .init(code: 0x0B, glyph: "B", text: "B", reserved: false),
      .init(code: 0x08, glyph: "C", text: "C", reserved: false),
      .init(code: 0x02, glyph: "D", text: "D", reserved: false),
      .init(code: 0x0E, glyph: "E", text: "E", reserved: false),
      .init(code: 0x03, glyph: "F", text: "F", reserved: false),
      .init(code: 0x05, glyph: "G", text: "G", reserved: false),
      .init(code: 0x04, glyph: "H", text: "H", reserved: false),
      .init(code: 0x22, glyph: "I", text: "I", reserved: false),
      .init(code: 0x26, glyph: "J", text: "J", reserved: false),
      .init(code: 0x28, glyph: "K", text: "K", reserved: false),
      .init(code: 0x25, glyph: "L", text: "L", reserved: false),
      .init(code: 0x2E, glyph: "M", text: "M", reserved: false),
      .init(code: 0x2D, glyph: "N", text: "N", reserved: false),
      .init(code: 0x1F, glyph: "O", text: "O", reserved: false),
      .init(code: 0x23, glyph: "P", text: "P", reserved: false),
      .init(code: 0x0C, glyph: "Q", text: "Q", reserved: false),
      .init(code: 0x0F, glyph: "R", text: "R", reserved: false),
      .init(code: 0x01, glyph: "S", text: "S", reserved: false),
      .init(code: 0x11, glyph: "T", text: "T", reserved: false),
      .init(code: 0x20, glyph: "U", text: "U", reserved: false),
      .init(code: 0x09, glyph: "V", text: "V", reserved: false),
      .init(code: 0x0D, glyph: "W", text: "W", reserved: false),
      .init(code: 0x07, glyph: "X", text: "X", reserved: false),
      .init(code: 0x10, glyph: "Y", text: "Y", reserved: false),
      .init(code: 0x06, glyph: "Z", text: "Z", reserved: false),

      // Numbers
      .init(code: 0x1D, glyph: "0", text: "0", reserved: false),
      .init(code: 0x12, glyph: "1", text: "1", reserved: false),
      .init(code: 0x13, glyph: "2", text: "2", reserved: false),
      .init(code: 0x14, glyph: "3", text: "3", reserved: false),
      .init(code: 0x15, glyph: "4", text: "4", reserved: false),
      .init(code: 0x17, glyph: "5", text: "5", reserved: false),
      .init(code: 0x16, glyph: "6", text: "6", reserved: false),
      .init(code: 0x1A, glyph: "7", text: "7", reserved: false),
      .init(code: 0x1C, glyph: "8", text: "8", reserved: false),
      .init(code: 0x19, glyph: "9", text: "9", reserved: false),

      // Special keys - space is allowed, backspace and escape are reserved
      .init(code: 36, glyph: "↵", text: "enter", reserved: false),
      .init(code: 48, glyph: "⇥", text: "tab", reserved: false),
      .init(code: 49, glyph: "␣", text: "space", reserved: false),  // Space is allowed!
      .init(code: 51, glyph: "⌫", text: "backspace", reserved: true),  // Reserved
      .init(code: 53, glyph: "⎋", text: "escape", reserved: true),  // Reserved
      .init(code: 117, glyph: "⌦", text: "delete", reserved: false),
      .init(code: 123, glyph: "←", text: "left", reserved: false),
      .init(code: 124, glyph: "→", text: "right", reserved: false),
      .init(code: 125, glyph: "↓", text: "down", reserved: false),
      .init(code: 126, glyph: "↑", text: "up", reserved: false),
    ]

    // Separate entries: lowercase letters go to byCode, all go to byGlyph/byText
    let byCodeEntries = entries.filter { entry in
      // Only lowercase letters and non-letters go in byCode (to avoid keycode conflicts)
      return entry.glyph.lowercased() == entry.glyph || !entry.glyph.first!.isLetter
    }

    return (
      byCode: Dictionary(uniqueKeysWithValues: byCodeEntries.map { ($0.code, $0) }),
      byGlyph: Dictionary(uniqueKeysWithValues: entries.map { ($0.glyph, $0) }),
      byText: Dictionary(uniqueKeysWithValues: entries.map { ($0.text, $0) })
    )
  }
}

// MARK: - Convenience Extensions

extension KeyMapEntry {
  /// Whether this key is reserved and cannot be bound by users
  var isReserved: Bool { reserved }

  /// Whether this key can be used for bindings
  var isBindable: Bool { !reserved }
}

extension KeyMaps {
  /// Get entry by key code
  static func entry(for code: UInt16) -> KeyMapEntry? {
    return byCode[code]
  }

  /// Get entry by glyph (visual symbol)
  static func entry(for glyph: String) -> KeyMapEntry? {
    return byGlyph[glyph]
  }

  /// Get entry by text identifier
  static func entry(forText text: String) -> KeyMapEntry? {
    return byText[text]
  }

  /// Convert a key from any representation to a glyph for display
  static func glyph(for input: String) -> String? {
    // Try as glyph first (most common case)
    if let entry = byGlyph[input] {
      return entry.glyph
    }

    // Try as text identifier
    if let entry = byText[input] {
      return entry.glyph
    }

    // Return as-is if not found (fallback for unknown keys)
    return input
  }

  /// Convert a key from any representation to text for config file storage
  static func text(for input: String) -> String? {
    // Try as glyph first
    if let entry = byGlyph[input] {
      return entry.text
    }

    // Try as text identifier
    if let entry = byText[input] {
      return entry.text
    }

    // Return as-is if not found (fallback)
    return input
  }

  /// Check if a key is reserved (cannot be bound)
  static func isReserved(_ input: String) -> Bool {
    if let entry = byGlyph[input] {
      return entry.isReserved
    }
    if let entry = byText[input] {
      return entry.isReserved
    }
    return false
  }
}
