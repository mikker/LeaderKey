import XCTest

@testable import Leader_Key

final class AppFilterTests: XCTestCase {

  // MARK: - matches tests

  func testMatches_noWhen() {
    XCTAssertTrue(AppFilter.matches(when: nil, bundleID: "com.example.app"))
  }

  func testMatches_includeApps_match() {
    let when = When(includeApps: ["com.google.Chrome"], excludeApps: nil)
    XCTAssertTrue(AppFilter.matches(when: when, bundleID: "com.google.Chrome"))
  }

  func testMatches_includeApps_noMatch() {
    let when = When(includeApps: ["com.google.Chrome"], excludeApps: nil)
    XCTAssertFalse(AppFilter.matches(when: when, bundleID: "com.apple.Safari"))
  }

  func testMatches_excludeApps_match() {
    let when = When(includeApps: nil, excludeApps: ["com.google.Chrome"])
    XCTAssertFalse(AppFilter.matches(when: when, bundleID: "com.google.Chrome"))
  }

  func testMatches_excludeApps_noMatch() {
    let when = When(includeApps: nil, excludeApps: ["com.google.Chrome"])
    XCTAssertTrue(AppFilter.matches(when: when, bundleID: "com.apple.Safari"))
  }

  func testMatches_includeAndExclude() {
    // bundleID in both include and exclude → exclude wins (AND logic)
    let when = When(includeApps: ["com.google.Chrome"], excludeApps: ["com.google.Chrome"])
    XCTAssertFalse(AppFilter.matches(when: when, bundleID: "com.google.Chrome"))
  }

  func testMatches_nilBundleID() {
    let when = When(includeApps: ["com.google.Chrome"], excludeApps: nil)
    XCTAssertFalse(AppFilter.matches(when: when, bundleID: nil))
  }

  func testMatches_nilBundleID_noWhen() {
    XCTAssertTrue(AppFilter.matches(when: nil, bundleID: nil))
  }

  func testMatches_emptyArrays() {
    let when = When(includeApps: [], excludeApps: [])
    XCTAssertTrue(AppFilter.matches(when: when, bundleID: "com.example.app"))
  }

  // MARK: - tier tests

  func testTier_noWhen() {
    XCTAssertEqual(AppFilter.tier(for: nil, bundleID: "com.example.app"), .c)
  }

  func testTier_includeAppsContainsBundleID() {
    let when = When(includeApps: ["com.google.Chrome"], excludeApps: nil)
    XCTAssertEqual(AppFilter.tier(for: when, bundleID: "com.google.Chrome"), .a)
  }

  func testTier_excludeAppsOnly() {
    let when = When(includeApps: nil, excludeApps: ["com.google.Chrome"])
    XCTAssertEqual(AppFilter.tier(for: when, bundleID: "com.apple.Safari"), .b)
  }

  func testTier_noMatch() {
    let when = When(includeApps: ["com.google.Chrome"], excludeApps: nil)
    XCTAssertNil(AppFilter.tier(for: when, bundleID: "com.apple.Safari"))
  }

  func testTier_emptyArrays() {
    let when = When(includeApps: [], excludeApps: [])
    XCTAssertEqual(AppFilter.tier(for: when, bundleID: "com.example.app"), .c)
  }

  func testTier_excludeAppsMatch() {
    let when = When(includeApps: nil, excludeApps: ["com.google.Chrome"])
    XCTAssertNil(AppFilter.tier(for: when, bundleID: "com.google.Chrome"))
  }

  // MARK: - resolve tests

  func testResolve_globalOnly() {
    let actions: [ActionOrGroup] = [
      .action(Action(key: "a", type: .application, value: "/Applications/App1.app")),
      .action(Action(key: "b", type: .application, value: "/Applications/App2.app")),
    ]

    let result = AppFilter.resolve(actions: actions, for: "com.example.app")
    XCTAssertEqual(result.count, 2)
  }

  func testResolve_tierAOverridesTierC() {
    let actions: [ActionOrGroup] = [
      .action(Action(key: "a", type: .application, value: "/Applications/Global.app")),
      .action(
        Action(
          key: "a", type: .application, value: "/Applications/Chrome.app",
          when: When(includeApps: ["com.google.Chrome"]))),
    ]

    let result = AppFilter.resolve(actions: actions, for: "com.google.Chrome")
    XCTAssertEqual(result.count, 1)
    if case .action(let action) = result.first {
      XCTAssertEqual(action.value, "/Applications/Chrome.app")
    } else {
      XCTFail("Expected an action")
    }
  }

