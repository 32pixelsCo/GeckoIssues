import SwiftUI
import GRDB

/// Displays issues for the selected repository in a compact list with sorting controls.
struct IssueListView: View {
    var appStore: AppStore
    var navigationStore: NavigationStore
    var syncStore: SyncStore
    var database: AppDatabase

    @State private var issues: [IssueRow] = []
    @State private var sortOrder: IssueSortOrder = .updated

    var body: some View {
        Group {
            if issues.isEmpty {
                ContentUnavailableView(
                    "No Issues",
                    systemImage: "exclamationmark.bubble",
                    description: Text("This repository has no issues yet.")
                )
            } else {
                List(issues, id: \.issue.id, selection: selectedIssueId) { row in
                    IssueRowView(row: row)
                        .tag(row.issue.id)
                }
                .listStyle(.inset)
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    navigationStore.isShowingNewIssueForm = true
                } label: {
                    SwiftUI.Label("New Issue", systemImage: "plus")
                }
                .accessibilityLabel("Create new issue")
            }
            ToolbarItem(placement: .automatic) {
                sortMenu
            }
        }
        .navigationTitle(navigationTitle)
        .task(id: appStore.selectedRepository?.id) {
            await loadIssues()
        }
        .onChange(of: syncStore.state) {
            if case .completed = syncStore.state {
                Task { await loadIssues() }
            }
        }
        .onChange(of: sortOrder) {
            Task { await loadIssues() }
        }
    }

    // MARK: - Navigation Title

    private var navigationTitle: String {
        guard let repo = appStore.selectedRepository else { return "Issues" }
        let count = issues.count
        return "\(repo.name) — Issues (\(count))"
    }

    // MARK: - Sort Menu

    private var sortMenu: some View {
        Menu {
            Picker("Sort By", selection: $sortOrder) {
                ForEach(IssueSortOrder.allCases) { order in
                    Text(order.label).tag(order)
                }
            }
        } label: {
            SwiftUI.Label("Sort", systemImage: "arrow.up.arrow.down")
        }
        .accessibilityLabel("Sort issues")
    }

    // MARK: - Selection

    private var selectedIssueId: Binding<Int64?> {
        Binding(
            get: { appStore.selectedIssue?.id },
            set: { newId in
                guard let newId else {
                    appStore.selectedIssue = nil
                    return
                }
                appStore.selectedIssue = issues.first { $0.issue.id == newId }?.issue
            }
        )
    }

    // MARK: - Data Loading

    private func loadIssues() async {
        guard let repo = appStore.selectedRepository else {
            issues = []
            return
        }
        do {
            issues = try await database.dbQueue.read { db in
                let ordering: SQLOrderingTerm
                switch sortOrder {
                case .updated:
                    ordering = Column("updatedAt").desc
                case .created:
                    ordering = Column("createdAt").desc
                case .title:
                    ordering = Column("title").collating(.localizedCaseInsensitiveCompare).asc
                }

                let rows = try Issue
                    .filter(Column("repositoryId") == repo.id)
                    .including(all: Issue.labels)
                    .order(ordering)
                    .asRequest(of: IssueWithLabels.self)
                    .fetchAll(db)

                return rows.map { IssueRow(issue: $0.issue, labels: $0.labels) }
            }

            // Refresh the selected issue with updated data from the database
            if let selectedId = appStore.selectedIssue?.id {
                appStore.selectedIssue = issues.first { $0.issue.id == selectedId }?.issue
            }
        } catch {
            // Non-fatal; issue list stays empty
        }
    }
}

// MARK: - Sort Order

enum IssueSortOrder: String, CaseIterable, Identifiable {
    case updated
    case created
    case title

    var id: String { rawValue }

    var label: String {
        switch self {
        case .updated: "Updated"
        case .created: "Created"
        case .title: "Title"
        }
    }
}

// MARK: - Data Types

/// An issue paired with its prefetched labels, used for GRDB association loading.
private struct IssueWithLabels: Decodable, FetchableRecord {
    var issue: Issue
    var labels: [Label]
}

/// A row in the issue list, combining an issue with its labels.
struct IssueRow: Sendable {
    var issue: Issue
    var labels: [Label]
}

// MARK: - Issue Row View

private struct IssueRowView: View {
    var row: IssueRow

    var body: some View {
        HStack(spacing: 6) {
            stateIcon

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text("#\(row.issue.number)")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12, design: .monospaced))

                    Text(row.issue.title)
                        .lineLimit(1)
                        .font(.system(size: 13))
                }

                if !row.labels.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(row.labels, id: \.id) { label in
                            LabelBadge(label: label)
                        }
                    }
                }
            }

            Spacer()

            Text(relativeTimestamp)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - State Icon

    private var stateIcon: some View {
        Group {
            switch row.issue.state {
            case .open:
                Image(systemName: "circle.fill")
                    .foregroundStyle(.green)
            case .closed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.purple)
            }
        }
        .font(.system(size: 12))
    }

    // MARK: - Relative Timestamp

    private var relativeTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: row.issue.updatedAt, relativeTo: Date())
    }

    // MARK: - Accessibility

    private var accessibilityText: String {
        let state = row.issue.state == .open ? "open" : "closed"
        let labels = row.labels.map(\.name).joined(separator: ", ")
        var text = "Issue \(row.issue.number), \(row.issue.title), \(state)"
        if !labels.isEmpty {
            text += ", labels: \(labels)"
        }
        return text
    }
}

