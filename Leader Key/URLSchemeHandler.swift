import Foundation

enum URLSchemeAction: Equatable {
  case settings
  case about
  case configReload
  case configReveal
  case activate
  case hide
  case reset
  case navigate(keys: [String], execute: Bool)
  case show  // Fallback for unknown hosts
  case invalid  // Invalid scheme
}

class URLSchemeHandler {
  static func parse(_ url: URL) -> URLSchemeAction {
    guard url.scheme == "leaderkey" else {
      return .invalid
    }

    switch url.host {
    case "settings":
      return .settings
    case "about":
      return .about
    case "config-reload":
      return .configReload
    case "config-reveal":
      return .configReveal
    case "activate":
      return .activate
    case "hide":
      return .hide
    case "reset":
      return .reset
    case "navigate":
      guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
        let queryItems = components.queryItems,
        let keysParam = queryItems.first(where: { $0.name == "keys" })?.value
      else {
        return .show
      }
      let keys = keysParam.split(separator: ",").map(String.init)
      let execute = queryItems.first(where: { $0.name == "execute" })?.value != "false"
      return .navigate(keys: keys, execute: execute)
    default:
      return .show
    }
  }
}
