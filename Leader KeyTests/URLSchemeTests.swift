import XCTest

@testable import Leader_Key

final class URLSchemeTests: XCTestCase {

  // MARK: - Configuration Management Tests

  func testConfigReloadURL() {
    let url = URL(string: "leaderkey://config-reload")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .configReload)
  }

  func testConfigRevealURL() {
    let url = URL(string: "leaderkey://config-reveal")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .configReveal)
  }

  // MARK: - Window Control Tests

  func testActivateURL() {
    let url = URL(string: "leaderkey://activate")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .activate)
  }

  func testHideURL() {
    let url = URL(string: "leaderkey://hide")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .hide)
  }

  func testResetURL() {
    let url = URL(string: "leaderkey://reset")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .reset)
  }

  // MARK: - Settings & Info Tests

  func testSettingsURL() {
    let url = URL(string: "leaderkey://settings")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .settings)
  }

  func testAboutURL() {
    let url = URL(string: "leaderkey://about")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .about)
  }

  // MARK: - Navigation Tests

  func testNavigateWithKeys() {
    let url = URL(string: "leaderkey://navigate?keys=a,b,c")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .navigate(keys: ["a", "b", "c"], execute: true))
  }

  func testNavigateWithExecuteFalse() {
    let url = URL(string: "leaderkey://navigate?keys=a,b&execute=false")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .navigate(keys: ["a", "b"], execute: false))
  }

  func testNavigateWithExecuteTrue() {
    let url = URL(string: "leaderkey://navigate?keys=x,y&execute=true")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .navigate(keys: ["x", "y"], execute: true))
  }

  func testNavigateWithSingleKey() {
    let url = URL(string: "leaderkey://navigate?keys=z")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .navigate(keys: ["z"], execute: true))
  }

  func testNavigateWithoutKeys() {
    let url = URL(string: "leaderkey://navigate")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .show)
  }

  // MARK: - Invalid URL Tests

  func testInvalidScheme() {
    let url = URL(string: "invalid://settings")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .invalid)
  }

  func testUnknownHost() {
    let url = URL(string: "leaderkey://unknown")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .show)
  }
}
