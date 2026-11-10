import Carbon.HIToolbox
import Combine
import Defaults
import XCTest

@testable import Leader_Key

class KeyboardLayoutTests: XCTestCase {
  var controller: Controller!
  var cancellables: Set<AnyCancellable>!
  var userState: UserState!
  var userConfig: UserConfig!

  override func setUp() {
    super.setUp()
    cancellables = Set<AnyCancellable>()

    // Create test instances
    userConfig = UserConfig()
    userState = UserState(userConfig: userConfig)
    controller = Controller(userState: userState, userConfig: userConfig)

    // Reset to default state
    Defaults[.forceEnglishKeyboardLayout] = false
  }

  override func tearDown() {
    cancellables = nil
    controller = nil
    userState = nil
    userConfig = nil
    super.tearDown()
  }

  // Helper to create fake NSEvent for testing
  private func fakeEvent(
    keyCode: UInt16, characters: String, charactersIgnoringModifiers: String,
    modifierFlags: NSEvent.ModifierFlags = []
  ) -> NSEvent {
    // This is a simplified mock - in real implementation we'd need to create a proper NSEvent
    // For now, we'll test the logic indirectly through Controller methods
    return NSEvent.keyEvent(
      with: .keyDown,
      location: NSPoint.zero,
      modifierFlags: modifierFlags,
      timestamp: 0,
      windowNumber: 0,
      context: nil,
      characters: characters,
      charactersIgnoringModifiers: charactersIgnoringModifiers,
      isARepeat: false,
      keyCode: keyCode
    )!
  }

  func testAZERTYLayoutWithForceEnglishDisabled() {
    Defaults[.forceEnglishKeyboardLayout] = false

    // Physical A key on AZERTY keyboard produces "q"
    let azertyAKey = fakeEvent(keyCode: 0x00, characters: "q", charactersIgnoringModifiers: "q")
    let result = controller.charForEvent(azertyAKey)

    XCTAssertEqual(result, "q", "Should respect AZERTY layout and return 'q' for physical A key")
  }

  func testAZERTYLayoutWithForceEnglishEnabled() {
    Defaults[.forceEnglishKeyboardLayout] = true

    // Physical A key on AZERTY keyboard - should force to English "a"
    let azertyAKey = fakeEvent(keyCode: 0x00, characters: "q", charactersIgnoringModifiers: "q")
    let result = controller.charForEvent(azertyAKey)

    XCTAssertEqual(result, "a", "Should force English layout and return 'a' for physical A key")
  }

  func testColemakLayoutWithForceEnglishDisabled() {
    Defaults[.forceEnglishKeyboardLayout] = false

    // Physical S key on Colemak produces "r"
    let colemakSKey = fakeEvent(keyCode: 0x01, characters: "r", charactersIgnoringModifiers: "r")
    let result = controller.charForEvent(colemakSKey)

    XCTAssertEqual(result, "r", "Should respect Colemak layout and return 'r' for physical S key")
  }

  func testColemakLayoutWithForceEnglishEnabled() {
    Defaults[.forceEnglishKeyboardLayout] = true

    // Physical S key on Colemak - should force to English "s"
    let colemakSKey = fakeEvent(keyCode: 0x01, characters: "r", charactersIgnoringModifiers: "r")
    let result = controller.charForEvent(colemakSKey)

    XCTAssertEqual(result, "s", "Should force English layout and return 's' for physical S key")
  }

  func testCaseSensitivityWithLayout() {
    Defaults[.forceEnglishKeyboardLayout] = false

    // Test lowercase
    let lowerR = fakeEvent(keyCode: 0x0F, characters: "r", charactersIgnoringModifiers: "r")
    let lowerResult = controller.charForEvent(lowerR)
    XCTAssertEqual(lowerResult, "r", "Should return lowercase 'r'")

    // Test uppercase with shift
    let upperR = fakeEvent(
      keyCode: 0x0F, characters: "R", charactersIgnoringModifiers: "R", modifierFlags: .shift)
    let upperResult = controller.charForEvent(upperR)
    XCTAssertEqual(upperResult, "R", "Should return uppercase 'R' with shift")

    XCTAssertNotEqual(lowerResult, upperResult, "Lowercase and uppercase should be different")
  }

