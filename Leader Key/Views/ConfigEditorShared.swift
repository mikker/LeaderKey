import AppKit
import ObjectiveC

enum ConfigEditorUI {
  static func setButtonTitle(_ button: NSButton, text: String, placeholder: Bool) {
    let attr = NSMutableAttributedString(string: text)
    let color: NSColor = placeholder ? .secondaryLabelColor : .labelColor
    attr.addAttribute(
      .foregroundColor, value: color, range: NSRange(location: 0, length: attr.length))
    button.title = text
    button.attributedTitle = attr
  }

  static func presentMoreMenu(
    anchor: NSView?,
    onDuplicate: @escaping () -> Void,
    onDelete: @escaping () -> Void
  ) {
    guard let anchor else { return }
    let menu = NSMenu()
    menu.addItem(
      withTitle: "Duplicate",
      action: #selector(MenuHandler.duplicate),
      keyEquivalent: ""
    )
    menu.addItem(
      withTitle: "Delete",
      action: #selector(MenuHandler.delete),
      keyEquivalent: ""
    )
    let handler = MenuHandler(onDuplicate: onDuplicate, onDelete: onDelete)
    for item in menu.items { item.target = handler }
    objc_setAssociatedObject(
      menu,
      &handlerAssociationKey,
      handler,
      .OBJC_ASSOCIATION_RETAIN_NONATOMIC
    )
    let point = NSPoint(x: 0, y: anchor.bounds.height)
    menu.popUp(positioning: nil, at: point, in: anchor)
  }

  static func presentIconMenu(
    anchor: NSView?,
    onPickAppIcon: @escaping () -> Void,
    onPickSymbol: @escaping () -> Void,
    onPickCustomImage: @escaping () -> Void,
    onClear: @escaping () -> Void
  ) {
    guard let anchor else { return }
    let menu = NSMenu()
    menu.addItem(
      withTitle: "App Icon…",
      action: #selector(MenuHandler.pickAppIcon),
      keyEquivalent: ""
    )
    menu.addItem(
      withTitle: "Symbol…",
      action: #selector(MenuHandler.pickSymbol),
      keyEquivalent: ""
    )
    menu.addItem(
      withTitle: "Custom Icon…",
      action: #selector(MenuHandler.pickCustomImage),
      keyEquivalent: ""
    )
    menu.addItem(NSMenuItem.separator())
    menu.addItem(withTitle: "Clear", action: #selector(MenuHandler.clearIcon), keyEquivalent: "")
    let handler = MenuHandler(
      onPickAppIcon: onPickAppIcon,
      onPickSymbol: onPickSymbol,
      onPickCustomImage: onPickCustomImage,
      onClearIcon: onClear,
      onDuplicate: {},
      onDelete: {}
    )
    for item in menu.items { item.target = handler }
    objc_setAssociatedObject(
      menu,
      &handlerAssociationKey,
      handler,
      .OBJC_ASSOCIATION_RETAIN_NONATOMIC
    )
    let point = NSPoint(x: 0, y: anchor.bounds.height)
    menu.popUp(positioning: nil, at: point, in: anchor)
  }

  private static var handlerAssociationKey: UInt8 = 0

  private final class MenuHandler: NSObject {
    let onPickAppIcon: (() -> Void)?
    let onPickSymbol: (() -> Void)?
    let onPickCustomImage: (() -> Void)?
    let onClearIcon: (() -> Void)?
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    init(
      onPickAppIcon: (() -> Void)? = nil,
      onPickSymbol: (() -> Void)? = nil,
      onPickCustomImage: (() -> Void)? = nil,
      onClearIcon: (() -> Void)? = nil,
      onDuplicate: @escaping () -> Void,
      onDelete: @escaping () -> Void
    ) {
      self.onPickAppIcon = onPickAppIcon
      self.onPickSymbol = onPickSymbol
      self.onPickCustomImage = onPickCustomImage
      self.onClearIcon = onClearIcon
      self.onDuplicate = onDuplicate
      self.onDelete = onDelete
    }

    @objc func pickAppIcon() { onPickAppIcon?() }
    @objc func pickSymbol() { onPickSymbol?() }
    @objc func pickCustomImage() { onPickCustomImage?() }
    @objc func clearIcon() { onClearIcon?() }
    @objc func duplicate() { onDuplicate() }
    @objc func delete() { onDelete() }
  }

  static func resizeAndRoundImage(_ image: NSImage, size: CGFloat) -> NSImage {
    CustomIconRenderer.render(image, size: NSSize(width: size, height: size))
  }
}

extension Action {
  func resolvedIcon() -> NSImage? {
    if let iconPath = iconPath, !iconPath.isEmpty {
      if iconPath.hasSuffix(".app") {
        return NSWorkspace.shared.icon(forFile: iconPath)
      }
      if let customImage = CustomIconRenderer.renderCustomIcon(
        from: iconPath,
        size: NSSize(width: 28, height: 28)
      ) {
        return customImage
      }
      if let img = NSImage(systemSymbolName: iconPath, accessibilityDescription: nil) {
        return img
      }
    }
    switch type {
    case .application:
      return NSWorkspace.shared.icon(forFile: value)
    case .url:
      return NSImage(systemSymbolName: "link", accessibilityDescription: nil)
    case .command:
      return NSImage(systemSymbolName: "terminal", accessibilityDescription: nil)
    case .folder:
      return NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
    default:
      return NSImage(systemSymbolName: "questionmark", accessibilityDescription: nil)
    }
  }
}

extension Group {
  func resolvedIcon() -> NSImage? {
    if let iconPath = iconPath, !iconPath.isEmpty {
      if iconPath.hasSuffix(".app") { return NSWorkspace.shared.icon(forFile: iconPath) }
      if let customImage = CustomIconRenderer.renderCustomIcon(
        from: iconPath,
        size: NSSize(width: 28, height: 28)
      ) {
        return customImage
      }
      if let img = NSImage(systemSymbolName: iconPath, accessibilityDescription: nil) { return img }
    }
    return NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
  }
}
