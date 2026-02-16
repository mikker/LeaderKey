import XCTest

@testable import Leader_Key

final class ConfigValidatorTests: XCTestCase {

  // Test that a valid configuration passes validation
  func testValidConfiguration() {
    // Create a valid configuration
    let group = Group(
      key: nil,  // Root group doesn't need a key
      label: "Root",
      actions: [
        .action(Action(key: "a", type: .application, value: "/Applications/App1.app")),
        .action(Action(key: "b", type: .application, value: "/Applications/App2.app")),
        .group(
          Group(
            key: "c",
            label: "Subgroup",
            actions: [
              .action(Action(key: "d", type: .application, value: "/Applications/App3.app")),
              .action(Action(key: "e", type: .application, value: "/Applications/App4.app")),
            ]
          )),
      ]
    )

    // Validate the configuration
    let errors = ConfigValidator.validate(group: group)

    // Assert that there are no errors
    XCTAssertTrue(errors.isEmpty, "Valid configuration should not have validation errors")
  }

  // Test that empty keys are detected
  func testEmptyKeys() {
    let group = Group(
      key: nil,
      label: "Root",
      actions: [
        .action(Action(key: "", type: .application, value: "/Applications/App1.app")),
        .group(
          Group(
            key: "c",
            label: "Subgroup",
            actions: [
              .action(Action(key: "", type: .application, value: "/Applications/App3.app"))
            ]
          )),
      ]
    )

    let errors = ConfigValidator.validate(group: group)

    XCTAssertEqual(errors.count, 2, "Should detect two empty keys")
    XCTAssertEqual(errors.filter { $0.type == .emptyKey }.count, 2)

    // Check paths to ensure errors are at the correct locations
    let errorPaths = errors.map { $0.path }
    XCTAssertTrue(errorPaths.contains([0]), "Should have error at path [0]")
    XCTAssertTrue(errorPaths.contains([1, 0]), "Should have error at path [1, 0]")
  }

  // Test that non-single-character keys are detected
  func testNonSingleCharacterKeys() {
    let group = Group(
      key: nil,
      label: "Root",
      actions: [
        .action(Action(key: "ab", type: .application, value: "/Applications/App1.app")),
        .group(
          Group(
            key: "cd",
            label: "Subgroup",
            actions: []
          )),
      ]
    )

    let errors = ConfigValidator.validate(group: group)

    XCTAssertEqual(errors.count, 2, "Should detect two non-single-character keys")
    XCTAssertEqual(errors.filter { $0.type == .nonSingleCharacterKey }.count, 2)

    // Check paths
    let errorPaths = errors.map { $0.path }
    XCTAssertTrue(errorPaths.contains([0]), "Should have error at path [0]")
    XCTAssertTrue(errorPaths.contains([1]), "Should have error at path [1]")
  }

  // Test that duplicate keys within the same group are detected
  func testDuplicateKeys() {
    let group = Group(
      key: nil,
      label: "Root",
      actions: [
        .action(Action(key: "a", type: .application, value: "/Applications/App1.app")),
        .action(Action(key: "a", type: .application, value: "/Applications/App2.app")),
        .group(
          Group(
            key: "c",
            label: "Subgroup",
            actions: [
              .action(Action(key: "d", type: .application, value: "/Applications/App3.app")),
              .action(Action(key: "d", type: .application, value: "/Applications/App4.app")),
            ]
          )),
      ]
    )

    let errors = ConfigValidator.validate(group: group)

    // We should have 4 errors: 2 for the duplicate 'a' keys and 2 for the duplicate 'd' keys
    XCTAssertEqual(errors.count, 4, "Should detect four errors for duplicate keys")
    XCTAssertEqual(errors.filter { $0.type == .duplicateKey }.count, 4)

    // Check paths
    let errorPaths = errors.map { $0.path }
    XCTAssertTrue(errorPaths.contains([0]), "Should have error at path [0]")
    XCTAssertTrue(errorPaths.contains([1]), "Should have error at path [1]")
    XCTAssertTrue(errorPaths.contains([2, 0]), "Should have error at path [2, 0]")
    XCTAssertTrue(errorPaths.contains([2, 1]), "Should have error at path [2, 1]")
  }

