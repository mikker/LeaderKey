import AppKit
import Combine
import Defaults
import KeyboardShortcuts
import ObjectiveC
import SwiftUI
import SymbolPicker
import UniformTypeIdentifiers

// An ultra-smooth, virtualized AppKit editor using NSOutlineView.
// Keeps file-format JSON unchanged by converting the tree to/from
// our existing Action/Group structs.

struct ConfigOutlineEditorView: NSViewRepresentable {
  @Binding var root: Group
  var onChange: ((Group) -> Void)? = nil
  @EnvironmentObject private var userConfig: UserConfig

  func makeNSView(context: Context) -> NSScrollView {
    let controller = OutlineController()
    controller.onChange = { updatedRoot in
      onChange?(updatedRoot)
      root = updatedRoot
    }
    controller.userConfig = userConfig
    context.coordinator.controller = controller

    let scroll = NSScrollView()
    scroll.hasVerticalScroller = true
    scroll.hasHorizontalScroller = false
    scroll.drawsBackground = true
    scroll.backgroundColor = .windowBackgroundColor
    controller.outline.backgroundColor = .windowBackgroundColor
    scroll.documentView = controller.outline
    controller.render(root: root)
    return scroll
  }

  func updateNSView(_ nsView: NSScrollView, context: Context) {
    context.coordinator.controller?.userConfig = userConfig
    context.coordinator.controller?.render(root: root)
  }

  func makeCoordinator() -> Coordinator { Coordinator() }
  class Coordinator { fileprivate var controller: OutlineController? }
}

// MARK: - Controller

