import Combine
import Foundation
import SwiftUI

final class UserState: ObservableObject {
  var userConfig: UserConfig!

  @Published var display: String?
  @Published var currentGroup: Group?
  @Published var isLoading: Bool

  init(userConfig: UserConfig!, lastChar: String? = nil, currentGroup: Group? = nil, isLoading: Bool = false) {
    self.userConfig = userConfig
    display = lastChar
    self.currentGroup = currentGroup
    self.isLoading = isLoading
  }

  func clear() {
    display = nil
    currentGroup = userConfig.root
    isLoading = false
  }
}
