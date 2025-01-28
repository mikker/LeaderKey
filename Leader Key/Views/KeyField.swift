import SwiftUI

struct KeyField: View {
  @Binding var text: String
  let placeholder: String
  @FocusState private var isFocused: Bool
  @State private var textField: NSTextField?

  var body: some View {
    TextField(placeholder, text: $text)
      .frame(width: 32)
      .textFieldStyle(.roundedBorder)
      .multilineTextAlignment(.center)
      .onChange(of: text) { newValue in
        if newValue.count > 1 {
          text = String(newValue.suffix(1))
        }
      }
      .focused($isFocused)
      .background(TextFieldWrapper(textField: $textField))
  }
}

// Helper view to get NSTextField reference
struct TextFieldWrapper: NSViewRepresentable {
  @Binding var textField: NSTextField?

  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    DispatchQueue.main.async {
      self.textField = view.firstSubview(ofType: NSTextField.self)
    }
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {}
}

extension NSView {
  func firstSubview<T: NSView>(ofType type: T.Type) -> T? {
    for subview in subviews {
      if let view = subview as? T {
        return view
      }
      if let foundView = subview.firstSubview(ofType: type) {
        return foundView
      }
    }
    return nil
  }
}

#Preview {
  struct Container: View {
    @State var text = "a"

    var body: some View {
      VStack(spacing: 20) {
        KeyField(text: $text, placeholder: "Key")
        Text("Current value: '\(text)'")
      }
      .padding()
      .frame(width: 300)
    }
  }

  return Container()
}
