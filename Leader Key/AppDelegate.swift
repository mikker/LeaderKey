import Cocoa
import KeyboardShortcuts
import Settings
import Sparkle
import SwiftUI
import UserNotifications

let UPDATE_NOTIFICATION_IDENTIFIER = "UpdateCheck"

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, SPUStandardUserDriverDelegate,
  UNUserNotificationCenterDelegate
{
  var window: Window!
  var controller: Controller!

  let statusItem = StatusItem()
  let config = UserConfig()

  var state: UserState!
  @IBOutlet var updaterController: SPUStandardUpdaterController!

  lazy var settingsWindowController = SettingsWindowController(
    panes: [
      Settings.Pane(
        identifier: .general, title: "General",
        toolbarIcon: NSImage(named: NSImage.preferencesGeneralName)!,
        contentView: { GeneralPane().environmentObject(self.config) }
      )
    ]
  )

  func applicationDidFinishLaunching(_: Notification) {
    guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }

    UNUserNotificationCenter.current().delegate = self
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) {
      granted, error in
      if let error = error {
        print("Error requesting notification permission: \(error)")
      }
    }

    NSApp.mainMenu = MainMenu()

    state = UserState(userConfig: config)

    controller = Controller(userState: state, userConfig: config)
    window = Window(controller: controller)
    controller.window = window

    config.afterReload = { _ in
      self.state.display = "🔃"

      self.show()
      delay(1000) {
        self.hide()
      }
    }

    config.loadAndWatch()

    statusItem.handlePreferences = {
      self.settingsWindowController.show()
      NSApp.activate(ignoringOtherApps: true)
    }
    statusItem.handleReloadConfig = {
      self.config.reloadConfig()
    }
    statusItem.handleRevealConfig = {
      NSWorkspace.shared.activateFileViewerSelecting([self.config.fileURL()])
    }
    statusItem.handleCheckForUpdates = {
      self.updaterController.checkForUpdates(nil)
    }
    statusItem.enable()

    KeyboardShortcuts.onKeyUp(for: .activate) {
      if self.window.isVisible && self.window.isKeyWindow {
        self.hide()
      } else {
        self.show()
      }
    }
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
    _ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState
  ) {
    // When an update alert will be presented, place the app in the foreground
    NSApp.setActivationPolicy(.regular)

    if !state.userInitiated {
      // Add a badge to the app's dock icon indicating one alert occurred
      NSApp.dockTile.badgeLabel = "1"

      // Post a user notification
      let content = UNMutableNotificationContent()
      content.title = "Leader Key Update Available"
      content.body = "Version \(update.displayVersionString) is now available"

      let request = UNNotificationRequest(
        identifier: UPDATE_NOTIFICATION_IDENTIFIER, content: content, trigger: nil)
      UNUserNotificationCenter.current().add(request)
    }
  }

  func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
    // Clear the dock badge indicator for the update
    NSApp.dockTile.badgeLabel = ""

    // Dismiss active update notifications
    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [
      UPDATE_NOTIFICATION_IDENTIFIER
    ])
  }

  func standardUserDriverWillFinishUpdateSession() {
    // Put app back in background when update session finishes
    NSApp.setActivationPolicy(.accessory)
  }

  // MARK: - UNUserNotificationCenter Delegate

  func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if response.notification.request.identifier == UPDATE_NOTIFICATION_IDENTIFIER
      && response.actionIdentifier == UNNotificationDefaultActionIdentifier
    {
      // If notification is clicked, bring update in focus
      updaterController.checkForUpdates(nil)
    }
    completionHandler()
  }
}
