import AppKit

/// Shared key capture utilities so SwiftUI and AppKit inputs stay in sync.
enum KeyCapture {
  enum Translation {
    case cancel
    case clear
    case set(String)
    case ignore
  }

  static func translate(event: NSEvent) -> Translation {
    switch event.keyCode {
    case 53:
      return .cancel
    case 51, 117:
      return .clear
    default:
      break
    }

    if let characters = event.characters, characters.count == 1 {
      if let character = characters.first, character.isLetter {
        return .set(String(character))
      }
    }

    if let entry = KeyMaps.entry(for: event.keyCode) {
      return .set(entry.glyph)
    }

    if let characters = event.charactersIgnoringModifiers ?? event.characters {
      if let first = characters.first {
        return .set(String(first))
      }
    }

    return .ignore
  }

  /// Processes an event and invokes the appropriate callbacks.
  /// - Returns: `true` when the event was handled.
  static func handle(
    event: NSEvent,
    onSet: (String?) -> Void,
    onCancel: () -> Void,
    onClear: (() -> Void)? = nil
  ) -> Bool {
    switch translate(event: event) {
    case .cancel:
      onCancel()
      return true
    case .clear:
      if let onClear {
        onClear()
      } else {
        onSet("")
      }
      return true
    case .set(let value):
      onSet(value)
      return true
    case .ignore:
      return false
    }
  }
}
