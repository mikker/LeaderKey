import Combine
import Defaults
import XCTest

@testable import Leader_Key

// Note: fakeEvent helper is defined in KeyboardLayoutTests.swift
// and is accessible from this file since they're in the same test target

class ModifierHijackingTests: XCTestCase {
  var controller: Controller!
  var cancellables: Set<AnyCancellable>!
  var userState: UserState!
  var userConfig: UserConfig!
  var originalHijackControl: Bool!
  var originalHijackOption: Bool!

  override func setUp() {
    super.setUp()

    originalHijackControl = Defaults[.hijackControl]
    originalHijackOption = Defaults[.hijackOption]

    cancellables = Set<AnyCancellable>()

    // Create test instances
    userConfig = UserConfig()
    userState = UserState(userConfig: userConfig)
    controller = Controller(userState: userState, userConfig: userConfig)
  }

  override func tearDown() {
    Defaults[.hijackControl] = originalHijackControl
    Defaults[.hijackOption] = originalHijackOption
    cancellables = nil
    controller = nil
    userState = nil
    userConfig = nil
    super.tearDown()
  }

  // MARK: - Defaults Tests

  func testHijackControlDefaultsToFalse() {
    XCTAssertFalse(Defaults[.hijackControl], "hijackControl should default to false")
  }

  func testHijackOptionDefaultsToFalse() {
    XCTAssertFalse(Defaults[.hijackOption], "hijackOption should default to false")
  }

  // MARK: - Settings Tests

  func testHijackControlSettingCanBeEnabled() {
    Defaults[.hijackControl] = true
    XCTAssertTrue(Defaults[.hijackControl], "hijackControl should be enabled")
  }

  func testHijackControlSettingCanBeDisabled() {
    Defaults[.hijackControl] = true
    Defaults[.hijackControl] = false
    XCTAssertFalse(Defaults[.hijackControl], "hijackControl should be disabled")
  }

  func testHijackOptionSettingCanBeEnabled() {
    Defaults[.hijackOption] = true
    XCTAssertTrue(Defaults[.hijackOption], "hijackOption should be enabled")
  }

  func testHijackOptionSettingCanBeDisabled() {
    Defaults[.hijackOption] = true
    Defaults[.hijackOption] = false
    XCTAssertFalse(Defaults[.hijackOption], "hijackOption should be disabled")
  }

  func testControlAndOptionCanBothBeEnabled() {
    Defaults[.hijackControl] = true
    Defaults[.hijackOption] = true

    XCTAssertTrue(Defaults[.hijackControl], "hijackControl should be enabled")
    XCTAssertTrue(Defaults[.hijackOption], "hijackOption should be enabled")
  }

  // MARK: - Modifier Key Configuration Interaction Tests

  func testHijackingDoesNotAffectModifierKeyConfiguration() {
    // Set modifier key configuration
    Defaults[.modifierKeyConfiguration] = .controlGroupOptionSticky

    // Enable hijacking
    Defaults[.hijackControl] = true
    Defaults[.hijackOption] = true

    // Verify modifier key configuration is unchanged
    XCTAssertEqual(
      Defaults[.modifierKeyConfiguration],
      .controlGroupOptionSticky,
      "Modifier key configuration should remain unchanged"
    )
  }

  func testModifierKeyConfigurationDoesNotAffectHijacking() {
    // Enable hijacking
    Defaults[.hijackControl] = true
    Defaults[.hijackOption] = true

    // Change modifier key configuration
    Defaults[.modifierKeyConfiguration] = .optionGroupControlSticky

    // Verify hijacking settings are unchanged
    XCTAssertTrue(
      Defaults[.hijackControl],
      "hijackControl should remain enabled")
    XCTAssertTrue(
      Defaults[.hijackOption],
      "hijackOption should remain enabled")
  }

  // MARK: - shouldHijackEvent Tests

  func testShouldHijackEventWithControlAndHijackEnabled() {
    Defaults[.hijackControl] = true

    let ctrlEvent = fakeEvent(
      keyCode: KeyHelpers.tab.rawValue,
      characters: "\t",
      charactersIgnoringModifiers: "\t",
      modifierFlags: .control
    )

    XCTAssertTrue(
      controller.shouldHijackEvent(ctrlEvent),
      "Should hijack event when Control is pressed and hijackControl is enabled"
    )
  }

  func testShouldNotHijackEventWithControlAndHijackDisabled() {
    Defaults[.hijackControl] = false

    let ctrlEvent = fakeEvent(
      keyCode: KeyHelpers.tab.rawValue,
      characters: "\t",
      charactersIgnoringModifiers: "\t",
      modifierFlags: .control
    )

    XCTAssertFalse(
      controller.shouldHijackEvent(ctrlEvent),
      "Should not hijack event when Control is pressed but hijackControl is disabled"
    )
  }

  func testShouldHijackEventWithOptionAndHijackEnabled() {
    Defaults[.hijackOption] = true

    let optEvent = fakeEvent(
      keyCode: KeyHelpers.tab.rawValue,
      characters: "\t",
      charactersIgnoringModifiers: "\t",
      modifierFlags: .option
    )

    XCTAssertTrue(
      controller.shouldHijackEvent(optEvent),
      "Should hijack event when Option is pressed and hijackOption is enabled"
    )
  }

  func testShouldNotHijackEventWithOptionAndHijackDisabled() {
    Defaults[.hijackOption] = false

    let optEvent = fakeEvent(
      keyCode: KeyHelpers.tab.rawValue,
      characters: "\t",
      charactersIgnoringModifiers: "\t",
      modifierFlags: .option
    )

    XCTAssertFalse(
      controller.shouldHijackEvent(optEvent),
      "Should not hijack event when Option is pressed but hijackOption is disabled"
    )
  }

  func testShouldHijackEventWithBothModifiersAndControlHijackEnabled() {
    Defaults[.hijackControl] = true
    Defaults[.hijackOption] = false

    let bothEvent = fakeEvent(
      keyCode: KeyHelpers.tab.rawValue,
      characters: "\t",
      charactersIgnoringModifiers: "\t",
      modifierFlags: [.control, .option]
    )

    XCTAssertTrue(
      controller.shouldHijackEvent(bothEvent),
      "Should hijack event when both modifiers are pressed and hijackControl is enabled"
    )
  }

  func testShouldNotHijackEventWithNoModifiers() {
    Defaults[.hijackControl] = true
    Defaults[.hijackOption] = true

    let noModEvent = fakeEvent(
      keyCode: KeyHelpers.tab.rawValue,
      characters: "\t",
      charactersIgnoringModifiers: "\t"
    )

    XCTAssertFalse(
      controller.shouldHijackEvent(noModEvent),
      "Should not hijack event when no modifiers are pressed"
    )
  }

  func testShouldNotHijackEventWithCommandModifier() {
    Defaults[.hijackControl] = true
    Defaults[.hijackOption] = true

    let cmdEvent = fakeEvent(
      keyCode: KeyHelpers.tab.rawValue,
      characters: "\t",
      charactersIgnoringModifiers: "\t",
      modifierFlags: .command
    )

    XCTAssertFalse(
      controller.shouldHijackEvent(cmdEvent),
      "Should not hijack event when only Command is pressed"
    )
  }
}
