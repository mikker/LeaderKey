import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct KeyView: View {
  let keyDef: KeyDefinition
  let binding: ActionOrGroup?
  let shiftHeld: Bool
  var scale: CGFloat = 1.0
  var showLabels: Bool = false
  var onSelect: (() -> Void)? = nil
  /// Called when a drag of this key's binding starts. Non-nil makes the key draggable.
  var onDragStart: (() -> Void)? = nil
  /// Accepts or rejects a binding dragged onto this key. Non-nil makes the key a drop target.
  var dropDelegate: KeyDropDelegate? = nil

  @State private var isHovered = false
  @State private var isCursorPushed = false
  @State private var isDropTargeted = false

  private var iconSize: NSSize {
    NSSize(width: 20 * scale, height: 20 * scale)
  }

  var body: some View {
    let width = KeyboardLayout.keyWidth(for: keyDef, scale: scale)
    let height = KeyboardLayout.scaledKeySize(scale)
    let cornerRadius = 6 * scale

    ZStack {
      // Key background
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(keyBackground)
        .shadow(color: .black.opacity(0.1), radius: 2 * scale, x: 0, y: 1 * scale)

      // Content
      ZStack {
        // Key label at top-left
        VStack {
          HStack {
            Text(displayLabel)
              .font(.system(size: 10 * scale, weight: .medium))
              .foregroundColor(keyDef.isModifier ? .secondary : .primary)
              .opacity(keyDef.isModifier ? 0.3 : 0.6)
              .padding(.leading, 4 * scale)
              .padding(.top, 4 * scale)
            Spacer()
          }
          Spacer()
        }

        // Binding icon (centered)
        if let binding = binding {
          VStack {
            actionIcon(item: binding, iconSize: iconSize, loadFavicons: true)
          }
          .offset(y: showLabels ? -4 * scale : 0)
          .overlay {
            if isHovered, !showLabels, let label = bindingLabel {
              Text(label)
                .font(.system(size: 9 * scale))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundColor(.primary)
                .padding(.horizontal, 2 * scale)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.9))
                .cornerRadius(4 * scale)
                .fixedSize()
                .offset(y: (iconSize.height / 2) + (5 * scale))
            }
          }
        }

        // Always-visible binding name along the bottom
        if showLabels, let label = bindingLabel {
          VStack {
            Spacer()
            Text(label)
              .font(.system(size: 7 * scale))
              .lineLimit(1)
              .truncationMode(.tail)
              .foregroundColor(.primary)
              .opacity(0.8)
              .padding(.leading, 3 * scale)
              .padding(.trailing, (isGroup ? 12 : 3) * scale)
              .padding(.bottom, 2 * scale)
          }
        }

        // Group indicator at bottom-right
        if case .group = binding {
          VStack {
            Spacer()
            HStack {
              Spacer()
              Image(systemName: "chevron.right")
                .font(.system(size: 8 * scale))
                .foregroundColor(.secondary)
                .padding(.trailing, 4 * scale)
                .padding(.bottom, 4 * scale)
            }
          }
        }
      }

      // Hover overlay
      if isHovered && !keyDef.isModifier && onSelect != nil {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(Color.accentColor.opacity(0.2))
      }

      // Drop target outline
      if isDropTargeted {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .strokeBorder(Color.accentColor, lineWidth: 2 * scale)
      }
    }
    .frame(width: width, height: height)
    .contentShape(Rectangle())
    .onHover { hovering in
      isHovered = hovering

      let shouldUsePointingHand = hovering && (!keyDef.isModifier || isShiftKey) && onSelect != nil
      if shouldUsePointingHand {
        if !isCursorPushed {
          NSCursor.pointingHand.push()
          isCursorPushed = true
        }
      } else if isCursorPushed {
        NSCursor.pop()
        isCursorPushed = false
      }
    }
    .onDisappear {
      if isCursorPushed {
        NSCursor.pop()
        isCursorPushed = false
      }
    }
    .onTapGesture {
      if !keyDef.isModifier || isShiftKey {
        onSelect?()
      }
    }
    .modifier(
      KeyDragDrop(
        onDragStart: binding == nil ? nil : onDragStart,
        dropDelegate: dropDelegate,
        isDropTargeted: $isDropTargeted
      ) {
        if let binding = binding {
          actionIcon(item: binding, iconSize: iconSize, loadFavicons: true)
        }
      }
    )
    .zIndex(isHovered ? 1 : 0)
  }

  private var displayLabel: String {
    if shiftHeld && !keyDef.isModifier {
      let shiftedKey = KeyboardLayout.bindingKey(for: keyDef, shifted: true)
      return KeyMaps.glyph(for: shiftedKey) ?? shiftedKey.uppercased()
    }

    let displayKey: String
    if keyDef.key.hasSuffix("_r") {
      displayKey = String(keyDef.key.dropLast(2))
    } else {
      displayKey = KeyboardLayout.bindingKey(for: keyDef, shifted: false)
    }

    return KeyMaps.glyph(for: displayKey) ?? keyDef.label
  }

  private var isGroup: Bool {
    if case .group = binding { return true }
    return false
  }

  private var isShiftKey: Bool {
    keyDef.key == "shift" || keyDef.key == "shift_r"
  }

  private var keyBackground: Color {
    if isShiftKey {
      return shiftHeld ? Color.accentColor.opacity(0.4) : Color.gray.opacity(0.1)
    } else if keyDef.isModifier {
      return Color.gray.opacity(0.05)
    } else if binding != nil {
      return Color.accentColor.opacity(0.15)
    } else {
      return Color.gray.opacity(0.1)
    }
  }

  private var bindingLabel: String? {
    switch binding {
    case .action(let action):
      return action.displayName
    case .group(let group):
      return group.displayName
    case .none:
      return nil
    }
  }
}

/// Decides what happens when a dragged binding is dropped on a key.
struct KeyDropDelegate {
  /// Whether a drag that this keyboard started is in progress and may land here.
  let canDrop: () -> Bool
  let onDrop: () -> Void
}

private struct KeyDragDrop<Preview: View>: ViewModifier {
  let onDragStart: (() -> Void)?
  let dropDelegate: KeyDropDelegate?
  @Binding var isDropTargeted: Bool
  @ViewBuilder let preview: () -> Preview

  func body(content: Content) -> some View {
    draggable(content)
      .onDrop(
        of: dropDelegate == nil ? [] : [KeyDragDrop.payloadType],
        delegate: Delegate(dropDelegate: dropDelegate, isDropTargeted: $isDropTargeted)
      )
  }

  @ViewBuilder
  private func draggable(_ content: Content) -> some View {
    if let onDragStart = onDragStart {
      content.onDrag {
        onDragStart()
        return NSItemProvider(object: "" as NSString)
      } preview: {
        preview()
      }
    } else {
      content
    }
  }

  private static var payloadType: UTType { .plainText }

  private struct Delegate: DropDelegate {
    let dropDelegate: KeyDropDelegate?
    @Binding var isDropTargeted: Bool

    func validateDrop(info: DropInfo) -> Bool {
      dropDelegate?.canDrop() ?? false
    }

    func dropEntered(info: DropInfo) {
      isDropTargeted = true
    }

    func dropExited(info: DropInfo) {
      isDropTargeted = false
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
      DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
      isDropTargeted = false
      guard let dropDelegate = dropDelegate, dropDelegate.canDrop() else { return false }
      dropDelegate.onDrop()
      return true
    }
  }
}
