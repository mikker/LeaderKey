import AppKit
import Defaults
import Settings
import SwiftUI
import UniformTypeIdentifiers

struct EditorWrapper: Identifiable {
  var id: String { item.uiid.uuidString }
  var item: ActionOrGroup
  var keyName: String
  var isNew: Bool = false
}

struct UnifiedEditorView: View {
  @Binding var item: ActionOrGroup
  var keyName: String
  var isNew: Bool
  var onSave: (ActionOrGroup) -> Void
  var onDelete: (ActionOrGroup) -> Void
  var onOpenLayout: (ActionOrGroup) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var showIconPicker = false

  // Temporary state to hold values when switching types
  @State private var actionType: Type = .application
  @State private var label: String = ""
  @State private var value: String = ""
  @State private var iconPath: String?

  @FocusState private var isValueFieldFocused: Bool

  // Type selection for the segmented control
  enum ItemType: String, CaseIterable {
    case action = "Action"
    case group = "Group"
  }

  @State private var selectedType: ItemType = .action

  init(
    item: Binding<ActionOrGroup>,
    keyName: String,
    isNew: Bool,
    onSave: @escaping (ActionOrGroup) -> Void,
    onDelete: @escaping (ActionOrGroup) -> Void,
    onOpenLayout: @escaping (ActionOrGroup) -> Void
  ) {
    self._item = item
    self.keyName = keyName
    self.isNew = isNew
    self.onSave = onSave
    self.onDelete = onDelete
    self.onOpenLayout = onOpenLayout

    // Initialize local state based on input item
    switch item.wrappedValue {
    case .action(let action):
      _selectedType = State(initialValue: .action)
      _actionType = State(initialValue: action.type)
      _label = State(initialValue: action.label ?? "")
      _value = State(initialValue: action.value)
      _iconPath = State(initialValue: action.iconPath)
    case .group(let group):
      _selectedType = State(initialValue: .group)
      _label = State(initialValue: group.label ?? "")
      _iconPath = State(initialValue: group.iconPath)
    }
  }

