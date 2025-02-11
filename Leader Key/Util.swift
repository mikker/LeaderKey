import Foundation

func delay(_ milliseconds: Int, callback: @escaping () -> Void) {
  DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(milliseconds), execute: callback)
}
