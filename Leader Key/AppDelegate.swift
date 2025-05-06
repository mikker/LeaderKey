import Cocoa
import Defaults
import KeyboardShortcuts
import Settings
import Sparkle
import SwiftUI
import UserNotifications

let updateLocationIdentifier = "UpdateCheck"

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate,
  SPUStandardUserDriverDelegate,
  UNUserNotificationCenterDelegate
{
  var controller: Controller!

  let statusItem = StatusItem()
  let config = UserConfig()
  var fileMonitor: FileMonitor!

  var state: UserState!
  @IBOutlet var updaterController: SPUStandardUpdaterController!

  lazy var settingsWindowController = SettingsWindowController(
    panes: [
      Settings.Pane(
        identifier: .general, title: "General",
        toolbarIcon: NSImage(named: NSImage.preferencesGeneralName)!,
        contentView: { GeneralPane().environmentObject(self.config) }
      ),
      Settings.Pane(
        identifier: .advanced, title: "Advanced",
        toolbarIcon: NSImage(named: NSImage.advancedName)!,
        contentView: {
          AdvancedPane().environmentObject(self.config)
        }),
    ],
    style: .segmentedControl
  )

  func applicationDidFinishLaunching(_: Notification) {
    guard
      ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1"
    else { return }
    guard !isRunningTests() else { return }

    UNUserNotificationCenter.current().delegate = self
    UNUserNotificationCenter.current().requestAuthorization(options: [
      .alert, .badge, .sound,
    ]) {
      granted, error in
      if let error = error {
        print("Error requesting notification permission: \(error)")
      }
    }

    NSApp.mainMenu = MainMenu()

    config.ensureAndLoad()
    state = UserState(userConfig: config)
    controller = Controller(userState: state, userConfig: config)

    Task {
      for await _ in Defaults.updates(.configDir) {
        self.fileMonitor?.stopMonitoring()

        self.fileMonitor = FileMonitor(
          fileURL: config.url,
          callback: {
            self.config.reloadConfig()
          })
        self.fileMonitor.startMonitoring()
      }
    }

    statusItem.handlePreferences = {
      self.settingsWindowController.show()
      NSApp.activate(ignoringOtherApps: true)
    }
    statusItem.handleReloadConfig = {
      self.config.reloadConfig()
    }
    statusItem.handleRevealConfig = {
      NSWorkspace.shared.activateFileViewerSelecting([self.config.url])
    }
    statusItem.handleCheckForUpdates = {
      self.updaterController.checkForUpdates(nil)
    }

    Task {
      for await value in Defaults.updates(.showMenuBarIcon) {
        if value {
          self.statusItem.enable()
        } else {
          self.statusItem.disable()
        }
      }
    }

    registerGlobalShortcuts()
  }

  func activate() {
    if self.controller.window.isKeyWindow {
      switch Defaults[.reactivateBehavior] {
      case .hide:
        self.hide()
      case .reset:
        self.controller.userState.clear()
      case .nothing:
        return
      }
    } else if self.controller.window.isVisible {
      // should never happen as the window will self-hide when not key
      self.controller.window.makeKeyAndOrderFront(nil)
    } else {
      self.show()
    }
  }

  func registerGlobalShortcuts() {
    KeyboardShortcuts.removeAllHandlers()

    KeyboardShortcuts.onKeyDown(for: .activate) {
      self.activate()
    }

    for groupKey in Defaults[.groupShortcuts] {
      print("Registering shortcut for \(groupKey)")
      KeyboardShortcuts.onKeyDown(for: KeyboardShortcuts.Name("group-\(groupKey)")) {
        if !self.controller.window.isVisible {
          self.activate()
        }
        self.processKeys([groupKey])
      }
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    config.saveConfig()
  }

  @IBAction
  func settingsMenuItemActionHandler(_: NSMenuItem) {
    settingsWindowController.show()
    NSApp.activate(ignoringOtherApps: true)
  }

  func show() {
    controller.show()
  }

  func hide() {
    controller.hide()
  }

  // MARK: - Sparkle Gentle Reminders

  var supportsGentleScheduledUpdateReminders: Bool {
    return true
  }

  func standardUserDriverWillHandleShowingUpdate(
    _ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem,
    state: SPUUserUpdateState
  ) {
    NSApp.setActivationPolicy(.regular)

    if !state.userInitiated {
      NSApp.dockTile.badgeLabel = "1"

      let content = UNMutableNotificationContent()
      content.title = "Leader Key Update Available"
      content.body = "Version \(update.displayVersionString) is now available"

      let request = UNNotificationRequest(
        identifier: updateLocationIdentifier, content: content,
        trigger: nil)
      UNUserNotificationCenter.current().add(request)
    }
  }

  func standardUserDriverDidReceiveUserAttention(
    forUpdate update: SUAppcastItem
  ) {
    NSApp.dockTile.badgeLabel = ""

    UNUserNotificationCenter.current().removeDeliveredNotifications(
      withIdentifiers: [
        updateLocationIdentifier
      ])
  }

  func standardUserDriverWillFinishUpdateSession() {
    NSApp.setActivationPolicy(.accessory)
  }

  // MARK: - UNUserNotificationCenter Delegate

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if response.notification.request.identifier
      == updateLocationIdentifier
      && response.actionIdentifier == UNNotificationDefaultActionIdentifier
    {
      updaterController.checkForUpdates(nil)
    }
    completionHandler()
  }

  func isRunningTests() -> Bool {
    let environment = ProcessInfo.processInfo.environment
    guard environment["XCTestSessionIdentifier"] != nil else { return false }
    return true
  }

  // MARK: - URL Scheme Handling

  func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls {
      handleURL(url)
    }
  }

  private func handleURL(_ url: URL) {
    guard url.scheme == "leaderkey" else { return }

    show()

    if url.host == "navigate",
      let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
      let queryItems = components.queryItems,
      let keysParam = queryItems.first(where: { $0.name == "keys" })?.value
    {
      let keys = keysParam.split(separator: ",").map(String.init)
      processKeys(keys)
    }
  }

  private func processKeys(_ keys: [String]) {
    guard !keys.isEmpty else { return }

    controller.handleKey(keys[0])

    if keys.count > 1 {
      let remainingKeys = Array(keys.dropFirst())

      var delayMs = 100
      for key in remainingKeys {
        delay(delayMs) { [weak self] in
          self?.controller.handleKey(key)
        }
        delayMs += 100
      }
    }
  }
}
