import AppKit
import SwiftUI

struct KeyButton: View {
  @Binding var text: String
  let placeholder: String
  @State private var isListening = false
  @State private var oldValue = ""

  var body: some View {
    Button(action: {
      oldValue = text  // Store the old value when entering listening mode
      isListening = true
    }) {
      Text(text.isEmpty ? placeholder : text)
        .frame(width: 32, height: 24)
        .background(
          RoundedRectangle(cornerRadius: 5)
            .fill(isListening ? Color.blue.opacity(0.2) : Color(.controlBackgroundColor))
            .overlay(
              RoundedRectangle(cornerRadius: 5)
                .stroke(isListening ? Color.blue : Color.gray.opacity(0.5), lineWidth: 1)
            )
        )
        .foregroundColor(text.isEmpty ? .gray : .primary)
    }
    .buttonStyle(PlainButtonStyle())
    .background(KeyListenerView(isListening: $isListening, text: $text, oldValue: $oldValue))
  }
}

// NSViewRepresentable to listen for key events
struct KeyListenerView: NSViewRepresentable {
  @Binding var isListening: Bool
  @Binding var text: String
  @Binding var oldValue: String

  func makeNSView(context: Context) -> NSView {
    let view = KeyListenerNSView()
    view.isListening = $isListening
    view.text = $text
    view.oldValue = $oldValue
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    if let view = nsView as? KeyListenerNSView {
      view.isListening = $isListening
      view.text = $text
      view.oldValue = $oldValue

      // When isListening changes to true, make this view the first responder
      if isListening {
        DispatchQueue.main.async {
          view.window?.makeFirstResponder(view)
        }
      }
    }
  }

  class KeyListenerNSView: NSView {
    var isListening: Binding<Bool>?
    var text: Binding<String>?
    var oldValue: Binding<String>?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      // Don't automatically become first responder here
      // We'll do it in updateNSView when isListening becomes true
    }

    override func keyDown(with event: NSEvent) {
      guard let isListening = isListening, let text = text, isListening.wrappedValue else {
        super.keyDown(with: event)
        return
      }

      // Handle escape key - cancel and revert to old value
      if event.keyCode == 53 {  // Escape key
        if let oldValue = oldValue {
          text.wrappedValue = oldValue.wrappedValue
        }
        DispatchQueue.main.async {
          isListening.wrappedValue = false
        }
        return
      }

      // Handle backspace/delete - clear the value
      if event.keyCode == 51 || event.keyCode == 117 {  // Backspace or Delete
        text.wrappedValue = ""
        DispatchQueue.main.async {
          isListening.wrappedValue = false
        }
        return
      }

      // Handle regular key presses
      if let characters = event.characters, !characters.isEmpty {
        text.wrappedValue = String(characters.first!)
        // Set isListening to false after a short delay to ensure the key event is processed
        DispatchQueue.main.async {
          isListening.wrappedValue = false
        }
      }
    }

    // Add this method to handle when the view loses focus
    override func resignFirstResponder() -> Bool {
      // If we're still in listening mode when losing focus, exit listening mode
      if let isListening = isListening, isListening.wrappedValue {
        DispatchQueue.main.async {
          isListening.wrappedValue = false
        }
      }
      return super.resignFirstResponder()
    }
  }
}

#Preview {
  struct Container: View {
    @State var text = "a"

    var body: some View {
      VStack(spacing: 20) {
        KeyButton(text: $text, placeholder: "Key")
        Text("Current value: '\(text)'")
      }
      .padding()
      .frame(width: 300)
    }
  }

  return Container()
}
