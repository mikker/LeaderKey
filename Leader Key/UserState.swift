import Combine
import Foundation
import SwiftUI

final class UserState: ObservableObject {
  var userConfig: UserConfig!

  @Published var display: String?
  @Published var currentGroup: Group?
  @Published var isShowingRefreshState: Bool
  @Published var navigationPath: [Group]?

  init(
    userConfig: UserConfig!, lastChar: String? = nil, currentGroup: Group? = nil,
    isShowingRefreshState: Bool = false
  ) {
    self.userConfig = userConfig
    display = lastChar
    self.currentGroup = currentGroup
    self.isShowingRefreshState = isShowingRefreshState
    self.navigationPath = nil
  }

  func clear() {
    display = nil
    currentGroup = nil
    navigationPath = nil
    isShowingRefreshState = false
  }

  func navigateToGroup(_ group: Group) {
    if navigationPath == nil {
      navigationPath = []
    }
    navigationPath?.append(group)
    currentGroup = group
  }
}
