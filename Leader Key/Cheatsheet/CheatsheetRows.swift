import SwiftUI
import Defaults

private let iconSize = NSSize(width: 24, height: 24)

struct ActionRow: View {
    let action: Action
    let indent: Int
    @Default(.showDetailsInCheatsheet) var showDetails
    @Default(.showAppIconsInCheatsheet) var showIcons

    var body: some View {
        HStack {
            HStack {
                ForEach(0..<indent, id: \.self) { _ in
                    Text("  ")
                }
                KeyBadge(key: action.key ?? "●")

                if showIcons {
                    actionIcon(item: ActionOrGroup.action(action), iconSize: iconSize)
                }

                Text(action.displayName)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if showDetails {
                Text(action.value)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }
}

struct GroupRow: View {
    @Default(.expandGroupsInCheatsheet) var expand
    @Default(.showDetailsInCheatsheet) var showDetails
    @Default(.showAppIconsInCheatsheet) var showIcons

    let group: Group
    let indent: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                ForEach(0..<indent, id: \.self) { _ in
                    Text("  ")
                }
                KeyBadge(key: group.key ?? "")

                if showIcons {
                    actionIcon(item: ActionOrGroup.group(group), iconSize: iconSize)
                }

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)

                Text(group.displayName)

                Spacer()
                if showDetails {
                    Text("\(group.actions.count.description) item(s)")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            if expand {
                ForEach(Array(group.actions.enumerated()), id: \.offset) { _, item in
                    switch item {
                    case .action(let action):
                        ActionRow(action: action, indent: indent + 1)
                    case .group(let group):
                        GroupRow(group: group, indent: indent + 1)
                    }
                }
            }
        }
    }
}