import Combine

enum EventKey {
  // Lifecycle
  case willActivate
  case didActivate
  case willDeactivate
  case didDeactivate

  // Config
  case willReload
  case didReload
}

class Events {
  static let shared = Events()
  private init() {}

  let publisher = PassthroughSubject<EventKey, Never>()

  static func send(_ key: EventKey) {
    shared.publisher.send(key)
  }

  static func sink(_ completion: @escaping (EventKey) -> Void) -> AnyCancellable {
    return shared.publisher.sink { event in
      completion(event)
    }
  }
}
