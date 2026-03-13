import AppKit
import Settings
import SwiftUI
import Kingfisher

struct StatsPane: View {
  private let contentWidth = 550.0

  @EnvironmentObject private var userConfig: UserConfig

  @State private var groupedStats: [GroupStats] = []
  @State private var expandedGroups: Set<String> = []
  @State private var totalExecutions: Int = 0

  var body: some View {
    Settings.Container(contentWidth: contentWidth) {
      Settings.Section(title: "") {
        VStack(alignment: .leading, spacing: 16) {
          // Header
          HStack(alignment: .center) {
            Text("Usage Stats")
              .font(.headline)
            Spacer()
            Text("\(totalExecutions) total")
              .foregroundColor(.primary)
              .font(.system(.body, design: .rounded))
              .fontWeight(.medium)
              .monospacedDigit()
          }
          .padding(.bottom, 8)

          // Stats list
          if groupedStats.isEmpty {
            Text("No actions recorded yet")
              .foregroundColor(.secondary)
              .padding(.vertical, 20)
          } else {
            ScrollView {
              VStack(spacing: 2) {
                ForEach(groupedStats) { group in
                  GroupStatsRow(
                    group: group,
                    isExpanded: expandedGroups.contains(group.id),
                    maxCount: groupedStats.first?.totalCount ?? 1,
                    depth: 0,
                    expandedGroups: $expandedGroups
                  )
                }
              }
            }
            .scrollIndicators(.hidden)
            .frame(height: 400)
          }
        }
      }

      Settings.Section(title: "") {
        VStack {
          Spacer()
            .frame(height: 24)

          HStack {
            Spacer()
            Button("Clear Stats") {
              showClearConfirmation()
            }
            Spacer()
          }
        }
      }
    }
    .onAppear {
      loadStats()
    }
  }

  private func loadStats() {
    let rawActions = StatsManager.shared.getMostUsedActions(limit: 50)

    // Build tree structure
    let allDisplays = rawActions.map { stat in
      ActionStatsDisplay(
        action: stat,
        pathComponents: stat.keyPath.split(separator: "/").map(String.init)
      )
    }

    groupedStats = buildGroupTree(displays: allDisplays, pathPrefix: [])
      .sorted { $0.totalCount > $1.totalCount }

    totalExecutions = StatsManager.shared.getTotalExecutions()
  }

  private func buildGroupTree(displays: [ActionStatsDisplay], pathPrefix: [String]) -> [GroupStats] {
    var result: [GroupStats] = []

    // Group by next path component
    var grouped: [String: [ActionStatsDisplay]] = [:]
    var leafActions: [ActionStatsDisplay] = []

    for display in displays {
      let remainingPath = Array(display.pathComponents.dropFirst(pathPrefix.count))

      if remainingPath.count == 1 {
        // This is a leaf action at this level
        leafActions.append(display)
      } else if remainingPath.count > 1 {
        // This belongs to a subgroup
        let nextKey = remainingPath[0]
        grouped[nextKey, default: []].append(display)
      }
    }

    // Create GroupStats for each subgroup
    for (key, items) in grouped {
      let fullPath = (pathPrefix + [key]).joined(separator: "/")
      let totalCount = items.reduce(0) { $0 + $1.action.executionCount }
      let groupLabel = findGroupLabel(for: key, at: pathPrefix) ?? key.capitalized

      // Recursively build children
      let nestedGroups = buildGroupTree(displays: items, pathPrefix: pathPrefix + [key])
      let children: [GroupStatsChild] = nestedGroups.map { .group($0) }

      result.append(GroupStats(
        fullPath: fullPath,
        groupKey: key,
        groupLabel: groupLabel,
        totalCount: totalCount,
        children: children,
        isGroup: true
      ))
    }

    // Add leaf actions
    for action in leafActions {
      result.append(GroupStats(
        fullPath: action.action.keyPath,
        groupKey: action.pathComponents.last ?? "",
        groupLabel: action.action.actionLabel ?? action.action.actionValue,
        totalCount: action.action.executionCount,
        children: [.action(action)],
        isGroup: false
      ))
    }

    return result.sorted { $0.totalCount > $1.totalCount }
  }

