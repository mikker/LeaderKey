import Cocoa

protocol AlertHandler {
  func showAlert(style: NSAlert.Style, message: String)
  func showAlert(style: NSAlert.Style, message: String, informativeText: String, buttons: [String])
    -> NSApplication.ModalResponse
}

class DefaultAlertHandler: AlertHandler {
  func showAlert(style: NSAlert.Style, message: String) {
    let alert = NSAlert()
    alert.alertStyle = style
    alert.messageText = message
    alert.runModal()
  }

  func showAlert(style: NSAlert.Style, message: String, informativeText: String, buttons: [String])
    -> NSApplication.ModalResponse
  {
    let alert = NSAlert()
    alert.alertStyle = style
    alert.messageText = message
    alert.informativeText = informativeText

    for button in buttons {
      alert.addButton(withTitle: button)
    }

    return alert.runModal()
  }
}