private class OutlineController: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
  let outline = NSOutlineView()
  private let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("main"))
  private let actionID = NSUserInterfaceItemIdentifier("ActionCell")
  private let groupID = NSUserInterfaceItemIdentifier("GroupCell")
  private var rootNode: EditorNode = EditorNode.group(Group(key: nil, actions: []))
  var onChange: ((Group) -> Void)?
  var userConfig: UserConfig? {
    didSet {
      guard userConfig !== oldValue else { return }
      validationCancellable = userConfig?
        .$validationErrors
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in
          self?.applyValidationErrors()
        }
    }
  }
  private var observers: [NSObjectProtocol] = []
  private var didApplyInitialExpansion = false
  private let expandedDefaultsKey = "ConfigOutlineEditor.ExpandedIndexPaths"
  private let dragType = NSPasteboard.PasteboardType("com.leaderkey.node")
  private var lastRenderedRoot: Group?
  private var validationCancellable: AnyCancellable?
  /// Flags the next render call to skip a full reload because we already mutated `rootNode` locally.
  private var skipNextRender = false

  override init() {
    super.init()
    outline.rowHeight = 36
    outline.headerView = nil
    outline.usesAlternatingRowBackgroundColors = false
    outline.style = .sourceList
    outline.allowsColumnReordering = false
    outline.allowsMultipleSelection = false
    outline.intercellSpacing = NSSize(width: 0, height: 4)  // add spacing between rows
    outline.addTableColumn(column)
    outline.outlineTableColumn = column
    outline.delegate = self
    outline.dataSource = self
    outline.registerForDraggedTypes([dragType])
    outline.setDraggingSourceOperationMask(.move, forLocal: true)

    // Expand/Collapse all via notifications from SwiftUI container
    let nc = NotificationCenter.default
    observers.append(
      nc.addObserver(forName: .lkExpandAll, object: nil, queue: .main) { [weak self] _ in
        guard let self else { return }
        self.expandAll()
        self.saveCurrentExpandedState()
      })
    observers.append(
      nc.addObserver(forName: .lkCollapseAll, object: nil, queue: .main) { [weak self] _ in
        guard let self else { return }
        self.collapseAll()
        self.saveCurrentExpandedState()
      })
    observers.append(
      nc.addObserver(forName: .lkSortAZ, object: nil, queue: .main) { [weak self] _ in
        self?.sortAll()
      })
  }

  deinit {
    for o in observers {
      NotificationCenter.default.removeObserver(o)
    }
  }

  func render(root: Group) {
    if skipNextRender {
      lastRenderedRoot = root
      skipNextRender = false
      applyValidationErrors()
      return
    }

    if let last = lastRenderedRoot, last == root { return }
    // Capture current expansions by IDs for stability across reorder/sort
    let expandedIDs = collectExpandedIDs()
    // Also load persisted paths (for fresh launches)
    let savedPaths = loadExpandedState() ?? Set<String>()

    // Save scroll position before reload
    let scrollPosition = outline.enclosingScrollView?.documentVisibleRect.origin ?? .zero

    rootNode = EditorNode.from(group: root)
    outline.reloadData()

    if !savedPaths.isEmpty {
      restoreExpandedState(savedPaths)
    } else if !expandedIDs.isEmpty {
      restoreExpandedByIDs(expandedIDs)
    } else if !didApplyInitialExpansion {
      outline.expandItem(nil, expandChildren: true)
    }
    didApplyInitialExpansion = true
    lastRenderedRoot = root

    // Restore scroll position after reload
    DispatchQueue.main.async {
      self.outline.enclosingScrollView?.documentView?.scroll(scrollPosition)
      self.applyValidationErrors()
    }
  }

  // MARK: DataSource
  func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
    let node = (item as? EditorNode) ?? rootNode
    return node.children.count
  }

  func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
    guard let node = item as? EditorNode else { return false }
    return node.isGroup
  }

  func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
    let node = (item as? EditorNode) ?? rootNode
    return node.children[index]
  }

  // MARK: Delegate
  func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any)
    -> NSView?
  {
    guard let node = item as? EditorNode else { return nil }

    if node.isGroup {
      let cell =
        outlineView.makeView(withIdentifier: groupID, owner: self) as? GroupCellView
        ?? GroupCellView(identifier: groupID)
      let path = indexPath(for: node) ?? []
      cell.configure(
        node: node,
        validationError: userConfig?.validationError(at: path),
        onChange: { [weak self] payload in
          guard let self = self else { return }
          node.apply(payload)
          self.propagateRootChange()
        },
        onDelete: { [weak self] in
          guard let self = self else { return }
          node.deleteFromParent()
          outlineView.reloadData()
          self.propagateRootChange()
        },
        onDuplicate: { [weak self] in
          guard let self = self else { return }
          node.duplicateInParent()
          outlineView.reloadData()
          self.propagateRootChange()
        },
        onAddAction: { [weak self] in
          guard let self else { return }
          node.children.append(
            EditorNode.action(Action(key: "", type: .application, value: ""), parent: node))
          outlineView.reloadData()
          outlineView.expandItem(node)
          self.saveCurrentExpandedState()
          self.propagateRootChange()
        },
        onAddGroup: { [weak self] in
          guard let self else { return }
          node.children.append(EditorNode.group(Group(key: "", actions: []), parent: node))
          outlineView.reloadData()
          outlineView.expandItem(node)
          self.saveCurrentExpandedState()
          self.propagateRootChange()
        })
      return cell
    } else {
      let cell =
        outlineView.makeView(withIdentifier: actionID, owner: self) as? ActionCellView
        ?? ActionCellView(identifier: actionID)
      let path = indexPath(for: node) ?? []
      cell.configure(
        node: node,
        validationError: userConfig?.validationError(at: path),
        onChange: { [weak self] payload in
          guard let self = self else { return }
          node.apply(payload)
          self.propagateRootChange()
        },
        onDelete: { [weak self] in
          guard let self = self else { return }
          node.deleteFromParent()
          outlineView.reloadData()
          self.propagateRootChange()
        },
        onDuplicate: { [weak self] in
          guard let self = self else { return }
          node.duplicateInParent()
          outlineView.reloadData()
          self.propagateRootChange()
        })
      return cell
    }
  }

  func outlineView(_ outlineView: NSOutlineView, shouldEdit tableColumn: NSTableColumn?, item: Any)
    -> Bool
  {
    // Allow text fields inside cells to begin editing
    return true
  }

  // MARK: Expand/Collapse helpers
  private func expandAll() {
    outline.expandItem(nil, expandChildren: true)
  }

  private func collapseAll() {
    outline.collapseItem(nil, collapseChildren: true)
  }

  /// Mirrors the latest validation state into the visible outline row views.
  private func applyValidationErrors() {
    guard let userConfig else { return }

    let rows = outline.numberOfRows
    guard rows > 0 else { return }

    for row in 0..<rows {
      guard let node = outline.item(atRow: row) as? EditorNode else { continue }
      let path = indexPath(for: node) ?? []
      let validation = userConfig.validationError(at: path)

      guard let view = outline.view(atColumn: 0, row: row, makeIfNecessary: false) else {
        continue
      }

      if let actionCell = view as? ActionCellView {
        actionCell.applyValidation(validation)
      } else if let groupCell = view as? GroupCellView {
        groupCell.applyValidation(validation)
      }
    }
  }

  private func propagateRootChange() {
    // The SwiftUI binding will call back into `render` immediately; skip that pass so the outline keeps its current expansion state.
    skipNextRender = true
    onChange?(rootNode.toGroup())
  }

  // MARK: Persisted expansion state
  private func indexPath(for node: EditorNode) -> [Int]? {
    var path: [Int] = []
    var current: EditorNode? = node
    while let n = current, let p = n.parent {
      guard let idx = p.children.firstIndex(where: { $0 === n }) else { return nil }
      path.insert(idx, at: 0)
      current = p
    }
    // If current has no parent, n is root; paths are from root's children
    return path
  }

  private func node(at path: [Int]) -> EditorNode? {
    var node: EditorNode = rootNode
    var cursor = path[...]
    while let first = cursor.first {
      guard first >= 0 && first < node.children.count else { return nil }
      node = node.children[first]
      cursor = cursor.dropFirst()
    }
    return node
  }

  private func encode(path: [Int]) -> String { path.map(String.init).joined(separator: ".") }
  private func decode(path: String) -> [Int] { path.split(separator: ".").compactMap { Int($0) } }

  private func collectExpandedPaths() -> Set<String> {
    var set: Set<String> = []
    func walk(node: EditorNode, path: [Int]) {
      if node.isGroup && outline.isItemExpanded(node) {
        set.insert(encode(path: path))
      }
      for (i, child) in node.children.enumerated() {
        walk(node: child, path: path + [i])
      }
    }
    for (i, child) in rootNode.children.enumerated() { walk(node: child, path: [i]) }
    return set
  }

  private func collectExpandedIDs() -> Set<UUID> {
    var set: Set<UUID> = []
    func walk(node: EditorNode) {
      if node.isGroup && outline.isItemExpanded(node) { set.insert(node.id) }
      for child in node.children { walk(node: child) }
    }
    walk(node: rootNode)
    return set
  }

  private func saveCurrentExpandedState() {
    let set = collectExpandedPaths()
    UserDefaults.standard.set(Array(set), forKey: expandedDefaultsKey)
  }

  private func loadExpandedState() -> Set<String>? {
    if let arr = UserDefaults.standard.array(forKey: expandedDefaultsKey) as? [String] {
      return Set(arr)
    }
    return nil
  }

  private func restoreExpandedState(_ saved: Set<String>) {
    // After reload, items are collapsed; just expand saved nodes.
    for key in saved.sorted() {  // deterministic order
      let path = decode(path: key)
      if let n = node(at: path) { outline.expandItem(n, expandChildren: false) }
    }
  }

  private func restoreExpandedByIDs(_ ids: Set<UUID>) {
    func walk(node: EditorNode) {
      if ids.contains(node.id) { outline.expandItem(node, expandChildren: false) }
      for child in node.children { walk(node: child) }
    }
    walk(node: rootNode)
  }

  // MARK: NSOutlineViewDelegate expansion tracking
  func outlineView(_ outlineView: NSOutlineView, shouldExpandItem item: Any) -> Bool {
    defer { saveCurrentExpandedState() }
    return true
  }

  func outlineView(_ outlineView: NSOutlineView, shouldCollapseItem item: Any) -> Bool {
    defer { saveCurrentExpandedState() }
    return true
  }

  // MARK: Drag & Drop reordering
  func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any)
    -> NSPasteboardWriting?
  {
    guard let node = item as? EditorNode else { return nil }
    let pb = NSPasteboardItem()
    pb.setString(node.id.uuidString, forType: dragType)
    return pb
  }

  func outlineView(
    _ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?,
    proposedChildIndex index: Int
  ) -> NSDragOperation {
    // Be permissive; we will normalize the target in acceptDrop
    return .move
  }

  func outlineView(
    _ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex: Int
  ) -> Bool {
    guard let str = info.draggingPasteboard.string(forType: dragType),
      let dragged = findNode(by: str)
    else { return false }

    // Normalize drop target: drop into groups; otherwise drop next to the leaf within its parent
    var targetParent: EditorNode
    var insertIndex = childIndex
    if let target = item as? EditorNode {
      if target.isGroup {
        targetParent = target
        if insertIndex == NSOutlineViewDropOnItemIndex { insertIndex = targetParent.children.count }
      } else {
        targetParent = target.parent ?? rootNode
        if insertIndex == NSOutlineViewDropOnItemIndex {
          // Dropped "on" a leaf; place after it
          insertIndex =
            (targetParent.children.firstIndex(where: { $0 === target })
              ?? targetParent.children.count) + 1
        }
      }
    } else {
      targetParent = rootNode
      if insertIndex == NSOutlineViewDropOnItemIndex { insertIndex = targetParent.children.count }
    }

    // Snapshot expansion state
    let snapshotIDs = collectExpandedIDs()

    // Remove from old parent
    guard let oldParent = dragged.parent,
      let oldIndex = oldParent.children.firstIndex(where: { $0 === dragged })
    else { return false }

    // Prevent moving a node into its own descendant
    var ancestor: EditorNode? = targetParent
    while let a = ancestor {
      if a === dragged { return false }
      ancestor = a.parent
    }
    oldParent.children.remove(at: oldIndex)

    // Adjust index if moving within same parent and removing an earlier index
    if oldParent === targetParent && oldIndex < insertIndex { insertIndex -= 1 }

    // Insert at target
    dragged.parent = targetParent
    insertIndex = max(0, min(targetParent.children.count, insertIndex))
    targetParent.children.insert(dragged, at: insertIndex)

    outline.reloadData()
    restoreExpandedByIDs(snapshotIDs)
    saveCurrentExpandedState()
    propagateRootChange()
    return true
  }

  private func findNode(by idString: String) -> EditorNode? {
    func walk(_ node: EditorNode) -> EditorNode? {
      if node.id.uuidString == idString { return node }
      for child in node.children { if let f = walk(child) { return f } }
      return nil
    }
    return walk(rootNode)
  }

  // MARK: Sort A→Z
  private func sortAll() {
    let expansionIDs = collectExpandedIDs()

    func sortRec(_ node: EditorNode) {
      for child in node.children { sortRec(child) }
      node.children.sort(by: { a, b in
        let ka = keyString(for: a)
        let kb = keyString(for: b)
        if ka.isEmpty != kb.isEmpty { return !ka.isEmpty }  // non-empty first
        return ka.localizedCaseInsensitiveCompare(kb) == .orderedAscending
      })
    }
    sortRec(rootNode)
    outline.reloadData()
    restoreExpandedByIDs(expansionIDs)
    saveCurrentExpandedState()
    propagateRootChange()
  }

  private func keyString(for node: EditorNode) -> String {
    switch node.kind {
    case .action(let a): return a.key ?? ""
    case .group(let g): return g.key ?? ""
    }
  }
}