  // Test that the findItem function correctly locates items
  func testFindItem() {
    let group = Group(
      key: nil,
      label: "Root",
      actions: [
        .action(Action(key: "a", type: .application, value: "/Applications/App1.app")),
        .group(
          Group(
            key: "b",
            label: "Subgroup",
            actions: [
              .action(Action(key: "c", type: .application, value: "/Applications/App2.app"))
            ]
          )),
      ]
    )

    // Find the root group
    if case .group(let foundGroup) = ConfigValidator.findItem(in: group, at: []) {
      XCTAssertEqual(foundGroup.label, "Root")
    } else {
      XCTFail("Should find the root group")
    }

    // Find the first action
    if case .action(let foundAction) = ConfigValidator.findItem(in: group, at: [0]) {
      XCTAssertEqual(foundAction.key, "a")
      XCTAssertEqual(foundAction.value, "/Applications/App1.app")
    } else {
      XCTFail("Should find the first action")
    }

    // Find the subgroup
    if case .group(let foundGroup) = ConfigValidator.findItem(in: group, at: [1]) {
      XCTAssertEqual(foundGroup.key, "b")
      XCTAssertEqual(foundGroup.label, "Subgroup")
    } else {
      XCTFail("Should find the subgroup")
    }

    // Find the action in the subgroup
    if case .action(let foundAction) = ConfigValidator.findItem(in: group, at: [1, 0]) {
      XCTAssertEqual(foundAction.key, "c")
      XCTAssertEqual(foundAction.value, "/Applications/App2.app")
    } else {
      XCTFail("Should find the action in the subgroup")
    }

    // Test with an invalid path
    XCTAssertNil(ConfigValidator.findItem(in: group, at: [3]), "Should return nil for invalid path")
    XCTAssertNil(
      ConfigValidator.findItem(in: group, at: [0, 0]),
      "Should return nil when path goes through an action")
  }

  // MARK: - Case Sensitivity Tests

  func testCaseSensitiveKeyValidation() {
    // Test that case-sensitive keys are treated as distinct
    let group = Group(
      key: nil,
      label: "Test",
      actions: [
        .action(Action(key: "r", type: .application, value: "/Applications/Terminal.app")),
        .action(Action(key: "R", type: .application, value: "/Applications/Finder.app")),
        .action(Action(key: "h", type: .application, value: "/Applications/Calculator.app")),
        .action(Action(key: "H", type: .application, value: "/Applications/TextEdit.app")),
      ]
    )

    let errors = ConfigValidator.validate(group: group)

    // Should have no errors since all keys are distinct (case-sensitive)
    XCTAssertEqual(errors.count, 0, "Uppercase and lowercase keys should be treated as distinct")
  }

  func testKeyMapsDistinguishesCases() {
    // Test that KeyMaps correctly handles both cases
    XCTAssertNotNil(KeyMaps.byGlyph["r"])
    XCTAssertNotNil(KeyMaps.byGlyph["R"])
    XCTAssertNotEqual(KeyMaps.byGlyph["r"], KeyMaps.byGlyph["R"])

    // Test normalization preserves case
    XCTAssertEqual(KeyMaps.glyph(for: "r"), "r")
    XCTAssertEqual(KeyMaps.glyph(for: "R"), "R")
  }

  // MARK: - Tier-Aware Duplicate Detection

  func testDuplicateKeysAllowedWithDifferentTiers() {
    // Tier A + Tier C for same key = OK (precedence resolves it)
    let group = Group(
      key: nil,
      label: "Root",
      actions: [
        .action(Action(key: "a", type: .application, value: "/Applications/Global.app")),
        .action(
          Action(
            key: "a", type: .application, value: "/Applications/Chrome.app",
            when: When(includeApps: ["com.google.Chrome"]))),
      ]
    )

    let errors = ConfigValidator.validate(group: group)
    let duplicateErrors = errors.filter { $0.type == .duplicateKey }
    XCTAssertEqual(duplicateErrors.count, 0, "Tier A + Tier C should not be flagged as duplicates")
  }

  func testDuplicateKeysErrorWhenBothGlobal() {
    // Two Tier C entries for same key = error (existing behavior preserved)
    let group = Group(
      key: nil,
      label: "Root",
      actions: [
        .action(Action(key: "a", type: .application, value: "/Applications/App1.app")),
        .action(Action(key: "a", type: .application, value: "/Applications/App2.app")),
      ]
    )

    let errors = ConfigValidator.validate(group: group)
    let duplicateErrors = errors.filter { $0.type == .duplicateKey }
    XCTAssertEqual(
      duplicateErrors.count, 2, "Two global entries for same key should produce errors")
  }

  func testDuplicateKeysErrorWhenMultipleTierB() {
    // Two Tier B for same key = error
    let group = Group(
      key: nil,
      label: "Root",
      actions: [
        .action(
          Action(
            key: "a", type: .application, value: "/Applications/App1.app",
            when: When(excludeApps: ["com.google.Chrome"]))),
        .action(
          Action(
            key: "a", type: .application, value: "/Applications/App2.app",
            when: When(excludeApps: ["com.apple.Safari"]))),
      ]
    )

    let errors = ConfigValidator.validate(group: group)
    let duplicateErrors = errors.filter { $0.type == .duplicateKey }
    XCTAssertEqual(
      duplicateErrors.count, 2, "Multiple Tier B entries for same key should produce errors")
  }