  private func findGroupLabel(for key: String, at pathPrefix: [String]) -> String? {
    // Navigate to the right level in the config
    var current: Group = userConfig.root

    for component in pathPrefix {
      guard let nextGroup = current.actions.first(where: { item in
        if case .group(let g) = item, g.key == component {
          return true
        }
        return false
      }) else {
        return nil
      }

      if case .group(let g) = nextGroup {
        current = g
      }
    }

    // Find the group at this level
    for item in current.actions {
      if case .group(let group) = item, group.key == key {
        return group.label ?? group.key
      }
    }

    return nil
  }


  private func showClearConfirmation() {
    let alert = NSAlert()
    alert.messageText = "Clear All Stats?"
    alert.informativeText =
      "This will permanently delete all recorded action history."
    alert.alertStyle = .warning
    alert.addButton(withTitle: "Clear")
    alert.addButton(withTitle: "Cancel")

    if alert.runModal() == .alertFirstButtonReturn {
      StatsManager.shared.clearAllStats()
      loadStats()
    }
  }
}

private struct GroupStats: Identifiable {
  var id: String { fullPath }
  let fullPath: String  // Full path for unique ID
  let groupKey: String  // Just this level's key
  let groupLabel: String
  let totalCount: Int
  let children: [GroupStatsChild]
  let isGroup: Bool
}

private enum GroupStatsChild: Identifiable {
  case action(ActionStatsDisplay)
  case group(GroupStats)

  var id: String {
    switch self {
    case .action(let display):
      return display.id.uuidString
    case .group(let group):
      return group.id
    }
  }

  var executionCount: Int {
    switch self {
    case .action(let display):
      return display.action.executionCount
    case .group(let group):
      return group.totalCount
    }
  }
}

private struct ActionStatsDisplay: Identifiable {
  let id = UUID()
  let action: ActionStats
  let pathComponents: [String]
}

private struct GroupStatsRow: View {
  let group: GroupStats
  let isExpanded: Bool
  let maxCount: Int
  let depth: Int
  @Binding var expandedGroups: Set<String>

  private let indentPerLevel: CGFloat = 16

  var body: some View {
    if group.isGroup {
      // Collapsible group with children
      VStack(spacing: 2) {
        // Group header
        HStack(spacing: 0) {
          // Indent spacer outside the button
          if depth > 0 {
            Spacer()
              .frame(width: indentPerLevel * CGFloat(depth))
          }

          Button(action: {
            if expandedGroups.contains(group.id) {
              expandedGroups.remove(group.id)
            } else {
              expandedGroups.insert(group.id)
            }
          }) {
            HStack(alignment: .center, spacing: 0) {
              // Chevron
              Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .animation(.easeInOut(duration: 0.2), value: isExpanded)
                .frame(width: 14)

              // Key badge
              KeyBadgeView(key: group.groupKey)
                .padding(.leading, 4)

              // Group name
              Text(group.groupLabel)
                .font(.system(.body))
                .foregroundColor(.primary)
                .padding(.leading, 8)

              Spacer(minLength: 16)

              // Right-aligned section (always same position)
              HStack(spacing: 0) {
                // Progress bar
                ProgressBarView(value: group.totalCount, max: maxCount)
                  .padding(.trailing, 20)

                // Folder icon
                Image(systemName: "folder")
                  .resizable()
                  .scaledToFit()
                  .foregroundColor(.secondary)
                  .frame(width: 24, height: 24)

                // Count
                Text("\(group.totalCount)")
                  .foregroundColor(.primary)
                  .font(.system(.body, design: .rounded))
                  .fontWeight(.medium)
                                  .monospacedDigit()
                                  .frame(width: 36, alignment: .trailing)
                              }
                            }
                            .padding(.trailing, 18)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 8)
                            .background(              RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.1))
            )
            .contentShape(Rectangle())
          }
          .buttonStyle(PlainButtonStyle())
        }

