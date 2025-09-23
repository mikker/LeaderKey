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