// MARK: - Row Views

private enum EditorPayload {
  case action(Action)
  case group(Group)
}

private class ActionCellView: NSTableCellView, NSWindowDelegate {
  private enum Layout {
    static let keyWidth: CGFloat = 28
    static let typeWidth: CGFloat = 110
    static let chooserWidth: CGFloat = 70
    static let valueWidth: CGFloat = 360
    static let labelWidth: CGFloat = 160
    static let iconButtonWidth: CGFloat = 28
    static let iconSize: CGFloat = 24
  }
  private var keyButton = NSButton()
  private var typePopup = NSPopUpButton()
  private var iconButton = NSButton()
  private var valueStack = NSStackView()
  private var labelButton = NSButton()
  private var moreBtn = NSButton()

  private var onChange: ((EditorPayload) -> Void)?
  private var onDelete: (() -> Void)?
  private var onDuplicate: (() -> Void)?
  private var node: EditorNode?
  private var currentValidationError: ValidationErrorType?
  private var symbolWindow: NSWindow?
  private weak var symbolParent: NSWindow?

  convenience init(identifier: NSUserInterfaceItemIdentifier) {
    self.init(frame: .zero)
    self.identifier = identifier
    setup()
  }

  private func setup() {
    wantsLayer = true

    let container = NSStackView()
    container.orientation = .horizontal
    container.spacing = 8
    container.translatesAutoresizingMaskIntoConstraints = false

    keyButton.bezelStyle = .rounded
    keyButton.controlSize = .regular
    keyButton.widthAnchor.constraint(equalToConstant: Layout.keyWidth).isActive = true
    keyButton.wantsLayer = true
    typePopup.addItems(withTitles: ["Application", "URL", "Command", "Folder"])
    typePopup.controlSize = .regular
    typePopup.widthAnchor.constraint(equalToConstant: Layout.typeWidth).isActive = true
    valueStack.orientation = .horizontal
    valueStack.spacing = 6
    labelButton.bezelStyle = .rounded
    labelButton.controlSize = .regular
    do {  // Ensure minimum width to prevent text from being cut off
      let minConstraint = labelButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 60)
      minConstraint.priority = .required
      minConstraint.isActive = true
    }
    moreBtn.bezelStyle = .rounded
    moreBtn.controlSize = .regular
    moreBtn.image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: nil)
    moreBtn.widthAnchor.constraint(equalToConstant: 30).isActive = true
    iconButton.bezelStyle = .rounded
    iconButton.controlSize = .regular
    iconButton.imagePosition = .imageOnly
    iconButton.imageScaling = .scaleProportionallyDown
    iconButton.widthAnchor.constraint(equalToConstant: Layout.iconButtonWidth).isActive = true

    for view in [keyButton, typePopup, iconButton, labelButton, moreBtn] {
      view.makeRigid()
    }

    valueStack.makeFlex()

    for view in [keyButton, typePopup, iconButton, valueStack, labelButton, moreBtn] {
      container.addArrangedSubview(view)
    }
    addSubview(container)
    NSLayoutConstraint.activate([
      // Leave a small drag gutter so drags can start even when row is full of controls
      container.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
      container.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
      container.topAnchor.constraint(equalTo: topAnchor, constant: 2),
      container.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
    ])

    // Actions
    keyButton.targetClosure { [weak self] in self?.beginKeyCapture() }
    typePopup.targetClosure { [weak self] in self?.propagate() }
    iconButton.targetClosure { [weak self] in self?.showIconMenu(anchor: self?.iconButton) }
    labelButton.targetClosure { [weak self] in
      guard let self else { return }
      self.promptText(title: "Label", initial: self.currentAction()?.label ?? "") { text in
        guard var a = self.currentAction() else { return }
        a.label = text.isEmpty ? nil : text
        self.onChange?(.action(a))
        self.updateButtons(for: a)
      }
    }
    moreBtn.targetClosure { [weak self] in self?.showMoreMenu(anchor: self?.moreBtn) }
  }

  func configure(
    node: EditorNode, validationError: ValidationErrorType? = nil,
    onChange: @escaping (EditorPayload) -> Void, onDelete: @escaping () -> Void,
    onDuplicate: @escaping () -> Void
  ) {
    self.node = node
    self.currentValidationError = validationError
    self.onChange = onChange
    self.onDelete = onDelete
    self.onDuplicate = onDuplicate
    guard case .action(let action) = node.kind else { return }

    updateButtons(for: action)
    typePopup.selectItem(at: Self.index(for: action.type))
    rebuildValue(for: action)
    updateIcon(for: action)
    updateValidationStyle(validationError)
  }

  func applyValidation(_ error: ValidationErrorType?) {
    currentValidationError = error
    updateValidationStyle(error)
  }

  private func showMoreMenu(anchor: NSView?) {
    ConfigEditorUI.presentMoreMenu(
      anchor: anchor,
      onDuplicate: { self.onDuplicate?() },
      onDelete: { self.onDelete?() }
    )
  }

  private func updateButtons(for action: Action) {
    keyButton.title =
      (action.key?.isEmpty ?? true)
      ? "Key" : (KeyMaps.glyph(for: action.key ?? "") ?? action.key ?? "Key")
    let isPlaceholder = (action.label?.isEmpty ?? true)
    ConfigEditorUI.setButtonTitle(
      labelButton,
      text: isPlaceholder ? "Label" : (action.label ?? "Label"),
      placeholder: isPlaceholder)
  }

  private func updateValidationStyle(_ error: ValidationErrorType?) {
    updateRowBackground(error)

    // Don't override blue background when listening for keys
    guard keyMonitor == nil else { return }

    if error != nil {
      // Add subtle red border to indicate validation error
      keyButton.layer?.borderColor = NSColor.systemRed.cgColor
      keyButton.layer?.borderWidth = 1.0
      keyButton.layer?.cornerRadius = 4.0
    } else {
      // Remove validation error styling
      keyButton.layer?.borderColor = NSColor.clear.cgColor
      keyButton.layer?.borderWidth = 0.0
    }
  }

  private func updateRowBackground(_ error: ValidationErrorType?) {
    let color: NSColor?
    if error != nil {
      color = NSColor.systemRed.withAlphaComponent(0.08)
    } else {
      color = nil
    }
    layer?.backgroundColor = color?.cgColor
  }

  private func rebuildValue(for action: Action) {
    while let v = valueStack.arrangedSubviews.first { v.removeFromSuperview() }
    let descriptor = ValueDescriptor.forAction(action)
    switch descriptor.kind {
    case .picker(let picker):
      let choose = Self.chooseButton(
        title: picker.buttonTitle,
        chooseDir: picker.chooseDirectories,
        allowedTypes: picker.allowedTypes,
        width: Layout.chooserWidth
      ) { [weak self] url in
        guard var a = self?.currentAction() else { return }
        a.value = url.path
        self?.onChange?(.action(a))
        self?.rebuildValue(for: a)
        self?.updateIcon(for: a)
      }
      let label = Self.valueLabel(text: descriptor.display)
      for v in [choose, label] { valueStack.addArrangedSubview(v) }
    case .prompt(let promptTitle):
      let edit = Self.editButton(width: Layout.chooserWidth)
      edit.targetClosure { [weak self] in
        self?.promptText(title: promptTitle, initial: action.value) { text in
          guard var a = self?.currentAction() else { return }
          a.value = text
          self?.onChange?(.action(a))
          self?.rebuildValue(for: a)
        }
      }
      let preview = Self.valueLabel(text: descriptor.display)
      for v in [edit, preview] { valueStack.addArrangedSubview(v) }
    }
  }

  private func propagate() {
    guard let action = currentAction() else { return }
    onChange?(.action(action))
    rebuildValue(for: action)  // ensure value UI matches type after change
  }

  private struct ValueDescriptor {
    struct PickerConfig {
      let buttonTitle: String
      let chooseDirectories: Bool
      let allowedTypes: [UTType]?
    }
    enum Kind {
      case picker(PickerConfig)
      case prompt(String)
    }

    let kind: Kind
    let display: String

    static func forAction(_ action: Action) -> ValueDescriptor {
      switch action.type {
      case .application:
        let config = PickerConfig(
          buttonTitle: "Choose…",
          chooseDirectories: false,
          allowedTypes: [.application, .applicationBundle]
        )
        return ValueDescriptor(kind: .picker(config), display: action.value)
      case .folder:
        let config = PickerConfig(
          buttonTitle: "Choose…",
          chooseDirectories: true,
          allowedTypes: nil
        )
        return ValueDescriptor(kind: .picker(config), display: action.value)
      case .command:
        return ValueDescriptor(kind: .prompt("Command"), display: action.value)
      case .url:
        return ValueDescriptor(kind: .prompt("URL"), display: action.value)
      default:
        return ValueDescriptor(kind: .prompt("Value"), display: action.value)
      }
    }
  }

  private static func valueLabel(text: String) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.lineBreakMode = .byTruncatingMiddle
    label.controlSize = .regular
    label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    let constraint = label.widthAnchor.constraint(lessThanOrEqualToConstant: Layout.valueWidth)
    constraint.priority = .defaultHigh
    constraint.isActive = true
    return label
  }

  private static func editButton(width: CGFloat) -> NSButton {
    let button = NSButton(title: "Edit…", target: nil, action: nil)
    button.controlSize = .regular
    button.bezelStyle = .rounded
    button.widthAnchor.constraint(equalToConstant: width).isActive = true
    return button
  }

  private func currentAction() -> Action? {
    guard case .action(var a) = node?.kind else { return nil }
    let keyTitle = keyButton.title
    a.key = (keyTitle == "Key" || keyTitle.isEmpty) ? nil : keyTitle
    a.type = Self.type(for: typePopup.indexOfSelectedItem)
    let labelTitle = labelButton.title
    a.label = (labelTitle == "Label" || labelTitle.isEmpty) ? nil : labelTitle
    return a
  }

  private static func chooseButton(
    title: String, chooseDir: Bool, allowedTypes: [UTType]?, width: CGFloat,
    picked: @escaping (URL) -> Void
  ) -> NSButton {
    let b = NSButton(title: title, target: nil, action: nil)
    b.controlSize = .regular
    b.bezelStyle = .rounded
    b.widthAnchor.constraint(equalToConstant: width).isActive = true
    b.targetClosure {
      let panel = NSOpenPanel()
      panel.allowsMultipleSelection = false
      let allowsAppBundles = allowsAppBundles(allowedTypes)
      panel.treatsFilePackagesAsDirectories = false
      panel.canChooseDirectories = chooseDir || allowsAppBundles
      panel.canChooseFiles = !chooseDir || allowsAppBundles
      if let types = allowedTypes { panel.allowedContentTypes = types }
      panel.directoryURL =
        chooseDir
        ? FileManager.default.homeDirectoryForCurrentUser : URL(fileURLWithPath: "/Applications")
      if panel.runModal() == .OK, let url = panel.url { picked(url) }
    }
    return b
  }

  private static func allowsAppBundles(_ types: [UTType]?) -> Bool {
    guard let types else { return false }
    return types.contains { type in
      type == .application || type == .applicationBundle
    }
  }

  private static func index(for type: Type) -> Int {
    switch type {
    case .application: return 0
    case .url: return 1
    case .command: return 2
    case .folder: return 3
    default: return 0
    }
  }
  private static func type(for idx: Int) -> Type {
    [Type.application, .url, .command, .folder][max(0, min(3, idx))]
  }

  private func promptText(title: String, initial: String, onOK: @escaping (String) -> Void) {
    let alert = NSAlert()
    alert.messageText = title
    alert.addButton(withTitle: "OK")
    alert.addButton(withTitle: "Cancel")
    let field = NSTextField(string: initial)
    field.frame = NSRect(x: 0, y: 0, width: 260, height: 22)
    alert.accessoryView = field
    // Focus and select all when the dialog opens
    alert.window.initialFirstResponder = field
    field.selectText(nil)
    let response = alert.runModal()
    if response == .alertFirstButtonReturn { onOK(field.stringValue) }
  }

  // MARK: Key capture logic (replicates SwiftUI KeyButton UX)
  private var keyMonitor: Any?
  private func beginKeyCapture() {
    guard keyMonitor == nil else { return }
    keyButton.title = ""

    // Change button to highlighted blue style
    keyButton.contentTintColor = NSColor.white
    keyButton.bezelColor = NSColor.systemBlue

    keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      guard let self = self else { return event }
      let handled = KeyCapture.handle(
        event: event,
        onSet: { self.endKeyCapture(set: $0) },
        onCancel: { self.endKeyCapture(set: nil) },
        onClear: { self.endKeyCapture(set: nil) }
      )
      return handled ? nil : event
    }
  }

  private func endKeyCapture(set char: String?) {
    if let monitor = keyMonitor {
      NSEvent.removeMonitor(monitor)
      keyMonitor = nil
    }

    // Reset button style
    keyButton.contentTintColor = nil
    keyButton.bezelColor = nil

    guard var a = currentAction() else {
      keyButton.title = "Key"
      return
    }
    let normalized = char?.isEmpty == true ? nil : char
    a.key = normalized
    onChange?(.action(a))
    updateButtons(for: a)

    // Restore validation styling if there was an error
    updateValidationStyle(currentValidationError)
  }

  // MARK: Icon helpers (action)
  private func showIconMenu(anchor: NSView?) {
    ConfigEditorUI.presentIconMenu(
      anchor: anchor,
      onPickAppIcon: { self.handlePickAppIcon() },
      onPickSymbol: { self.handlePickSymbol() },
      onPickCustomImage: { self.handlePickCustomImage() },
      onClear: { self.handleClearIcon() }
    )
  }

  @objc private func handlePickAppIcon() {
    guard var a = currentAction() else { return }
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.applicationBundle, .application]
    panel.canChooseFiles = true
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.directoryURL = URL(fileURLWithPath: "/Applications")
    if panel.runModal() == .OK {
      DispatchQueue.main.async {
        a.iconPath = panel.url?.path
        self.onChange?(.action(a))
        self.updateIcon(for: a)
      }
    }
  }

  @objc private func handlePickSymbol() {
    guard let anchor = iconButton as NSView? else { return }
    presentSymbolPickerSheet(
      anchor: anchor,
      initial: currentAction()?.iconPath,
      owner: self,
      getWindow: { self.symbolWindow },
      setWindow: { self.symbolWindow = $0 },
      getParent: { self.symbolParent },
      setParent: { self.symbolParent = $0 },
      onPicked: { [weak self] picked in
        guard let self, var a = self.currentAction() else { return }
        a.iconPath = picked?.isEmpty == true ? nil : picked
        self.onChange?(.action(a))
        self.updateIcon(for: a)
      }
    )
  }

  @objc private func handlePickCustomImage() {
    guard var a = currentAction() else { return }
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.png, .jpeg, .icns]
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
    panel.message = "Choose a custom icon image"
    if panel.runModal() == .OK {
      guard let path = panel.url?.path else { return }

      // Validate that the file can actually be loaded as an image
      guard NSImage(contentsOfFile: path) != nil else {
        let alert = NSAlert()
        alert.messageText = "Invalid Image File"
        alert.informativeText = "The selected file could not be loaded as an image. Please choose a valid PNG, JPEG, or ICNS file."
        alert.alertStyle = .warning
        alert.runModal()
        return
      }

      DispatchQueue.main.async {
        a.iconPath = path
        self.onChange?(.action(a))
        self.updateIcon(for: a)
      }
    }
  }

  @objc private func handleClearIcon() {
    guard var a = currentAction() else { return }
    DispatchQueue.main.async {
      a.iconPath = nil
      self.onChange?(.action(a))
      self.updateIcon(for: a)
    }
  }

  private func updateIcon(for action: Action) {
    iconButton.image = action.resolvedIcon()
  }

  // symbol picker presenting delegated to shared helper
}

