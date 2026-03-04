import AppKit
import SwiftUI

struct KeyView: View {
  let keyDef: KeyDefinition
  let binding: ActionOrGroup?
  let isEditable: Bool
  let shiftHeld: Bool
  var scale: CGFloat = 1.0
  var onSelect: (() -> Void)? = nil

  @State private var isHovered = false
  @State private var isCursorPushed = false

  private var iconSize: NSSize {
    NSSize(width: 20 * scale, height: 20 * scale)
  }

  var body: some View {
    let width =
      keyDef.width * KeyboardLayout.scaledKeySize(scale) + (keyDef.width - 1)
      * KeyboardLayout.scaledKeySpacing(scale)
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
          .overlay {
            if isHovered, let label = bindingLabel {
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
    .zIndex(isHovered ? 1 : 0)
  }

  private var displayLabel: String {
    if shiftHeld && !keyDef.isModifier {
      let shiftedKey = KeyboardLayout.shiftedKey(for: keyDef.key)
      return KeyMaps.glyph(for: shiftedKey) ?? shiftedKey.uppercased()
    }

    let displayKey: String
    if keyDef.key.hasSuffix("_r") {
      displayKey = String(keyDef.key.dropLast(2))
    } else {
      displayKey = keyDef.key
    }

    return KeyMaps.glyph(for: displayKey) ?? keyDef.label
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
