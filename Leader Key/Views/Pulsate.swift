//
//  Pulsate.swift
//  Leader Key
//
//  Created by Lennart Egbers on 03.02.25.
//

import Foundation
import SwiftUICore
import SwiftUI

public struct Pulsate: ViewModifier {
  @State var scale: Bool = true
  
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
  func pulsate(duration: TimeInterval, targetScale: CGFloat = 1.2) -> some View {
    self.modifier(Pulsate(duration: duration, targetScale: targetScale))
  }
}

struct Pulsate_Preview: PreviewProvider {
  static var previews: some View {
    ZStack {
      Text("●")
        .font(.system(size: 28, weight: .semibold, design: .rounded))
        .pulsate(duration: 1)
    }.padding(16)
  }
}
