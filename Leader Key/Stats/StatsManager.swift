import Foundation

class StatsManager {
  static let shared = StatsManager()

  // Optimization: Only keep recent executions in memory
  private var recentExecutions: [ActionExecution] = []
  private let maxRecentExecutions = 50
  
  // Optimization: Pre-aggregate daily counts
  private var dailyExecutions: [Date: Int] = [:]

  private var actionStatsCache: [String: ActionStats] = [:]
  private var groupStatsCache: [String: GroupNavigationStats] = [:]
  
  private var totalExecutions: Int = 0
  private var totalNavigations: Int = 0

  private let statsFilePath: String
  private var fileHandle: FileHandle?
  private let ioQueue = DispatchQueue(label: "com.leaderkey.StatsIO", qos: .utility)
  private let lock = NSLock()
  private let encoder = JSONEncoder()

  private init() {
    let supportDir = UserConfig.defaultDirectory()
    statsFilePath = (supportDir as NSString).appendingPathComponent("stats.jsonl")
    setupStatsFile()
    loadFromDisk()
  }

  private func setupStatsFile() {
    let fileManager = FileManager.default

    do {
      try fileHandle?.close()
    } catch {
      print("Failed to close stats file: \(error)")
    }
    fileHandle = nil

    if !fileManager.fileExists(atPath: statsFilePath) {
      fileManager.createFile(atPath: statsFilePath, contents: nil)
    }

    do {
      fileHandle = try FileHandle(forUpdating: URL(fileURLWithPath: statsFilePath))
      try fileHandle?.seekToEnd()
    } catch {
      print("Failed to open stats file: \(error)")
    }
  }

  private func actionStatsKey(for record: ActionExecution) -> String {
    if !record.keyPath.isEmpty {
      return record.keyPath
    }
    return "\(record.actionType)|\(record.actionValue)"
  }

  private func groupStatsKey(for record: ActionExecution) -> String {
    if !record.keyPath.isEmpty {
      return record.keyPath
    }
    return record.actionValue
  }

