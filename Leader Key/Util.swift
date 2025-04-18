import Foundation
import AppKit

func delay(_ milliseconds: Int, callback: @escaping () -> Void) {
  DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(milliseconds), execute: callback)
}

extension NSScreen {
  func center() -> NSPoint {
    let x = frame.origin.x + frame.width / 2
    let y = frame.origin.y + frame.height / 2
    return NSPoint(x: x, y: y)
  }
}