  var body: some View {
    VStack(spacing: 20) {
      // Key being edited indicator
      Text("Editing '\(keyName)'")
        .font(.title2)
        .foregroundColor(.secondary)
        .padding(.top, 12)

      // Header: Icon & Label
      VStack(spacing: 12) {
        // Icon Picker
        Button {
          showIconPicker = true
        } label: {
          if let icon = resolveIcon() {
            Image(nsImage: icon)
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 64, height: 64)
              .shadow(radius: 2)
          } else {
            ZStack {
              Circle().fill(Color.secondary.opacity(0.1))
                .frame(width: 64, height: 64)
              Image(systemName: "photo")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
            }
          }
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
          if iconPath != nil {
            Button {
              iconPath = nil
              updateItem()
            } label: {
              Image(systemName: "xmark.circle.fill")
                .foregroundColor(.secondary)
                .background(Circle().fill(Color(nsColor: .windowBackgroundColor)))
            }
            .buttonStyle(.plain)
            .offset(x: 4, y: -4)
          }
        }

        // Label Input
        TextField("Label", text: $label)
          .textFieldStyle(.plain)
          .font(.title2)
          .multilineTextAlignment(.center)
          .padding(6)
          .overlay(
            RoundedRectangle(cornerRadius: 8)
              .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
          )
          .frame(maxWidth: 220)
          .onChange(of: label) { _ in updateItem() }
      }
      .padding(.top, 24)

      // Type Switcher
      Picker("", selection: $selectedType) {
        ForEach(ItemType.allCases, id: \.self) { type in
          Text(type.rawValue).tag(type)
        }
      }
      .pickerStyle(.segmented)
      .padding(.horizontal, 32)
      .onChange(of: selectedType) { newType in
        updateItemType(newType)
      }

      // Content Area
      VStack(alignment: .leading, spacing: 16) {
        if selectedType == .action {
          // Action Type Picker
          HStack {
            Text("Action Type")
              .font(.subheadline)
              .foregroundColor(.secondary)
            Spacer()
            Picker("", selection: $actionType) {
              Text("Application").tag(Type.application)
              Text("URL").tag(Type.url)
              Text("Command").tag(Type.command)
              Text("Folder").tag(Type.folder)
            }
            .labelsHidden()
            .fixedSize()
          }
          .onChange(of: actionType) { _ in updateItem() }

          // Value Input
          VStack(alignment: .leading, spacing: 6) {
            Text(valueLabel)
              .font(.caption)
              .fontWeight(.semibold)
              .foregroundColor(.secondary)

            HStack {
              TextField("Enter value...", text: $value)
                .textFieldStyle(.roundedBorder)
                .focused($isValueFieldFocused)
                .onTapGesture {
                  isValueFieldFocused = true
                }
                .onChange(of: value) { _ in updateItem() }

              if actionType == .application || actionType == .folder {
                Button {
                  openFilePicker()
                } label: {
                  Image(systemName: "folder")
                }
                .buttonStyle(.bordered)
              }
            }
          }
        } else {
          // Group Mode
          Spacer()
        }
      }
      .padding(.horizontal, 24)

      Spacer()

      // Footer
      HStack {
        if selectedType == .group {
          // Group mode: Cancel button
          Button("Cancel") {
            dismiss()
          }
          .keyboardShortcut(.cancelAction)
          .buttonStyle(.bordered)
          .controlSize(.regular)
        } else if !isNew {
          // Action mode: Delete button
          Button(role: .destructive) {
            onDelete(item)
          } label: {
            Image(systemName: "trash")
              .font(.system(size: 16))
              .foregroundColor(.secondary)
          }
          .buttonStyle(.plain)
          .help("Delete Item")
        }

        Spacer()

        Button(selectedType == .group ? "Assign Actions" : "Done") {
          let updated = getUpdatedItem()
          item = updated
          onSave(updated)
          if selectedType == .group {
            onOpenLayout(updated)
          }
        }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.borderedProminent)
        .controlSize(.regular)
      }
      .padding(20)
      .background(Color(nsColor: .controlBackgroundColor))
    }
    .frame(width: 320, height: 480)
    .fileImporter(
      isPresented: $showIconPicker,
      allowedContentTypes: [.image, .icns],
      allowsMultipleSelection: false
    ) { result in
      switch result {
      case .success(let urls):
        if let url = urls.first {
          iconPath = url.path
          updateItem()
        }
      case .failure(let error):
        print("Icon selection error: \(error.localizedDescription)")
      }
    }
  }

  private func updateItemType(_ type: ItemType) {
    let key = item.key
    if type == .action {
      item = .action(
        Action(
          uiid: item.uiid,
          key: key,
          type: actionType,
          label: label.isEmpty ? nil : label,
          value: value,
          iconPath: iconPath
        )
      )
    } else {
      let existingActions: [ActionOrGroup]
      if case .group(let existingGroup) = item {
        existingActions = existingGroup.actions
      } else {
        existingActions = []
      }
      item = .group(
        Group(
          uiid: item.uiid,
          key: key,
          label: label.isEmpty ? nil : label,
          iconPath: iconPath,
          actions: existingActions
        )
      )
    }
  }

  private func updateItem() {
    item = getUpdatedItem()
  }

  private func getUpdatedItem() -> ActionOrGroup {
    let key = item.key
    let currentLabel = label.isEmpty ? nil : label

    switch selectedType {
    case .action:
      if case .action(let existingAction) = item {
        var updated = existingAction
        updated.key = key
        updated.type = actionType
        updated.label = currentLabel
        updated.value = value
        updated.iconPath = iconPath
        return .action(updated)
      } else {
        return .action(
          Action(
            uiid: item.uiid,
            key: key,
            type: actionType,
            label: currentLabel,
            value: value,
            iconPath: iconPath
          )
        )
      }
    case .group:
      if case .group(let existingGroup) = item {
        var newGroup = existingGroup
        newGroup.label = currentLabel
        newGroup.iconPath = iconPath
        return .group(newGroup)
      } else {
        return .group(
          Group(
            uiid: item.uiid,
            key: key,
            label: currentLabel,
            iconPath: iconPath,
            actions: []
          )
        )
      }
    }
  }

  private func resolveIcon() -> NSImage? {
    switch item {
    case .action(let action): return action.resolvedIcon()
    case .group(let group): return group.resolvedIcon()
    }
  }

  private var valueLabel: String {
    switch actionType {
    case .application: return "Application Path"
    case .url: return "URL"
    case .command: return "Shell Command"
    case .folder: return "Folder Path"
    default: return "Value"
    }
  }

  private var allowedFileTypes: [UTType] {
    switch actionType {
    case .application: return [.application, .applicationBundle]
    case .folder: return [.folder]
    default: return []
    }
  }

  private func openFilePicker() {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = actionType == .folder
    panel.canChooseFiles = actionType != .folder
    panel.allowedContentTypes = allowedFileTypes

    if actionType == .application {
      panel.directoryURL = URL(fileURLWithPath: "/Applications")
    }

    panel.begin { response in
      if response == .OK, let url = panel.url {
        self.value = url.path
        self.updateItem()
      }
    }
  }
}