private class GroupCellView: NSTableCellView, NSWindowDelegate {
  private enum Layout {
    static let keyWidth: CGFloat = 28
    static let labelWidth: CGFloat = 160
    static let iconButtonWidth: CGFloat = 28
    static let globalShortcutWidth: CGFloat = 120
  }
  private var keyButton = NSButton()
  private var iconButton = NSButton()
  private var labelButton = NSButton()
  private var globalShortcutView: NSView?
  private var addActionBtn = NSButton()
  private var addGroupBtn = NSButton()
  private var moreBtn = NSButton()

  private var node: EditorNode?
  private var onChange: ((EditorPayload) -> Void)?
  private var onDelete: (() -> Void)?
  private var onDuplicate: (() -> Void)?
  private var currentValidationError: ValidationErrorType?
  private var onAddAction: (() -> Void)?
  private var onAddGroup: (() -> Void)?
  private var symbolWindow: NSWindow?
  private weak var symbolParent: NSWindow?

  convenience init(identifier: NSUserInterfaceItemIdentifier) {
    self.init(frame: .zero)
    self.identifier = identifier
    setup()
  }

  private func setup() {
    let container = NSStackView()
    container.orientation = .horizontal
    container.spacing = 8
    container.translatesAutoresizingMaskIntoConstraints = false
    keyButton.bezelStyle = .rounded
    keyButton.controlSize = .regular
    keyButton.widthAnchor.constraint(equalToConstant: Layout.keyWidth).isActive = true
    keyButton.wantsLayer = true
    iconButton.bezelStyle = .rounded
    iconButton.controlSize = .regular
    iconButton.imagePosition = .imageOnly
    iconButton.imageScaling = .scaleProportionallyDown
    iconButton.widthAnchor.constraint(equalToConstant: Layout.iconButtonWidth).isActive = true
    labelButton.bezelStyle = .rounded
    labelButton.controlSize = .regular

    addActionBtn.title = "+ Action"
    addActionBtn.bezelStyle = .rounded
    addActionBtn.controlSize = .regular
    addActionBtn.widthAnchor.constraint(greaterThanOrEqualToConstant: 80).isActive = true
    addGroupBtn.title = "+ Group"
    addGroupBtn.bezelStyle = .rounded
    addGroupBtn.controlSize = .regular
    addGroupBtn.widthAnchor.constraint(greaterThanOrEqualToConstant: 80).isActive = true
    moreBtn.bezelStyle = .rounded
    moreBtn.controlSize = .regular
    moreBtn.image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: nil)
    moreBtn.widthAnchor.constraint(equalToConstant: 30).isActive = true

