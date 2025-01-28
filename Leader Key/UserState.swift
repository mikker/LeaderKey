import Combine
import Foundation
import SwiftUI

final class UserState: ObservableObject {
  var userConfig: UserConfig!

  @Published var display: String?
  @Published var currentGroup: Group?

  init(userConfig: UserConfig!, lastChar: String? = nil, currentGroup: Group? = nil) {
    self.userConfig = userConfig
    display = lastChar
    self.currentGroup = currentGroup
  }

  func clear() {
    display = nil
    currentGroup = userConfig.root
  }
}
