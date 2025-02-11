import Combine
import Foundation
import SwiftUI

final class UserState: ObservableObject {
  var userConfig: UserConfig!

  @Published var display: String?
  @Published var currentGroup: Group?
  @Published var isShowingRefreshState: Bool

  init(
    userConfig: UserConfig!, lastChar: String? = nil, currentGroup: Group? = nil,
    isShowingRefreshState: Bool = false
  ) {
    self.userConfig = userConfig
    display = lastChar
    self.currentGroup = currentGroup
    self.isShowingRefreshState = isShowingRefreshState
  }

  func clear() {
    display = nil
    currentGroup = userConfig.root
    isShowingRefreshState = false
  }
}