    let spacer2 = NSView()

    let globalShortcutContainer = NSView()
    globalShortcutContainer.widthAnchor.constraint(
      equalToConstant: Layout.globalShortcutWidth
    ).isActive = true
    globalShortcutView = globalShortcutContainer

    for view in [
      keyButton, iconButton, addActionBtn, addGroupBtn, labelButton, moreBtn,
      globalShortcutContainer,
    ] {
      view.makeRigid()
    }

    spacer2.makeFlex()

    for v in [keyButton, iconButton] {
      container.addArrangedSubview(v)
    }
    container.addArrangedSubview(globalShortcutContainer)

    for v in [spacer2, addActionBtn, addGroupBtn, labelButton, moreBtn] {
      container.addArrangedSubview(v)
    }
    addSubview(container)
    NSLayoutConstraint.activate([
      container.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
      container.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
      container.topAnchor.constraint(equalTo: topAnchor, constant: 2),
      container.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
    ])

    keyButton.targetClosure { [weak self] in self?.beginKeyCapture() }
    iconButton.targetClosure { [weak self] in self?.showIconMenu(anchor: self?.iconButton) }
    labelButton.targetClosure { [weak self] in
      self?.prompt(title: "Label", initial: self?.currentGroup()?.label ?? "") { text in
        guard var g = self?.currentGroup() else { return }
        g.label = text.isEmpty ? nil : text
        self?.onChange?(.group(g))
        self?.updateButtons(for: g)
      }
    }
    addActionBtn.targetClosure { [weak self] in self?.onAddAction?() }
    addGroupBtn.targetClosure { [weak self] in self?.onAddGroup?() }
    moreBtn.targetClosure { [weak self] in self?.showMoreMenu(anchor: self?.moreBtn) }
  }

  func configure(
    node: EditorNode, validationError: ValidationErrorType? = nil,
    onChange: @escaping (EditorPayload) -> Void, onDelete: @escaping () -> Void,
    onDuplicate: @escaping () -> Void, onAddAction: @escaping () -> Void,
    onAddGroup: @escaping () -> Void
  ) {
    self.node = node
    self.currentValidationError = validationError
    self.onChange = onChange
    self.onDelete = onDelete
    self.onDuplicate = onDuplicate
    self.onAddAction = onAddAction
    self.onAddGroup = onAddGroup
    guard case .group(let group) = node.kind else { return }
    updateButtons(for: group)
    updateIcon(for: group)
    updateValidationStyle(validationError)
  }

  func applyValidation(_ error: ValidationErrorType?) {
    currentValidationError = error
    updateValidationStyle(error)
  }

  private func updateButtons(for group: Group) {
    keyButton.title =
      (group.key?.isEmpty ?? true)
      ? "Group Key" : (KeyMaps.glyph(for: group.key ?? "") ?? group.key ?? "Group Key")
    let isPlaceholder = (group.label?.isEmpty ?? true)
    ConfigEditorUI.setButtonTitle(
      labelButton,
      text: isPlaceholder ? "Label" : (group.label ?? "Label"),
      placeholder: isPlaceholder)
    updateGlobalShortcutView(for: group)
  }

  private func updateValidationStyle(_ error: ValidationErrorType?) {
    updateRowBackground(error)

    // Don't override blue background when listening for keys
    guard keyMonitor == nil else { return }

    if error != nil {
      // Add subtle red border to indicate validation error
      keyButton.layer?.borderColor = NSColor.systemRed.cgColor
      keyButton.layer?.borderWidth = 1.0
      keyButton.layer?.cornerRadius = 4.0
    } else {
      // Remove validation error styling
      keyButton.layer?.borderColor = NSColor.clear.cgColor
      keyButton.layer?.borderWidth = 0.0
    }
  }

  private func updateRowBackground(_ error: ValidationErrorType?) {
    let color: NSColor?
    if error != nil {
      color = NSColor.systemRed.withAlphaComponent(0.08)
    } else {
      color = nil
    }
    layer?.backgroundColor = color?.cgColor
  }

  private func updateGlobalShortcutView(for group: Group) {
    guard let container = globalShortcutView else { return }

    // Clear existing content
    container.subviews.removeAll()

    let isFirstLevel = node?.parent?.parent == nil  // First level groups are children of root
    let hasValidKey = group.key != nil && !group.key!.isEmpty

    if isFirstLevel && hasValidKey, let key = group.key {
      let recorder = KeyboardShortcuts.RecorderCocoa(for: KeyboardShortcuts.Name("group-\(key)")) {
        _ in
        // Update the groupShortcuts set when shortcut changes
        let shortcutName = KeyboardShortcuts.Name("group-\(key)")
        if KeyboardShortcuts.getShortcut(for: shortcutName) != nil {
          Defaults[.groupShortcuts].insert(key)
        } else {
          Defaults[.groupShortcuts].remove(key)
        }

        // Re-register global shortcuts
        (NSApplication.shared.delegate as! AppDelegate).registerGlobalShortcuts()
      }
      recorder.translatesAutoresizingMaskIntoConstraints = false
      container.addSubview(recorder)
      NSLayoutConstraint.activate([
        recorder.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        recorder.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        recorder.topAnchor.constraint(equalTo: container.topAnchor),
        recorder.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      ])
    }
  }

  private func currentGroup() -> Group? {
    if case .group(let g) = node?.kind { return g } else { return nil }
  }

  private func prompt(title: String, initial: String?, onOK: @escaping (String) -> Void) {
    let alert = NSAlert()
    alert.messageText = title
    alert.addButton(withTitle: "OK")
    alert.addButton(withTitle: "Cancel")
    let field = NSTextField(string: initial ?? "")
    field.frame = NSRect(x: 0, y: 0, width: 260, height: 22)
    alert.accessoryView = field
    // Focus and select all when the dialog opens
    alert.window.initialFirstResponder = field
    field.selectText(nil)
    if alert.runModal() == .alertFirstButtonReturn { onOK(field.stringValue) }
  }

  // MARK: Key capture (group)
  private var keyMonitor: Any?
  private func beginKeyCapture() {
    guard keyMonitor == nil else { return }
    keyButton.title = ""

    // Change button to highlighted blue style
    keyButton.contentTintColor = NSColor.white
    keyButton.bezelColor = NSColor.systemBlue

    keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      guard let self = self else { return event }
      let handled = KeyCapture.handle(
        event: event,
        onSet: { self.endKeyCapture(set: $0) },
        onCancel: { self.endKeyCapture(set: nil) },
        onClear: { self.endKeyCapture(set: nil) }
      )
      return handled ? nil : event
    }
  }

  private func endKeyCapture(set char: String?) {
    if let monitor = keyMonitor {
      NSEvent.removeMonitor(monitor)
      keyMonitor = nil
    }

    // Reset button style
    keyButton.contentTintColor = nil
    keyButton.bezelColor = nil

    guard var g = currentGroup() else {
      keyButton.title = "Group Key"
      return
    }

    let normalized = char?.isEmpty == true ? nil : char

    // If key changed and there was a global shortcut, remove it
    if let oldKey = g.key, !oldKey.isEmpty, normalized != oldKey {
      var shortcuts = Defaults[.groupShortcuts]
      shortcuts.remove(oldKey)
      Defaults[.groupShortcuts] = shortcuts
      KeyboardShortcuts.reset([KeyboardShortcuts.Name("group-\(oldKey)")])
    }

    g.key = normalized
    onChange?(.group(g))
    updateButtons(for: g)

    // Restore validation styling if there was an error
    updateValidationStyle(currentValidationError)

    // Re-register global shortcuts after key change
    let appDelegate = NSApp.delegate as? AppDelegate
    appDelegate?.registerGlobalShortcuts()
  }

  // MARK: Icon helpers (group)
  private func showIconMenu(anchor: NSView?) {
    ConfigEditorUI.presentIconMenu(
      anchor: anchor,
      onPickAppIcon: { self.handlePickAppIcon() },
      onPickSymbol: { self.handlePickSymbol() },
      onPickCustomImage: { self.handlePickCustomImage() },
      onClear: { self.handleClearIcon() }
    )
  }

  @objc private func handlePickAppIcon() {
    guard var g = currentGroup() else { return }
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.applicationBundle, .application]
    panel.canChooseFiles = true
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.directoryURL = URL(fileURLWithPath: "/Applications")
    if panel.runModal() == .OK {
      DispatchQueue.main.async {
        g.iconPath = panel.url?.path
        self.onChange?(.group(g))
        self.updateIcon(for: g)
      }
    }
  }

  @objc private func handlePickSymbol() {
    guard let anchor = iconButton as NSView? else { return }
    presentSymbolPickerSheet(
      anchor: anchor,
      initial: currentGroup()?.iconPath,
      owner: self,
      getWindow: { self.symbolWindow },
      setWindow: { self.symbolWindow = $0 },
      getParent: { self.symbolParent },
      setParent: { self.symbolParent = $0 },
      onPicked: { [weak self] picked in
        guard let self, var g = self.currentGroup() else { return }
        g.iconPath = picked?.isEmpty == true ? nil : picked
        self.onChange?(.group(g))
        self.updateIcon(for: g)
      }
    )
  }

  @objc private func handlePickCustomImage() {
    guard var g = currentGroup() else { return }
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.png, .jpeg, .icns]
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
    panel.message = "Choose a custom icon image"
    if panel.runModal() == .OK {
      guard let path = panel.url?.path else { return }

      // Validate that the file can actually be loaded as an image
      guard NSImage(contentsOfFile: path) != nil else {
        let alert = NSAlert()
        alert.messageText = "Invalid Image File"
        alert.informativeText = "The selected file could not be loaded as an image. Please choose a valid PNG, JPEG, or ICNS file."
        alert.alertStyle = .warning
        alert.runModal()
        return
      }

      DispatchQueue.main.async {
        g.iconPath = path
        self.onChange?(.group(g))
        self.updateIcon(for: g)
      }
    }
  }

  @objc private func handleClearIcon() {
    guard var g = currentGroup() else { return }
    DispatchQueue.main.async {
      g.iconPath = nil
      self.onChange?(.group(g))
      self.updateIcon(for: g)
    }
  }

  private func updateIcon(for group: Group) {
    iconButton.image = group.resolvedIcon()
  }

  private func showMoreMenu(anchor: NSView?) {
    ConfigEditorUI.presentMoreMenu(
      anchor: anchor,
      onDuplicate: { self.onDuplicate?() },
      onDelete: { self.onDelete?() }
    )
  }
}

