import AppKit
import SwiftUI

struct KeyboardLayoutView: View {
  let bindings: [String: ActionOrGroup]
  let isEditable: Bool
  let shiftHeld: Bool
  var scale: CGFloat = 1.0
  var onKeySelected: ((String) -> Void)? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: KeyboardLayout.scaledRowSpacing(scale)) {
      ForEach(Array(KeyboardLayout.rows.enumerated()), id: \.offset) { _, row in
        HStack(spacing: KeyboardLayout.scaledKeySpacing(scale)) {
          ForEach(row) { keyDef in
            KeyView(
              keyDef: keyDef,
              binding: getBinding(for: keyDef),
              isEditable: isEditable,
              shiftHeld: shiftHeld,
              scale: scale,
              onSelect: {
                onKeySelected?(keyDef.key)
              }
            )
          }
        }
        .fixedSize()
      }
    }
    .fixedSize()
  }

  private func getBinding(for keyDef: KeyDefinition) -> ActionOrGroup? {
    if shiftHeld {
      let shiftedKey = KeyboardLayout.shiftedKey(for: keyDef.key)
      return bindings[shiftedKey]
    }
    return bindings[keyDef.key]
  }
}

#Preview {
  let sampleBindings: [String: ActionOrGroup] = [
    "s": .action(
      Action(
        key: "s",
        type: .application,
        label: "Safari",
        value: "/Applications/Safari.app"
      )),
    "v": .group(
      Group(
        key: "v",
        label: "VSCode",
        actions: []
      )),
  ]

  KeyboardLayoutView(
    bindings: sampleBindings,
    isEditable: false,
    shiftHeld: false
  )
  .frame(width: 700, height: 300)
  .padding()
}
