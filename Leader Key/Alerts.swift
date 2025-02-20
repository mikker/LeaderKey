import Cocoa

protocol AlertHandler {
  func showAlert(style: NSAlert.Style, message: String)
}

class DefaultAlertHandler: AlertHandler {
  func showAlert(style: NSAlert.Style, message: String) {
    let alert = NSAlert()
    alert.alertStyle = style
    alert.messageText = message
    alert.runModal()
  }
}