// MARK: - Editor Node

private class EditorNode: NSObject {
  enum Kind {
    case action(Action)
    case group(Group)
  }
  var id = UUID()
  var kind: Kind
  weak var parent: EditorNode?
  var children: [EditorNode] = []

  var isGroup: Bool { if case .group = kind { return true } else { return false } }

  init(kind: Kind, parent: EditorNode? = nil) {
    self.kind = kind
    self.parent = parent
    super.init()
  }

  static func action(_ a: Action, parent: EditorNode?) -> EditorNode {
    EditorNode(kind: .action(a), parent: parent)
  }
  static func group(_ g: Group, parent: EditorNode? = nil) -> EditorNode {
    EditorNode(kind: .group(g), parent: parent)
  }

  static func from(group: Group, parent: EditorNode? = nil) -> EditorNode {
    let node = EditorNode.group(group, parent: parent)
    node.children = group.actions.map { child in
      switch child {
      case .action(let a):
        return EditorNode.action(a, parent: node)
      case .group(let g):
        return from(group: g, parent: node)
      }
    }
    return node
  }

  func toGroup() -> Group {
    switch kind {
    case .group(var g):
      g.actions = children.map { $0.toActionOrGroup() }
      return g
    case .action:
      // Root always a group
      return Group(key: nil, actions: children.map { $0.toActionOrGroup() })
    }
  }

