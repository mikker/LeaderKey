import Cocoa
import Foundation

func delay(_ milliseconds: Int, callback: @escaping () -> Void) {
  DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(milliseconds), execute: callback)
}

func tintedImage(named name: String, color: NSColor) -> NSImage? {
  guard let image = NSImage(named: name),
    let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
  else { return nil }

  let newImage = NSImage(size: image.size)
  newImage.lockFocus()

  if let ctx = NSGraphicsContext.current?.cgContext {
    // Draw original image
    ctx.draw(cgImage, in: CGRect(origin: .zero, size: image.size))

    // Overlay with color
    ctx.setBlendMode(.sourceAtop)
    ctx.setFillColor(color.cgColor)
    ctx.fill(CGRect(origin: .zero, size: image.size))
  }

  newImage.unlockFocus()
  return newImage
}
