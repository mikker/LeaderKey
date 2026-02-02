import Cocoa
import SwiftUI

class InputPromptWindow: NSPanel {
    private var textField: NSTextField!
    private var onSubmit: ((String) -> Void)?
    private var onCancel: (() -> Void)?
    private var previousApp: NSRunningApplication?
    
    init(label: String, prompt: String, placeholder: String = "", onSubmit: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.onSubmit = onSubmit
        self.onCancel = onCancel
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 56),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.isFloatingPanel = true
        self.level = .screenSaver  // Topmost level
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isReleasedWhenClosed = false
        self.hidesOnDeactivate = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        setupUI(label: label, prompt: prompt, placeholder: placeholder)
        positionWindow()
        
        self.delegate = self
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    private func positionWindow() {
        guard let screen = NSScreen.main else {
            center()
            return
        }
        
        let screenFrame = screen.visibleFrame
        let windowFrame = self.frame
        let x = screenFrame.midX - windowFrame.width / 2
        let y = screenFrame.maxY - 200 - windowFrame.height  // 200pt from top
        
        self.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    private func setupUI(label: String, prompt: String, placeholder: String) {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 56))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor
        
        let visualEffect = NSVisualEffectView(frame: container.bounds)
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 12
        visualEffect.layer?.masksToBounds = true
        container.addSubview(visualEffect)
        
        let actionLabel = NSTextField(labelWithString: label)
        actionLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        actionLabel.textColor = NSColor.tertiaryLabelColor
        actionLabel.alignment = .right
        actionLabel.frame = NSRect(x: 350, y: 36, width: 134, height: 14)
        actionLabel.lineBreakMode = .byTruncatingTail
        visualEffect.addSubview(actionLabel)
        
        textField = NSTextField(string: "")
        textField.placeholderString = prompt
        textField.font = NSFont.systemFont(ofSize: 24, weight: .light)
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.frame = NSRect(x: 16, y: 10, width: 468, height: 32)
        textField.delegate = self
        visualEffect.addSubview(textField)
        
        self.contentView = container
    }
    
    func showAndFocus() {
        previousApp = NSWorkspace.shared.frontmostApplication
        
        positionWindow()
        makeKeyAndOrderFront(nil)
        orderFrontRegardless()  // Force to front
        textField.becomeFirstResponder()
        textField.selectText(nil)
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func submitAction() {
        let value = textField.stringValue
        close()
        onSubmit?(value)
    }
    
    @objc private func cancelAction() {
        close()
        restorePreviousApp()
        onCancel?()
    }
    
    private func restorePreviousApp() {
        previousApp?.activate()
    }
}

extension InputPromptWindow: NSTextFieldDelegate {
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            submitAction()
            return true
        } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            cancelAction()
            return true
        }
        return false
    }
}

extension InputPromptWindow: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        cancelAction()
    }
}

extension Action {
    var requiresInput: Bool {
        return prompt != nil && !prompt!.isEmpty
    }
    
    func valueWithInput(_ input: String) -> String {
        return value.replacingOccurrences(of: "{input}", with: input)
    }
}
