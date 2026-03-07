import Foundation

struct ValidationError: Identifiable, Equatable {
  let id = UUID()
  let path: [Int]  // Path to the item with the error (indices in the actions array)
  let message: String
  let type: ValidationErrorType

  static func == (lhs: ValidationError, rhs: ValidationError) -> Bool {
    lhs.id == rhs.id
  }
}

enum ValidationErrorType {
  case emptyKey
  case nonSingleCharacterKey
  case duplicateKey
  case invalidWhen
}

class ConfigValidator {
  static func validate(group: Group) -> [ValidationError] {
    var errors = [ValidationError]()

    // Validate the root group
    validateGroup(group, path: [], errors: &errors)

    return errors
  }

  private static func validateGroup(_ group: Group, path: [Int], errors: inout [ValidationError]) {
    // Check if the group key is valid (if not root level)
    if !path.isEmpty {
      validateKey(group.key, at: path, errors: &errors)
    }

    // Validate `when` self-consistency for the group itself
    if !path.isEmpty {
      validateWhen(group.when, at: path, errors: &errors)
    }

    // Collect items by normalized key for tier-aware duplicate detection
    struct KeyEntry {
      let index: Int
      let when: When?
    }
    var keyEntries: [String: [KeyEntry]] = [:]

    for (index, item) in group.actions.enumerated() {
      let currentPath = path + [index]

      // Get the key and when from the item
      let key: String?
      let itemWhen: When?
      switch item {
      case .action(let action):
        key = action.key
        itemWhen = action.when
        // Validate the key for actions
        validateKey(key, at: currentPath, errors: &errors)
        // Validate when self-consistency
        validateWhen(itemWhen, at: currentPath, errors: &errors)
      case .group(let subgroup):
        key = subgroup.key
        itemWhen = subgroup.when
        // Recursively validate subgroups
        validateGroup(subgroup, path: currentPath, errors: &errors)
      // Validate when self-consistency (done in recursive call for the group itself)
      }

      // Collect entries by normalized key
      if let key = key, !key.isEmpty {
        let normalizedKey = KeyMaps.glyph(for: key) ?? key
        keyEntries[normalizedKey, default: []].append(KeyEntry(index: index, when: itemWhen))
      }
    }

    // Tier-aware duplicate detection
    for (normalizedKey, entries) in keyEntries {
      guard entries.count > 1 else { continue }

      // Classify each entry by tier (using nil bundleID since we check structurally)
      struct TieredEntry {
        let index: Int
        let when: When?
        let structuralTier: AppFilter.Tier  // tier based on structure, not a specific app
      }

      let tieredEntries: [TieredEntry] = entries.map { entry in
        let tier = structuralTier(for: entry.when)
        return TieredEntry(index: entry.index, when: entry.when, structuralTier: tier)
      }

      // Check for conflicts within each tier
      let tierCEntries = tieredEntries.filter { $0.structuralTier == .c }
      let tierBEntries = tieredEntries.filter { $0.structuralTier == .b }
      let tierAEntries = tieredEntries.filter { $0.structuralTier == .a }

      // Multiple Tier C entries for same key = error
      if tierCEntries.count > 1 {
        for entry in tierCEntries {
          errors.append(
            ValidationError(
              path: path + [entry.index],
              message: "Multiple actions for the same key '\(normalizedKey)'",
              type: .duplicateKey
            ))
        }
      }

      // Multiple Tier B entries for same key = error (they overlap broadly)
      if tierBEntries.count > 1 {
        for entry in tierBEntries {
          errors.append(
            ValidationError(
              path: path + [entry.index],
              message: "Multiple 'everywhere-except' actions for the same key '\(normalizedKey)'",
              type: .duplicateKey
            ))
        }
      }

      // Tier A overlaps: two items with includeApps containing the same bundle ID
      if tierAEntries.count > 1 {
        var bundleToEntries: [String: [TieredEntry]] = [:]
        for entry in tierAEntries {
          for bundle in entry.when?.includeApps ?? [] {
            bundleToEntries[bundle, default: []].append(entry)
          }
        }
        var reportedIndices = Set<Int>()
        for (bundle, conflicting) in bundleToEntries {
          if conflicting.count > 1 {
            for entry in conflicting where !reportedIndices.contains(entry.index) {
              reportedIndices.insert(entry.index)
              errors.append(
                ValidationError(
                  path: path + [entry.index],
                  message:
                    "Multiple app-specific actions for '\(bundle)' on key '\(normalizedKey)'",
                  type: .duplicateKey
                ))
            }
          }
        }
      }
    }
  }

  /// Determine the structural tier of a `when` clause (without a specific bundleID).
  private static func structuralTier(for when: When?) -> AppFilter.Tier {
    guard let when = when else { return .c }
    let include = when.includeApps ?? []
    let exclude = when.excludeApps ?? []
    if include.isEmpty && exclude.isEmpty { return .c }
    if !include.isEmpty { return .a }
    if include.isEmpty && !exclude.isEmpty { return .b }
    return .c
  }

  /// Validate that a `when` clause is self-consistent.
  private static func validateWhen(_ when: When?, at path: [Int], errors: inout [ValidationError]) {
    guard let when = when else { return }
    let include = Set(when.includeApps ?? [])
    let exclude = Set(when.excludeApps ?? [])
    let overlap = include.intersection(exclude)
    if !overlap.isEmpty {
      errors.append(
        ValidationError(
          path: path,
          message: "Bundle ID '\(overlap.first!)' appears in both includeApps and excludeApps",
          type: .invalidWhen
        ))
    }
  }

  private static func validateKey(_ key: String?, at path: [Int], errors: inout [ValidationError]) {
    guard let key = key else {
      errors.append(
        ValidationError(
          path: path,
          message: "Key is missing",
          type: .emptyKey
        ))
      return
    }

    if key.isEmpty {
      errors.append(
        ValidationError(
          path: path,
          message: "Key is empty",
          type: .emptyKey
        ))
      return
    }

    // Check if key is valid in our key mapping system
    let entry = KeyMaps.entry(for: key) ?? KeyMaps.entry(forText: key)

    if entry == nil && key.count != 1 {
      errors.append(
        ValidationError(
          path: path,
          message: "Key must be a single character or a valid key name",
          type: .nonSingleCharacterKey
        ))
      return
    }

    // Check if key is reserved (only for non-root level)
    if !path.isEmpty, let entry = entry, entry.isReserved {
      errors.append(
        ValidationError(
          path: path,
          message: "Key '\(key)' is reserved and cannot be bound",
          type: .duplicateKey  // Reusing existing error type
        ))
    }
  }

  // Helper function to find an item at a specific path
  static func findItem(in group: Group, at path: [Int]) -> ActionOrGroup? {
    guard !path.isEmpty else { return .group(group) }

    var currentGroup = group
    var remainingPath = path

    while !remainingPath.isEmpty {
      let index = remainingPath.removeFirst()

      guard index < currentGroup.actions.count else { return nil }

      if remainingPath.isEmpty {
        // We've reached the target item
        return currentGroup.actions[index]
      } else {
        // We need to go deeper
        guard case .group(let subgroup) = currentGroup.actions[index] else {
          // Path points through an action, which can't contain other items
          return nil
        }
        currentGroup = subgroup
      }
    }

    return nil
  }
}
