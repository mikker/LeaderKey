import Foundation

class FileMonitor {
  private var fileDescriptor: Int32 = -1
  private var queue: DispatchQueue = .main
  private var source: DispatchSourceFileSystemObject?

  private var fileURL: URL!
  private var callback: (() -> Void)!

  init(fileURL: URL, callback: @escaping () -> Void) {
    self.fileURL = fileURL
    self.callback = callback
  }

  deinit {
    print("FileMonitor is being deallocated")
  }

  func startMonitoring() {
    // Ensure the file exists
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      print("File does not exist: \(fileURL.path)")
      return
    }

    // Open the file in read-only mode to get the file descriptor
    fileDescriptor = open(fileURL.path, O_EVTONLY)

    if fileDescriptor == -1 {
      print("Unable to open file: \(fileURL.path)")
      return
    }

    // Create a Dispatch Source that monitors the file for various events
    source = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: fileDescriptor,
      eventMask: [.delete, .write, .extend, .link, .rename, .revoke],
      queue: queue
    )

    source?.setEventHandler { [weak self] in
      guard let self = self else { return }
      guard let event = self.source?.data else {
        print("no event?")
        return
      }

      switch event {
      case .delete, .rename:
        self.waitForFileRecreation(callback: callback)
        break
      default:
        callback()
        break
      }

      stopMonitoring()
      startMonitoring()
    }

    source?.setCancelHandler { [weak self] in
      guard let self = self else { return }
      close(self.fileDescriptor)
      self.fileDescriptor = -1
      self.source = nil
    }

    // Start monitoring
    source?.resume()
  }

  private func waitForFileRecreation(callback: @escaping () -> Void) {
    delay(100) {
      guard FileManager.default.fileExists(atPath: self.fileURL.path) else {
        print("File not found at \(self.fileURL.path)")
        return
      }

      callback()

      self.stopMonitoring()
      self.startMonitoring()
    }
  }

  func stopMonitoring() {
    source?.cancel()
  }
}