  func testResolve_tierBOverridesTierC() {
    let actions: [ActionOrGroup] = [
      .action(Action(key: "a", type: .application, value: "/Applications/Global.app")),
      .action(
        Action(
          key: "a", type: .application, value: "/Applications/EverywhereExcept.app",
          when: When(excludeApps: ["com.google.Chrome"]))),
    ]

    let result = AppFilter.resolve(actions: actions, for: "com.apple.Safari")
    XCTAssertEqual(result.count, 1)
    if case .action(let action) = result.first {
      XCTAssertEqual(action.value, "/Applications/EverywhereExcept.app")
    } else {
      XCTFail("Expected an action")
    }
  }

  func testResolve_tierAOverridesTierB() {
    let actions: [ActionOrGroup] = [
      .action(
        Action(
          key: "a", type: .application, value: "/Applications/EverywhereExcept.app",
          when: When(excludeApps: ["com.apple.Finder"]))),
      .action(
        Action(
          key: "a", type: .application, value: "/Applications/Chrome.app",
          when: When(includeApps: ["com.google.Chrome"]))),
    ]

    let result = AppFilter.resolve(actions: actions, for: "com.google.Chrome")
    XCTAssertEqual(result.count, 1)
    if case .action(let action) = result.first {
      XCTAssertEqual(action.value, "/Applications/Chrome.app")
    } else {
      XCTFail("Expected an action")
    }
  }

  func testResolve_appSpecificHiddenForOtherApp() {
    // Tier A item hidden for non-matching app, Tier C shows
    let actions: [ActionOrGroup] = [
      .action(Action(key: "a", type: .application, value: "/Applications/Global.app")),
      .action(
        Action(
          key: "a", type: .application, value: "/Applications/Chrome.app",
          when: When(includeApps: ["com.google.Chrome"]))),
    ]

    let result = AppFilter.resolve(actions: actions, for: "com.apple.Safari")
    XCTAssertEqual(result.count, 1)
    if case .action(let action) = result.first {
      XCTAssertEqual(action.value, "/Applications/Global.app")
    } else {
      XCTFail("Expected an action")
    }
  }

  func testResolve_excludePatternHidesForMatchingApp() {
    let actions: [ActionOrGroup] = [
      .action(
        Action(
          key: "a", type: .application, value: "/Applications/NotInChrome.app",
          when: When(excludeApps: ["com.google.Chrome"])))
    ]

    let result = AppFilter.resolve(actions: actions, for: "com.google.Chrome")
    XCTAssertEqual(result.count, 0)
  }

  func testResolve_groupFilteredOut() {
    let actions: [ActionOrGroup] = [
      .group(
        Group(
          key: "g", label: "Chrome Only",
          actions: [
            .action(Action(key: "a", type: .application, value: "/Applications/App.app"))
          ], when: When(includeApps: ["com.google.Chrome"])))
    ]

    let result = AppFilter.resolve(actions: actions, for: "com.apple.Safari")
    XCTAssertEqual(result.count, 0)
  }

  func testResolve_preservesOrder() {
    let actions: [ActionOrGroup] = [
      .action(Action(key: "a", type: .application, value: "/Applications/App1.app")),
      .action(Action(key: "b", type: .application, value: "/Applications/App2.app")),
      .action(Action(key: "c", type: .application, value: "/Applications/App3.app")),
    ]

    let result = AppFilter.resolve(actions: actions, for: "com.example.app")
    XCTAssertEqual(result.count, 3)
    if case .action(let a0) = result[0], case .action(let a1) = result[1],
      case .action(let a2) = result[2]
    {
      XCTAssertEqual(a0.key, "a")
      XCTAssertEqual(a1.key, "b")
      XCTAssertEqual(a2.key, "c")
    } else {
      XCTFail("Expected actions in order")
    }
  }

  func testResolve_multipleKeysWithMixedTiers() {
    // "a" has Tier A + Tier C, "b" is global only
    let actions: [ActionOrGroup] = [
      .action(Action(key: "a", type: .application, value: "/Applications/Global.app")),
      .action(Action(key: "b", type: .application, value: "/Applications/App2.app")),
      .action(
        Action(
          key: "a", type: .application, value: "/Applications/Chrome.app",
          when: When(includeApps: ["com.google.Chrome"]))),
    ]

    let result = AppFilter.resolve(actions: actions, for: "com.google.Chrome")
    XCTAssertEqual(result.count, 2)
    // "b" should be present, and the Chrome-specific "a" should win
    let keys = result.map { $0.item.key }
    XCTAssertTrue(keys.contains("b"))
    XCTAssertTrue(keys.contains("a"))
    if case .action(let aAction) = result.first(where: { $0.item.key == "a" }) {
      XCTAssertEqual(aAction.value, "/Applications/Chrome.app")
    }
  }
}
