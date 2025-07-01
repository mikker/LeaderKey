import Combine
import Defaults
import Foundation
import SwiftUI

// Ensure UserConfig and Group are in scope

final class UserState: ObservableObject {
  var userConfig: UserConfig!

  @Published var display: String?
  @Published var isShowingRefreshState: Bool
  @Published var navigationPath: [Group] = []

  // Store the clipboard contents captured on activation
  @Published var clipboard: String? = nil

  var currentGroup: Group? {
    return navigationPath.last
  }

  init(
    userConfig: UserConfig!,
    lastChar: String? = nil,
    isShowingRefreshState: Bool = false
  ) {
    self.userConfig = userConfig
    display = lastChar
    self.isShowingRefreshState = isShowingRefreshState
    self.navigationPath = []
  }

  func clear() {
    display = nil
    navigationPath = []
    isShowingRefreshState = false
    clipboard = nil
  }

  func navigateToGroup(_ group: Group) {
    navigationPath.append(group)
  }

  // Helper to update clipboard
  func updateClipboard(_ value: String?) {
    clipboard = value
  }
}