struct GroupWrapper: Identifiable {
  var id: String { group.uiid.uuidString }
  var group: KeyGroup
}

struct GroupEditorView: View {
  @Binding var group: KeyGroup
  var onSave: () -> Void
  var onDelete: () -> Void
  var onOpenLayout: () -> Void

  @State private var showIconPicker = false

  var body: some View {
    VStack(spacing: 20) {
      // Header: Icon & Label
      VStack(spacing: 12) {
        // Icon Picker
        Button {
          showIconPicker = true
        } label: {
          if let icon = group.resolvedIcon() {
            Image(nsImage: icon)
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 64, height: 64)
              .shadow(radius: 2)
          } else {
            ZStack {
              Circle().fill(Color.secondary.opacity(0.1))
                .frame(width: 64, height: 64)
              Image(systemName: "folder")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
            }
          }
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
          if group.iconPath != nil {
            Button {
              group.iconPath = nil
            } label: {
              Image(systemName: "xmark.circle.fill")
                .foregroundColor(.secondary)
                .background(Circle().fill(Color(nsColor: .windowBackgroundColor)))
            }
            .buttonStyle(.plain)
            .offset(x: 4, y: -4)
          }
        }

        // Label Input
        TextField(
          "Label",
          text: Binding(
            get: { group.label ?? "" },
            set: { group.label = $0.isEmpty ? nil : $0 }
          )
        )
        .textFieldStyle(.plain)
        .font(.title2)
        .multilineTextAlignment(.center)
        .padding(6)
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
        .frame(maxWidth: 220)
      }
      .padding(.top, 24)

      Text("Edit group settings")
        .font(.subheadline)
        .foregroundColor(.secondary)

      Spacer()

      // Footer
      HStack {
        Button(role: .destructive) {
          onDelete()
        } label: {
          Image(systemName: "trash")
            .font(.system(size: 16))
            .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
        .help("Delete Group")

        Spacer()

        Button("Done") {
          onSave()
        }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.borderedProminent)
        .controlSize(.regular)
      }
      .padding(20)
      .background(Color(nsColor: .controlBackgroundColor))
    }
    .frame(width: 320, height: 350)
    .fileImporter(
      isPresented: $showIconPicker,
      allowedContentTypes: [.image, .icns],
      allowsMultipleSelection: false
    ) { result in
      switch result {
      case .success(let urls):
        if let url = urls.first {
          group.iconPath = url.path
        }
      case .failure(let error):
        print("Icon selection error: \(error.localizedDescription)")
      }
    }
  }
}

struct KeyboardPane: View {
  private let contentWidth = 950.0
  private let maxKeyboardScale: CGFloat = 1.4
  @EnvironmentObject private var config: UserConfig
  @Default(.cheatsheetStyle) var cheatsheetStyle

  @State private var editingItem: EditorWrapper?
  @State private var editingGroupWrapper: GroupWrapper?
  @State private var currentGroupPath: [UUID] = []
  @State private var keyboardScale: CGFloat = 1.4
  @State private var shiftHeld = false
  @State private var stickyShiftMode = false  // Persists after editing capital letter keys
  @State private var monitor: Any?

