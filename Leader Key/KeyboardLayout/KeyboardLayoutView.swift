import AppKit
import Carbon.HIToolbox
import Defaults
import SwiftUI

struct KeyboardLayoutView: View {
  let bindings: [String: ActionOrGroup]
  let shiftHeld: Bool
  var scale: CGFloat = 1.0
  var showLabels: Bool = false
  var onKeySelected: ((String) -> Void)? = nil
  /// Called with the source and target binding keys when a binding is dragged onto another key.
  var onBindingMoved: ((String, String) -> Void)? = nil

  @State private var draggedBindingKey: String?

  // Key labels and binding keys depend on both of these, so redraw when either changes
  @Default(.forceEnglishKeyboardLayout) private var forceEnglishKeyboardLayout
  @State private var inputSourceRevision = 0

  var body: some View {
    VStack(alignment: .leading, spacing: KeyboardLayout.scaledRowSpacing(scale)) {
      ForEach(Array(KeyboardLayout.rows.enumerated()), id: \.offset) { _, row in
        HStack(spacing: KeyboardLayout.scaledKeySpacing(scale)) {
          ForEach(row) { keyDef in
            KeyView(
              keyDef: keyDef,
              binding: getBinding(for: keyDef),
              shiftHeld: shiftHeld,
              scale: scale,
              showLabels: showLabels,
              onSelect: {
                onKeySelected?(keyDef.key)
              },
              onDragStart: canRearrange(keyDef)
                ? { draggedBindingKey = bindingKey(for: keyDef) } : nil,
              dropDelegate: canRearrange(keyDef) ? dropDelegate(for: keyDef) : nil
            )
          }
        }
        .fixedSize()
      }
    }
    .fixedSize()
    .id("\(forceEnglishKeyboardLayout)-\(inputSourceRevision)")
    .onReceive(
      DistributedNotificationCenter.default().publisher(
        for: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String))
    ) { _ in
      inputSourceRevision += 1
    }
  }

  private func getBinding(for keyDef: KeyDefinition) -> ActionOrGroup? {
    bindings[bindingKey(for: keyDef)]
  }

  private func bindingKey(for keyDef: KeyDefinition) -> String {
    KeyboardLayout.bindingKey(for: keyDef, shifted: shiftHeld)
  }

  private func canRearrange(_ keyDef: KeyDefinition) -> Bool {
    onBindingMoved != nil && !keyDef.isModifier
  }

  private func dropDelegate(for keyDef: KeyDefinition) -> KeyDropDelegate {
    let targetKey = bindingKey(for: keyDef)
    return KeyDropDelegate(
      canDrop: {
        guard let source = draggedBindingKey else { return false }
        return source != targetKey && bindings[source] != nil
      },
      onDrop: {
        guard let source = draggedBindingKey else { return }
        draggedBindingKey = nil
        onBindingMoved?(source, targetKey)
      }
    )
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
    shiftHeld: false
  )
  .frame(width: 700, height: 300)
  .padding()
}