  func toActionOrGroup() -> ActionOrGroup {
    switch kind {
    case .action(let a): return .action(a)
    case .group(var g):
      g.actions = children.map { $0.toActionOrGroup() }
      return .group(g)
    }
  }

  func apply(_ payload: EditorPayload) {
    switch (kind, payload) {
    case (.action, .action(let a)): kind = .action(a)
    case (.group, .group(let g)): kind = .group(g)
    default: break
    }
  }

  func deleteFromParent() {
    guard let p = parent else { return }
    if let idx = p.children.firstIndex(where: { $0 === self }) { p.children.remove(at: idx) }
  }

  func duplicateInParent() {
    guard let p = parent else { return }
    let copy = deepCopy(newParent: p)
    if let idx = p.children.firstIndex(where: { $0 === self }) { p.children.insert(copy, at: idx) }
  }

  private func deepCopy(newParent: EditorNode?) -> EditorNode {
    let copy = EditorNode(kind: kind, parent: newParent)
    copy.children = children.map { $0.deepCopy(newParent: copy) }
    return copy
  }
}

// MARK: - Target/Action helpers

private class ClosureTarget: NSObject {
  let handler: () -> Void
  init(_ handler: @escaping () -> Void) { self.handler = handler }
  @objc func go() { handler() }
}