  var currentGroup: KeyGroup {
    if let id = currentGroupPath.last {
      return config.root.find(id: id) ?? config.root
    }
    return config.root
  }

  var bindings: [String: ActionOrGroup] {
    var result: [String: ActionOrGroup] = [:]

    for item in currentGroup.actions {
      switch item {
      case .action(let action):
        if let key = action.key {
          result[key] = item
        }
      case .group(let group):
        if let key = group.key {
          result[key] = item
        }
      }
    }

    return result
  }

  var body: some View {
    Settings.Container(contentWidth: contentWidth) {
      Settings.Section(title: "", bottomDivider: true) {
        VStack(alignment: .center, spacing: 12) {
          // Breadcrumbs & Header
          HStack(spacing: 0) {
            let keyboardWidth = KeyboardLayout.totalWidth * maxKeyboardScale

            HStack(spacing: 4) {
              if !currentGroupPath.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                  HStack(spacing: 4) {
                    // Root breadcrumb
                    Button {
                      currentGroupPath.removeAll()
                    } label: {
                      Image(systemName: "house.fill")
                    }

                    // Path breadcrumbs
                    ForEach(0..<currentGroupPath.count, id: \.self) { index in
                      Text(">")
                        .foregroundColor(.secondary)

                      let id = currentGroupPath[index]
                      let name = getGroupName(for: id)
                      let isLast = index == currentGroupPath.count - 1

                      if isLast {
                        // Current location - show as bold text, not a button
                        Text(name)
                          .fontWeight(.bold)
                      } else {
                        Button {
                          currentGroupPath = Array(
                            (currentGroupPath as [UUID]).prefix(index + 1)
                          )
                        } label: {
                          Text(name)
                        }
                      }
                    }
                  }
                }

                Spacer()

                // Edit Current Group Button
                Button {
                  editingGroupWrapper = GroupWrapper(group: currentGroup)
                } label: {
                  Image(systemName: "gearshape")
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Edit Group Settings")
              } else {
                // Invisible button to maintain consistent height with breadcrumb view
                Button {
                } label: {
                  Image(systemName: "house.fill")
                }
                .opacity(0)
                .disabled(true)

                Spacer()
              }
            }
            .frame(width: keyboardWidth)
          }
          .frame(height: 24)

          KeyboardLayoutView(
            bindings: bindings,
            isEditable: false,
            shiftHeld: shiftHeld || stickyShiftMode,
            scale: maxKeyboardScale,
            onKeySelected: { key in
                if key == "shift" || key == "shift_r" {
                  stickyShiftMode.toggle()
                  return
                }

                // Determine if we're in shift mode
                let isShiftActive = shiftHeld || stickyShiftMode

                // If shift is active, persist it (sticky mode)
                if isShiftActive {
                  stickyShiftMode = true
                }

                // If shift is held, use the shifted key for lookup and creation
                let lookupKey =
                  isShiftActive ? KeyboardLayout.shiftedKey(for: key) : key

                if let existing = bindings[lookupKey] {
                  switch existing {
                  case .action(let action):
                    editingItem = EditorWrapper(
                      item: .action(action),
                      keyName: lookupKey,
                      isNew: false
                    )
                  case .group(let group):
                    // Direct navigation into group
                    currentGroupPath.append(group.uiid)
                  }
                } else {
                  // Default to empty application action
                  editingItem = EditorWrapper(
                    item: .action(
                      Action(key: lookupKey, type: .application, value: "")
                    ),
                    keyName: lookupKey,
                    isNew: true
                  )
                }
              }
            )

          Text("Click any key to configure")
            .font(.body)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 24)
        }
      }
    }
    .sheet(
      item: $editingItem,
      onDismiss: {
        stickyShiftMode = false
      }
    ) { wrapper in
      UnifiedEditorView(
        item: Binding(
          get: { wrapper.item },
          set: { editingItem?.item = $0 }
        ),
        keyName: wrapper.keyName,
        isNew: wrapper.isNew,
        onSave: { updatedItem in
          saveItem(updatedItem)
          editingItem = nil
        },
        onDelete: { itemToDelete in
          deleteItem(itemToDelete)
          editingItem = nil
        },
        onOpenLayout: { updatedItem in
          if case .group(let group) = updatedItem {
            currentGroupPath.append(group.uiid)
            editingItem = nil
          }
        }
      )
    }
    .sheet(
      item: $editingGroupWrapper,
      onDismiss: {
        stickyShiftMode = false
      }
    ) { wrapper in
      GroupEditorView(
        group: Binding(
          get: { wrapper.group },
          set: { editingGroupWrapper?.group = $0 }
        ),
        onSave: {
          if let group = editingGroupWrapper?.group {
            saveGroup(group)
          }
          editingGroupWrapper = nil
        },
        onDelete: {
          if let group = editingGroupWrapper?.group {
            deleteGroup(group)
            // If we deleted the current group, pop back
            if !currentGroupPath.isEmpty {
              currentGroupPath.removeLast()
            }
          }
          editingGroupWrapper = nil
        },
        onOpenLayout: {
          editingGroupWrapper = nil
        }
      )
    }
    .onAppear {
      monitor = NSEvent.addLocalMonitorForEvents(
        matching: .flagsChanged
      ) { event in
        let wasShiftHeld = shiftHeld
        let isShiftHeld = event.modifierFlags.contains(.shift)
        shiftHeld = isShiftHeld

        // If physical shift was released while in sticky mode, exit sticky mode
        // BUT only if we're not currently editing (keep shift while editor is open)
        if wasShiftHeld && !isShiftHeld && stickyShiftMode && editingItem == nil {
          stickyShiftMode = false
        }
        return event
      }
    }
    .onDisappear {
      if let monitor = monitor {
        NSEvent.removeMonitor(monitor)
      }
      monitor = nil
      // Reset to root when closing settings
      currentGroupPath.removeAll()
      stickyShiftMode = false
    }
  }

  private var keyboardMaxHeight: CGFloat {
    let rows = CGFloat(KeyboardLayout.rows.count)
    let scaledKeySize = KeyboardLayout.keySize * maxKeyboardScale
    let scaledRowSpacing = KeyboardLayout.rowSpacing * maxKeyboardScale
    let keyboardHeight = (scaledKeySize * rows) + (scaledRowSpacing * (rows - 1))
    // Add padding (8px for .padding(.vertical, 4)) + 32px for the overlapping text
    return ceil(keyboardHeight) + 40
  }

  private func saveItem(_ item: ActionOrGroup) {
    var group = currentGroup
    let newActions = group.actions.filter { existing in
      // Use UUID match if updating same item, OR Key match if replacing/colliding
      existing.uiid != item.uiid && existing.key != item.key
    }
    group.actions = newActions + [item]

    updateConfig(with: group)
  }

  private func deleteItem(_ item: ActionOrGroup) {
    var group = currentGroup
    let newActions = group.actions.filter { existing in
      existing.uiid != item.uiid
    }
    group.actions = newActions

    updateConfig(with: group)
  }

  private func saveGroup(_ group: KeyGroup) {
    updateConfig(with: group)
  }

  private func deleteGroup(_ group: KeyGroup) {
    if currentGroupPath.isEmpty {
      return
    }

    // Find parent
    let parentId = currentGroupPath.dropLast().last
    let parent = parentId != nil ? config.root.find(id: parentId!) : config.root

    if var p = parent {
      p.actions.removeAll { $0.uiid == group.uiid }
      updateConfig(with: p)
    }
  }

  private func updateConfig(with modifiedGroup: KeyGroup) {
    if currentGroupPath.isEmpty {
      config.root = modifiedGroup
    } else {
      var root = config.root
      if root.update(group: modifiedGroup) {
        config.root = root
      }
    }
  }

  private func getGroupName(for id: UUID) -> String {
    if let group = config.root.find(id: id) {
      return group.displayName
    }
    return "Unknown"
  }
}

#Preview {
  let config = UserConfig()
  return KeyboardPane()
    .environmentObject(config)
}