  private func loadFromDisk() {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: statsFilePath)) else {
      return
    }

    // TODO: For very large files, stream line-by-line instead of loading all at once
    let lines = String(data: data, encoding: .utf8)?.components(separatedBy: .newlines) ?? []
    let decoder = JSONDecoder()
    let calendar = Calendar.current

    for line in lines {
      guard !line.isEmpty else { continue }

      do {
        let record = try decoder.decode(ActionExecution.self, from: Data(line.utf8))
        updateAggregates(record)
        
        // Track daily stats
        let day = calendar.startOfDay(for: record.timestamp)
        dailyExecutions[day, default: 0] += 1

        // Maintain fixed-size recent history
        recentExecutions.append(record)
        if recentExecutions.count > maxRecentExecutions {
          recentExecutions.removeFirst()
        }
      } catch {
        print("Failed to parse stats line: \(error)")
      }
    }
  }

  private func updateAggregates(_ record: ActionExecution) {
    if record.eventType == "action" {
      totalExecutions += 1

      let key = actionStatsKey(for: record)
      if var existing = actionStatsCache[key] {
        existing.executionCount += 1
        if record.timestamp > existing.lastExecuted {
          existing.lastExecuted = record.timestamp
        }
        if (existing.actionLabel?.isEmpty ?? true), !(record.actionLabel?.isEmpty ?? true) {
          existing.actionLabel = record.actionLabel
        }
        actionStatsCache[key] = existing
      } else {
        actionStatsCache[key] = ActionStats(
          actionValue: record.actionValue,
          actionType: record.actionType,
          actionLabel: record.actionLabel,
          keyPath: record.keyPath,
          executionCount: 1,
          lastExecuted: record.timestamp
        )
      }
    } else if record.eventType == "group" {
      totalNavigations += 1

      let key = groupStatsKey(for: record)
      if var existing = groupStatsCache[key] {
        existing.navigationCount += 1
        if record.timestamp > existing.lastNavigated {
          existing.lastNavigated = record.timestamp
        }
        if (existing.groupLabel?.isEmpty ?? true), !(record.actionLabel?.isEmpty ?? true) {
          existing.groupLabel = record.actionLabel
        }
        groupStatsCache[key] = existing
      } else {
        groupStatsCache[key] = GroupNavigationStats(
          groupKey: record.actionValue,
          groupLabel: record.actionLabel,
          keyPath: record.keyPath,
          navigationCount: 1,
          lastNavigated: record.timestamp
        )
      }
    }
  }

  private func appendToFile(_ record: ActionExecution) {
    ioQueue.async { [weak self] in
      guard let self = self else { return }

      guard let jsonData = try? self.encoder.encode(record) else {
        print("Failed to encode stats record")
        return
      }

      guard let jsonString = String(data: jsonData, encoding: .utf8) else {
        return
      }

      let line = jsonString + "\n"
      guard let lineData = line.data(using: .utf8) else { return }

      do {
        try self.fileHandle?.write(contentsOf: lineData)
      } catch {
        print("Failed to write stats record: \(error)")
      }
    }
  }

  // MARK: - Recording

  func recordExecution(action: Action, keyPath: String) {
    let record = ActionExecution(
      actionType: action.type.rawValue,
      actionValue: action.value,
      actionLabel: action.label,
      keyPath: keyPath,
      eventType: "action",
      timestamp: Date()
    )

    lock.lock()
    updateAggregates(record)
    
    let calendar = Calendar.current
    let day = calendar.startOfDay(for: record.timestamp)
    dailyExecutions[day, default: 0] += 1
    
    recentExecutions.append(record)
    if recentExecutions.count > maxRecentExecutions {
      recentExecutions.removeFirst()
    }
    lock.unlock()

    appendToFile(record)
  }

  func recordGroupNavigation(group: Group, keyPath: String) {
    let record = ActionExecution(
      actionType: "group",
      actionValue: group.key ?? "",
      actionLabel: group.label,
      keyPath: keyPath,
      eventType: "group",
      timestamp: Date()
    )

    lock.lock()
    updateAggregates(record)
    
    // Also track navigations in daily stats? 
    // The previous implementation included everything in 'executions' array but getExecutionsPerDay iterated all.
    // Let's include them to maintain behavior.
    let calendar = Calendar.current
    let day = calendar.startOfDay(for: record.timestamp)
    dailyExecutions[day, default: 0] += 1
    
    recentExecutions.append(record)
    if recentExecutions.count > maxRecentExecutions {
      recentExecutions.removeFirst()
    }
    lock.unlock()

    appendToFile(record)
  }

  // MARK: - Queries

  func getMostUsedActions(limit: Int = 20) -> [ActionStats] {
    lock.lock()
    defer { lock.unlock() }

    return Array(actionStatsCache.values)
      .sorted { $0.executionCount > $1.executionCount }
      .prefix(limit)
      .map { $0 }
  }

  func getMostNavigatedGroups(limit: Int = 20) -> [GroupNavigationStats] {
    lock.lock()
    defer { lock.unlock() }

    return Array(groupStatsCache.values)
      .sorted { $0.navigationCount > $1.navigationCount }
      .prefix(limit)
      .map { $0 }
  }

  func getRecentActivity(limit: Int = 50) -> [ActionExecution] {
    lock.lock()
    defer { lock.unlock() }

    // Return reversed so newest is first
    return Array(recentExecutions.suffix(limit).reversed())
  }

  func getTotalExecutions() -> Int {
    lock.lock()
    defer { lock.unlock() }

    return totalExecutions
  }

  func getTotalNavigations() -> Int {
    lock.lock()
    defer { lock.unlock() }

    return totalNavigations
  }

  func getExecutionsPerDay(days: Int = 30) -> [(date: Date, count: Int)] {
    lock.lock()
    defer { lock.unlock() }

    let calendar = Calendar.current
    guard let cutoffDate = calendar.date(byAdding: .day, value: -days, to: Date()) else {
      return []
    }

    // Filter from pre-aggregated dictionary
    return dailyExecutions
      .filter { $0.key >= cutoffDate }
      .sorted { $0.key < $1.key }
      .map { (date: $0.key, count: $0.value) }
  }

  func getTodayCount() -> Int {
    lock.lock()
    defer { lock.unlock() }

    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    return dailyExecutions[today] ?? 0
  }

  func clearAllStats() {
    lock.lock()
    recentExecutions.removeAll()
    dailyExecutions.removeAll()
    actionStatsCache.removeAll()
    groupStatsCache.removeAll()
    totalExecutions = 0
    totalNavigations = 0
    lock.unlock()

    ioQueue.async { [weak self] in
      guard let self = self else { return }

      do {
        try self.fileHandle?.close()
      } catch {
        print("Failed to close stats file: \(error)")
      }
      self.fileHandle = nil

      try? FileManager.default.removeItem(atPath: self.statsFilePath)
      self.setupStatsFile()
    }
  }
}

struct ActionExecution: Codable {
  var actionType: String
  var actionValue: String
  var actionLabel: String?
  var keyPath: String
  var eventType: String
  var timestamp: Date
}

struct ActionStats {
  var actionValue: String
  var actionType: String
  var actionLabel: String?
  var keyPath: String
  var executionCount: Int
  var lastExecuted: Date
}

struct GroupNavigationStats {
  var groupKey: String
  var groupLabel: String?
  var keyPath: String
  var navigationCount: Int
  var lastNavigated: Date
}