  func testDuplicateKeysErrorWhenTierAOverlap() {
    // Two Tier A items with same includeApps bundle for same key = error
    let group = Group(
      key: nil,
      label: "Root",
      actions: [
        .action(
          Action(
            key: "a", type: .application, value: "/Applications/App1.app",
            when: When(includeApps: ["com.google.Chrome"]))),
        .action(
          Action(
            key: "a", type: .application, value: "/Applications/App2.app",
            when: When(includeApps: ["com.google.Chrome"]))),
      ]
    )

    let errors = ConfigValidator.validate(group: group)
    let duplicateErrors = errors.filter { $0.type == .duplicateKey }
    XCTAssertEqual(duplicateErrors.count, 2, "Overlapping Tier A entries should produce errors")
  }

  func testInvalidWhen_sameBundleInBothArrays() {
    let group = Group(
      key: nil,
      label: "Root",
      actions: [
        .action(
          Action(
            key: "a", type: .application, value: "/Applications/App1.app",
            when: When(includeApps: ["com.google.Chrome"], excludeApps: ["com.google.Chrome"])))
      ]
    )

    let errors = ConfigValidator.validate(group: group)
    let whenErrors = errors.filter { $0.type == .invalidWhen }
    XCTAssertEqual(whenErrors.count, 1, "Same bundle in both arrays should produce an error")
  }

  func testDuplicateKeysAllowedTierAAndTierB() {
    // Tier A + Tier B for same key = OK
    let group = Group(
      key: nil,
      label: "Root",
      actions: [
        .action(
          Action(
            key: "a", type: .application, value: "/Applications/EverywhereExcept.app",
            when: When(excludeApps: ["com.apple.Finder"]))),
        .action(
          Action(
            key: "a", type: .application, value: "/Applications/Chrome.app",
            when: When(includeApps: ["com.google.Chrome"]))),
      ]
    )

    let errors = ConfigValidator.validate(group: group)
    let duplicateErrors = errors.filter { $0.type == .duplicateKey }
    XCTAssertEqual(duplicateErrors.count, 0, "Tier A + Tier B should not be flagged as duplicates")
  }

  func testDuplicateKeysAllowedTierBAndTierC() {
    // Tier B + Tier C for same key = OK
    let group = Group(
      key: nil,
      label: "Root",
      actions: [
        .action(Action(key: "a", type: .application, value: "/Applications/Global.app")),
        .action(
          Action(
            key: "a", type: .application, value: "/Applications/EverywhereExcept.app",
            when: When(excludeApps: ["com.google.Chrome"]))),
      ]
    )

    let errors = ConfigValidator.validate(group: group)
    let duplicateErrors = errors.filter { $0.type == .duplicateKey }
    XCTAssertEqual(duplicateErrors.count, 0, "Tier B + Tier C should not be flagged as duplicates")
  }

  func testTierADifferentBundlesAllowed() {
    // Two Tier A items for different bundles on same key = OK
    let group = Group(
      key: nil,
      label: "Root",
      actions: [
        .action(
          Action(
            key: "a", type: .application, value: "/Applications/Chrome.app",
            when: When(includeApps: ["com.google.Chrome"]))),
        .action(
          Action(
            key: "a", type: .application, value: "/Applications/Safari.app",
            when: When(includeApps: ["com.apple.Safari"]))),
      ]
    )

    let errors = ConfigValidator.validate(group: group)
    let duplicateErrors = errors.filter { $0.type == .duplicateKey }
    XCTAssertEqual(
      duplicateErrors.count, 0, "Tier A entries for different bundles should be allowed")
  }

  func testKeyMatchingLogic() {
    // Test the core key matching logic used in Controller.handleKey
    let testCases: [(input: String, config: String, shouldMatch: Bool)] = [
      ("r", "r", true),
      ("R", "R", true),
      ("r", "R", false),  // This was the bug - these should NOT match
      ("R", "r", false),
      ("h", "h", true),
      ("H", "H", true),
      ("h", "H", false),
      ("H", "h", false),
    ]

    for testCase in testCases {
      // Simulate the key normalization logic from Controller.handleKey
      let actionKey = KeyMaps.glyph(for: testCase.config) ?? testCase.config
      let inputKey = KeyMaps.glyph(for: testCase.input) ?? testCase.input
      let matches = actionKey == inputKey

      XCTAssertEqual(
        matches, testCase.shouldMatch,
        "Input '\(testCase.input)' vs config '\(testCase.config)' should \(testCase.shouldMatch ? "match" : "not match")"
      )
    }
  }
}
