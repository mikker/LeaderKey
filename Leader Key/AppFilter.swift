import Foundation

enum AppFilter {
  enum Tier: Int, Comparable {
    case c = 0  // global (no `when` or both arrays empty)
    case b = 1  // excludeApps non-empty, includeApps empty
    case a = 2  // includeApps non-empty and contains active app

    static func < (lhs: Tier, rhs: Tier) -> Bool { lhs.rawValue < rhs.rawValue }
  }

  /// Whether an item's `when` matches the given bundle ID.
  static func matches(when: When?, bundleID: String?) -> Bool {
    guard let when = when else { return true }
    let include = when.includeApps ?? []
    let exclude = when.excludeApps ?? []
    let includeMatch = include.isEmpty || include.contains(bundleID ?? "")
    let excludeMatch = exclude.isEmpty || !exclude.contains(bundleID ?? "")
    return includeMatch && excludeMatch
  }

  /// Compute the tier of an item for a given bundle ID.
  /// Returns nil if the item doesn't match (should be filtered out).
  static func tier(for when: When?, bundleID: String?) -> Tier? {
    guard matches(when: when, bundleID: bundleID) else { return nil }
    guard let when = when else { return .c }
    let include = when.includeApps ?? []
    let exclude = when.excludeApps ?? []
    if include.isEmpty && exclude.isEmpty { return .c }
    if !include.isEmpty && include.contains(bundleID ?? "") { return .a }
    if include.isEmpty && !exclude.isEmpty { return .b }
    return .c
  }

  /// Filter and resolve actions for the frontmost app.
  /// Returns items that match scope, with highest-tier winner per key.
  static func resolve(actions: [ActionOrGroup], for bundleID: String?) -> [ActionOrGroup] {
    // Compute tier for each item. nil means filtered out.
    var tiered: [(item: ActionOrGroup, tier: Tier, index: Int)] = []
    for (index, item) in actions.enumerated() {
      if let t = tier(for: item.when, bundleID: bundleID) {
        tiered.append((item, t, index))
      }
    }

    // Group by normalized key
    var byKey: [String: [(item: ActionOrGroup, tier: Tier, index: Int)]] = [:]
    var noKey: [(item: ActionOrGroup, tier: Tier, index: Int)] = []

    for entry in tiered {
      let key = entry.item.item.key ?? ""
      if key.isEmpty {
        noKey.append(entry)
      } else {
        let normalized = KeyMaps.glyph(for: key) ?? key
        byKey[normalized, default: []].append(entry)
      }
    }

    // For each key, keep only the highest-tier winner(s)
    var winnerIndices: Set<Int> = []

    for (_, candidates) in byKey {
      let maxTier = candidates.map(\.tier).max()!
      let winners = candidates.filter { $0.tier == maxTier }
      // Take the first winner at the highest tier (validator catches same-tier ties)
      if let winner = winners.first {
        winnerIndices.insert(winner.index)
      }
    }

    // Items without keys always pass if they matched
    for entry in noKey {
      winnerIndices.insert(entry.index)
    }

    // Preserve original order
    var result: [ActionOrGroup] = []
    for (index, item) in actions.enumerated() {
      if winnerIndices.contains(index) {
        result.append(item)
      }
    }

    return result
  }
}
