import Defaults
import XCTest

@testable import Leader_Key

class TestAlertManager: AlertHandler {
  var shownAlerts: [(style: NSAlert.Style, message: String)] = []

  func showAlert(style: NSAlert.Style, message: String) {
    shownAlerts.append((style: style, message: message))
  }

  func reset() {
    shownAlerts = []
  }
}

final class UserConfigTests: XCTestCase {
  var tempBaseDir: String!
  var testAlertManager: TestAlertManager!
  var subject: UserConfig!
  var originalSuite: UserDefaults!

  override func setUp() {
    super.setUp()

    // Create a temporary UserDefaults suite for testing
    originalSuite = defaultsSuite
    defaultsSuite = UserDefaults(suiteName: UUID().uuidString)!

    // Create a unique temporary directory for each test
    tempBaseDir = NSTemporaryDirectory().appending("/LeaderKeyTests-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(atPath: tempBaseDir, withIntermediateDirectories: true)

    testAlertManager = TestAlertManager()
    subject = UserConfig(alertHandler: testAlertManager)

    // Set the config directory to our temp directory by default
    Defaults[.configDir] = tempBaseDir
  }

  override func tearDown() {
    try? FileManager.default.removeItem(atPath: tempBaseDir)
    testAlertManager.reset()

    // Restore original UserDefaults suite
    defaultsSuite = originalSuite

    subject = nil
    super.tearDown()
  }

  func testInitializesWithDefaults() throws {
    subject.ensureAndLoad()

    XCTAssertNotEqual(subject.root, emptyRoot)
    XCTAssertTrue(subject.exists)
    XCTAssertEqual(testAlertManager.shownAlerts.count, 0)
  }

  func testCreatesDefaultConfigDirIfNotExists() throws {
    let defaultDir = UserConfig.defaultDirectory()
    // Remove both directory and config file
    try? FileManager.default.removeItem(atPath: defaultDir)
    try? FileManager.default.removeItem(
      atPath: (defaultDir as NSString).appendingPathComponent("config.json"))
    Defaults[.configDir] = defaultDir

    subject.ensureAndLoad()

    XCTAssertTrue(FileManager.default.fileExists(atPath: defaultDir))
    XCTAssertTrue(subject.exists)
    XCTAssertEqual(testAlertManager.shownAlerts.count, 0)
    XCTAssertNotEqual(subject.root, emptyRoot)  // Verify the config was parsed successfully
  }

  func testResetsToDefaultDirWhenCustomDirDoesNotExist() throws {
    let nonExistentDir = tempBaseDir.appending("/DoesNotExist")
    Defaults[.configDir] = nonExistentDir

    subject.ensureAndLoad()

    XCTAssertEqual(Defaults[.configDir], UserConfig.defaultDirectory())
    XCTAssertEqual(testAlertManager.shownAlerts.count, 1)
    XCTAssertEqual(testAlertManager.shownAlerts[0].style, .warning)
    XCTAssertTrue(
      testAlertManager.shownAlerts[0].message.contains("Config directory does not exist"))
    XCTAssertTrue(subject.exists)
  }

  func testShowsAlertWhenConfigFileFailsToParse() throws {
    // First ensure we're in the default directory since custom dirs are no longer supported
    Defaults[.configDir] = UserConfig.defaultDirectory()

    let invalidJSON = "{ invalid json }"
    try invalidJSON.write(to: subject.url, atomically: true, encoding: .utf8)

    subject.ensureAndLoad()

    XCTAssertEqual(subject.root, emptyRoot)
    XCTAssertGreaterThan(testAlertManager.shownAlerts.count, 0)
    // Verify that at least one critical alert was shown
    XCTAssertTrue(
      testAlertManager.shownAlerts.contains { alert in
        alert.style == .critical
      })
  }
}