        // Expanded children
        if isExpanded {
          VStack(spacing: 2) {
            ForEach(group.children) { child in
              switch child {
              case .action(let stat):
                ActionStatsRow(
                  stat: stat,
                  maxCount: group.children.map(\.executionCount).max() ?? 1,
                  depth: depth + 1,
                  expandedGroups: $expandedGroups
                )
              case .group(let subGroup):
                GroupStatsRow(
                  group: subGroup,
                  isExpanded: expandedGroups.contains(subGroup.id),
                  maxCount: group.children.map(\.executionCount).max() ?? 1,
                  depth: depth + 1,
                  expandedGroups: $expandedGroups
                )
              }
            }
          }
        }
      }
    } else {
      // Top-level individual action
      if case .action(let stat) = group.children.first {
        ActionStatsRow(
          stat: stat,
          maxCount: maxCount,
          depth: depth,
          expandedGroups: $expandedGroups
        )
      }
    }
  }
}

private struct ActionStatsRow: View {
  let stat: ActionStatsDisplay
  let maxCount: Int
  let depth: Int
  @Binding var expandedGroups: Set<String>

  private let indentPerLevel: CGFloat = 16

  var body: some View {
    HStack(alignment: .center, spacing: 0) {
      // Indent spacer (add extra indent since no chevron)
      Spacer()
        .frame(width: indentPerLevel * CGFloat(depth) + 14)

      // Key badge
      if let lastKey = stat.pathComponents.last {
        KeyBadgeView(key: lastKey)
          .padding(.leading, 4)
      }

      // Action name
      Text(displayName)
        .font(.system(.body))
        .lineLimit(1)
        .truncationMode(.tail)
        .padding(.leading, 8)

      Spacer(minLength: 16)

      // Right-aligned section (always same position)
      HStack(spacing: 0) {
        // Progress bar
        ProgressBarView(value: stat.action.executionCount, max: maxCount)
          .padding(.trailing, 20)

        // Icon
        ActionIconView(actionType: stat.action.actionType, actionValue: stat.action.actionValue)

        // Count
        Text("\(stat.action.executionCount)")
          .foregroundColor(.primary)
          .font(.system(.body, design: .rounded))
          .fontWeight(.medium)
          .monospacedDigit()
          .frame(width: 36, alignment: .trailing)
      }
    }
    .padding(.trailing, 18)
    .padding(.vertical, 8)
    .padding(.horizontal, 8)
    .contentShape(Rectangle())
  }

  private var displayName: String {
    if let label = stat.action.actionLabel, !label.isEmpty {
      return label
    }
    switch stat.action.actionType {
    case "application":
      return
        (stat.action.actionValue as NSString).lastPathComponent
        .replacingOccurrences(of: ".app", with: "")
    case "folder":
      return (stat.action.actionValue as NSString).lastPathComponent
    default:
      return stat.action.actionValue
    }
  }
}

private struct ProgressBarView: View {
  let value: Int
  let max: Int

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: 2)
          .fill(Color.secondary.opacity(0.15))
          .frame(height: 6)

        RoundedRectangle(cornerRadius: 2)
          .fill(Color.accentColor)
          .frame(
            width: geometry.size.width * CGFloat(value) / CGFloat(max),
            height: 6
          )
      }
    }
    .frame(width: 100, height: 6)
  }
}

private struct KeyBadgeView: View {
  let key: String

  var body: some View {
    Text(KeyMaps.glyph(for: key) ?? key)
      .font(.system(.callout, design: .monospaced))
      .fontWeight(.medium)
      .foregroundColor(.primary)
      .frame(width: 28, height: 28)
      .background(Color.secondary.opacity(0.15))
      .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
  }
}

private struct ActionIconView: View {
  let actionType: String
  let actionValue: String

  private let iconSize: CGFloat = 24

  var body: some View {
    iconContent
      .frame(width: iconSize, height: iconSize)
  }

  @ViewBuilder
  private var iconContent: some View {
    switch actionType {
    case "application":
      AppIconImage(appPath: actionValue, size: NSSize(width: iconSize, height: iconSize))
    case "url":
      FavIconImage(url: actionValue, icon: "link", size: NSSize(width: iconSize, height: iconSize))
    case "folder", "group":
      Image(systemName: "folder")
        .resizable()
        .scaledToFit()
        .foregroundColor(.secondary)
    case "command":
      Image(systemName: "terminal")
        .resizable()
        .scaledToFit()
        .foregroundColor(.secondary)
    default:
      Image(systemName: "questionmark.circle")
        .resizable()
        .scaledToFit()
        .foregroundColor(.secondary)
    }
  }
}