  func testCaseSensitivityWithForceEnglish() {
    Defaults[.forceEnglishKeyboardLayout] = true

    // Test lowercase
    let lowerR = fakeEvent(keyCode: 0x0F, characters: "r", charactersIgnoringModifiers: "r")
    let lowerResult = controller.charForEvent(lowerR)
    XCTAssertEqual(lowerResult, "r", "Should return lowercase 'r' in force English mode")

    // Test uppercase with shift
    let upperR = fakeEvent(
      keyCode: 0x0F, characters: "R", charactersIgnoringModifiers: "R", modifierFlags: .shift)
    let upperResult = controller.charForEvent(upperR)
    XCTAssertEqual(upperResult, "R", "Should return uppercase 'R' with shift in force English mode")

    XCTAssertNotEqual(
      lowerResult, upperResult, "Lowercase and uppercase should be different in force English mode")
  }

  func testSpecialKeysAlwaysUseKeyMaps() {
    Defaults[.forceEnglishKeyboardLayout] = false

    // Arrow keys should always use KeyMaps regardless of layout setting
    let leftArrow = fakeEvent(keyCode: 0x7B, characters: "", charactersIgnoringModifiers: "")
    let result = controller.charForEvent(leftArrow)

    // Should return the KeyMaps entry for left arrow
    XCTAssertEqual(result, "←", "Special keys should always use KeyMaps")
  }
}

class KeyboardLayoutModelTests: XCTestCase {
  private var originalForceEnglish: Bool!

  override func setUp() {
    super.setUp()
    originalForceEnglish = Defaults[.forceEnglishKeyboardLayout]
  }

  override func tearDown() {
    Defaults[.forceEnglishKeyboardLayout] = originalForceEnglish
    super.tearDown()
  }

  func testEveryRowHasTheSameWidthAsTotalWidth() {
    XCTAssertEqual(KeyboardLayout.totalWidth, 656, accuracy: 0.001)
    for (index, row) in KeyboardLayout.rows.enumerated() {
      XCTAssertEqual(
        KeyboardLayout.rowWidth(row), KeyboardLayout.totalWidth, accuracy: 0.001,
        "Row \(index) should be as wide as the keyboard")
    }
  }

  func testRowWidthIsSumOfKeyWidthsPlusGaps() {
    for scale: CGFloat in [1.0, KeyboardLayout.centeredScale] {
      for (index, row) in KeyboardLayout.rows.enumerated() {
        let keys = row.reduce(0) { $0 + KeyboardLayout.keyWidth(for: $1, scale: scale) }
        let gaps = CGFloat(row.count - 1) * KeyboardLayout.scaledKeySpacing(scale)
        XCTAssertEqual(
          KeyboardLayout.rowWidth(row, scale: scale), keys + gaps, accuracy: 0.001,
          "Row \(index) at scale \(scale)")
      }
    }
  }

  func testKeyWidthCoversSpannedGaps() {
    let single = KeyboardLayout.row0[0]
    let backspace = KeyboardLayout.row0.last!
    XCTAssertEqual(KeyboardLayout.keyWidth(for: single), 40, accuracy: 0.001)
    XCTAssertEqual(KeyboardLayout.keyWidth(for: backspace), 84, accuracy: 0.001)
    XCTAssertEqual(KeyboardLayout.keyWidth(for: backspace, scale: 2), 168, accuracy: 0.001)
  }

  func testShiftedKeyForLetters() {
    XCTAssertEqual(KeyboardLayout.shiftedKey(for: "a"), "A")
    XCTAssertEqual(KeyboardLayout.shiftedKey(for: "z"), "Z")
  }

  func testShiftedKeyForDigits() {
    let expected = [
      "1": "!", "2": "@", "3": "#", "4": "$", "5": "%",
      "6": "^", "7": "&", "8": "*", "9": "(", "0": ")",
    ]
    for (key, shifted) in expected {
      XCTAssertEqual(KeyboardLayout.shiftedKey(for: key), shifted)
    }
  }

  func testShiftedKeyForPunctuation() {
    let expected = [
      "`": "~", "-": "_", "=": "+", "[": "{", "]": "}", "\\": "|",
      ";": ":", "'": "\"", ",": "<", ".": ">", "/": "?",
    ]
    for (key, shifted) in expected {
      XCTAssertEqual(KeyboardLayout.shiftedKey(for: key), shifted)
    }
  }

  func testShiftedKeyLeavesNamedKeysAlone() {
    XCTAssertEqual(KeyboardLayout.shiftedKey(for: "tab"), "tab")
    XCTAssertEqual(KeyboardLayout.shiftedKey(for: "space"), "space")
  }

