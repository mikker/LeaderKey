//
//  PanelWindow.swift
//  Leader Key
//
//  Created by Mikkel Malmberg on 11/02/2025.
//

import AppKit

class PanelWindow: NSPanel {
  init(contentRect: NSRect) {
    super.init(
      contentRect: contentRect,
      styleMask: [.nonactivatingPanel],
      backing: .buffered, defer: false
    )

    isFloatingPanel = true
    isReleasedWhenClosed = false
    animationBehavior = .none
    backgroundColor = .clear
    isOpaque = false
  }
}
