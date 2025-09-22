//
//  Pulsate.swift
//  Leader Key
//
//  Created by Lennart Egbers on 03.02.25.
//

import Foundation
import SwiftUI

public struct Pulsate: ViewModifier {
  @State var scale: Bool = true

  static let singleDurationS = 0.15

  let duration: TimeInterval
  let targetScale: CGFloat

  init(duration: TimeInterval, targetScale: CGFloat) {
    self.duration = duration
    self.targetScale = targetScale
  }

  public func body(content: Content) -> some View {
    content.onAppear {
      withAnimation(Animation.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
        scale.toggle()
      }
    }
    .scaleEffect(scale ? 1 : targetScale)
  }
}

extension View {
  func pulsate(duration: TimeInterval = Pulsate.singleDurationS, targetScale: CGFloat = 1.3)
    -> some View
  {
    self.modifier(Pulsate(duration: duration, targetScale: targetScale))
  }
}

struct Pulsate_Preview: PreviewProvider {
  static var previews: some View {
    ZStack {
      Text("●")
        .font(.system(size: 28, weight: .semibold, design: .rounded))
        .pulsate(duration: Pulsate.singleDurationS)
    }.padding(32)
  }
}