  func testBindingKeyIsStaticWhenForcingEnglishLayout() {
    Defaults[.forceEnglishKeyboardLayout] = true

    for keyDef in KeyboardLayout.rows.joined() {
      XCTAssertEqual(KeyboardLayout.bindingKey(for: keyDef, shifted: false), keyDef.key)
      XCTAssertEqual(
        KeyboardLayout.bindingKey(for: keyDef, shifted: true),
        KeyboardLayout.shiftedKey(for: keyDef.key))
      XCTAssertEqual(
        KeyboardLayout.bindingKey(forStaticKey: keyDef.key, shifted: true),
        KeyboardLayout.bindingKey(for: keyDef, shifted: true))
    }
  }

  func testNonCharacterKeysAreStaticForAnyLayout() {
    Defaults[.forceEnglishKeyboardLayout] = false

    for keyDef in KeyboardLayout.rows.joined() where !keyDef.isCharacterKey {
      XCTAssertEqual(KeyboardLayout.bindingKey(for: keyDef, shifted: false), keyDef.key)
      XCTAssertEqual(KeyboardLayout.bindingKey(for: keyDef, shifted: true), keyDef.key)
    }
  }

  private func inputSource(id: String) -> TISInputSource? {
    let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
    let sources = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource]
    return sources?.first
  }

  private func keyDef(_ keyCode: Int) -> KeyDefinition {
    KeyboardLayout.rows.joined().first { $0.keyCode == UInt16(keyCode) }!
  }

  func testBindingKeyFollowsInputSource() throws {
    guard let french = inputSource(id: "com.apple.keylayout.French") else {
      throw XCTSkip("French keyboard layout is not installed")
    }
    Defaults[.forceEnglishKeyboardLayout] = false

    func key(_ keyCode: Int, shifted: Bool = false) -> String {
      KeyboardLayout.bindingKey(for: keyDef(keyCode), shifted: shifted, inputSource: french)
    }

    // AZERTY swaps A/Q and moves M
    XCTAssertEqual(key(kVK_ANSI_Q), "a")
    XCTAssertEqual(key(kVK_ANSI_A), "q")
    XCTAssertEqual(key(kVK_ANSI_Q, shifted: true), "A")
    XCTAssertEqual(key(kVK_ANSI_Semicolon), "m")
    XCTAssertEqual(key(kVK_ANSI_Semicolon, shifted: true), "M")
    XCTAssertEqual(key(kVK_ANSI_M), ",")
    XCTAssertEqual(key(kVK_ANSI_M, shifted: true), "?")

    // Digit row: symbols unshifted, digits shifted
    XCTAssertEqual(key(kVK_ANSI_1), "&")
    XCTAssertEqual(key(kVK_ANSI_1, shifted: true), "1")
    // "é" is not ASCII, so the controller falls back to the KeyMaps glyph
    XCTAssertEqual(key(kVK_ANSI_2), "2")
    XCTAssertEqual(key(kVK_ANSI_2, shifted: true), "2")

    // Dead key yields its own character
    XCTAssertEqual(key(kVK_ANSI_LeftBracket), "^")

    // Non-character keys never follow the layout
    XCTAssertEqual(key(kVK_Tab), "tab")
    XCTAssertEqual(key(kVK_Space), "space")
  }

  func testBindingKeyIgnoresInputSourceWhenForcingEnglishLayout() throws {
    guard let french = inputSource(id: "com.apple.keylayout.French") else {
      throw XCTSkip("French keyboard layout is not installed")
    }
    Defaults[.forceEnglishKeyboardLayout] = true

    XCTAssertEqual(
      KeyboardLayout.bindingKey(for: keyDef(kVK_ANSI_Q), shifted: false, inputSource: french), "q")
  }

  func testCharacterKeyCodesMatchKeyMaps() {
    // Letters and digits are the keys KeyMaps knows by code; the layout must agree
    for keyDef in KeyboardLayout.rows.joined() where keyDef.isCharacterKey {
      guard let entry = KeyMaps.entry(for: keyDef.keyCode) else { continue }
      XCTAssertEqual(entry.glyph, keyDef.key, "Key code mismatch for \(keyDef.key)")
    }
    for key in ["tab", "enter", "space"] {
      let keyDef = KeyboardLayout.rows.joined().first { $0.key == key }
      XCTAssertEqual(keyDef.flatMap { KeyMaps.entry(for: $0.keyCode)?.text }, key)
    }
  }
}