extension NSControl {
  fileprivate func targetClosure(_ action: @escaping () -> Void) {
    let t = ClosureTarget(action)
    self.target = t
    self.action = #selector(ClosureTarget.go)
    objc_setAssociatedObject(
      self, Unmanaged.passUnretained(self).toOpaque(), t, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
  }
}

// Popover lifecycle cleanup
// No longer using popovers for symbol picking; presented as sheets/windows instead
// Small SwiftUI bridge around the package view so we can observe changes
private struct SymbolPickerBridge: View {
  @State var symbol: String?
  var onChange: (String?) -> Void
  var onClose: () -> Void

  init(initial: String?, onChange: @escaping (String?) -> Void, onClose: @escaping () -> Void) {
    _symbol = State(initialValue: initial)
    self.onChange = onChange
    self.onClose = onClose
  }

  var body: some View {
    VStack(spacing: 12) {
      SymbolPicker(
        symbol: Binding(
          get: { symbol },
          set: { newVal in
            symbol = newVal
            onChange(newVal)
          }
        ))
      HStack {
        Spacer()
        Button("Close") { onClose() }
          .keyboardShortcut(.cancelAction)
      }
    }
    .padding()
  }
}

// Shared presenter for the symbol picker sheet used by both cell types
private func presentSymbolPickerSheet(
  anchor: NSView,
  initial: String?,
  owner: NSWindowDelegate,
  getWindow: @escaping () -> NSWindow?,
  setWindow: @escaping (NSWindow?) -> Void,
  getParent: @escaping () -> NSWindow?,
  setParent: @escaping (NSWindow?) -> Void,
  onPicked: @escaping (String?) -> Void
) {
  if let parent = getParent(), let win = getWindow() { parent.endSheet(win) }
  setWindow(nil)
  setParent(nil)

  let host = NSHostingController(
    rootView: SymbolPickerBridge(
      initial: initial,
      onChange: { value in
        onPicked(value)
        if let win = getWindow() {
          if let parent = getParent() ?? anchor.window ?? NSApp.keyWindow {
            parent.endSheet(win, returnCode: .OK)
          } else {
            win.close()
          }
          setWindow(nil)
          setParent(nil)
        }
      },
      onClose: {
        guard let win = getWindow() else { return }
        if let parent = getParent() ?? anchor.window ?? NSApp.keyWindow {
          parent.endSheet(win, returnCode: .cancel)
        } else {
          win.close()
        }
        setWindow(nil)
        setParent(nil)
      }
    ))
  let win = NSWindow(contentViewController: host)
  win.title = "Choose Symbol"
  win.styleMask.insert(.titled)
  win.styleMask.insert(.closable)
  win.setContentSize(NSSize(width: 560, height: 640))
  win.delegate = owner
  setWindow(win)
  let parent = anchor.window ?? NSApp.keyWindow
  setParent(parent)
  if let parent {
    parent.beginSheet(win) { _ in
      setWindow(nil)
      setParent(nil)
    }
  } else {
    win.center()
    win.makeKeyAndOrderFront(nil)
  }
}
extension Notification.Name {
  static let lkExpandAll = Notification.Name("LKExpandAll")
  static let lkCollapseAll = Notification.Name("LKCollapseAll")
  static let lkSortAZ = Notification.Name("LKSortAZ")
}

// MARK: - NSWindowDelegate for symbol sheets
extension ActionCellView {
  func windowShouldClose(_ sender: NSWindow) -> Bool {
    (sender.sheetParent ?? symbolParent)?.endSheet(sender)
    symbolWindow = nil
    symbolParent = nil
    return true
  }
}
extension GroupCellView {
  func windowShouldClose(_ sender: NSWindow) -> Bool {
    (sender.sheetParent ?? symbolParent)?.endSheet(sender)
    symbolWindow = nil
    symbolParent = nil
    return true
  }
}

extension NSView {
  fileprivate func makeFlex() {
    setContentHuggingPriority(.init(10), for: .horizontal)
    setContentCompressionResistancePriority(.init(10), for: .horizontal)
  }

  fileprivate func makeSoft() {
    setContentHuggingPriority(.defaultLow, for: .horizontal)  // 250
    setContentCompressionResistancePriority(.defaultLow, for: .horizontal)  // 250
  }

  fileprivate func makeRigid() {
    setContentHuggingPriority(.defaultHigh, for: .horizontal)  // 750
    setContentCompressionResistancePriority(.init(999), for: .horizontal)
  }
}
