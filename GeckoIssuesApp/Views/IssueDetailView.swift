import SwiftUI
import GRDB

/// Displays and edits an issue using the "always editing" pattern.
///
/// When `issue` is nil, acts as a new-issue form with a Create button.
/// When `issue` is present, fields are populated from the existing issue.
struct IssueDetailView: View {
    var issue: Issue?
    var repository: Repository
    var navigationStore: NavigationStore
    var syncStore: SyncStore
    var authStore: AuthStore
    var database: AppDatabase

    private var isNewIssue: Bool { issue == nil }

    // MARK: - Editable State

    @State private var title = ""
    @State private var issueBody = ""

    // MARK: - Sidebar Selections (node IDs for mutations)

    @State private var selectedLabelIds: Set<String> = []
    @State private var selectedAssigneeIds: Set<String> = []
    @State private var selectedMilestoneId: String?

    // MARK: - Available Options (fetched from GitHub with node IDs)

    @State private var availableLabels: [SelectableItem] = []
    @State private var availableAssignees: [SelectableItem] = []
    @State private var availableMilestones: [SelectableItem] = []

    // MARK: - Comments (existing issues only)

    @State private var comments: [Comment] = []

    // MARK: - Loading / Error

    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            mainContent
            Divider()
            sidebar
        }
        .task(id: issue?.id) {
            populateFromIssue()
            await loadSidebarData()
            if let issue {
                await loadComments(for: issue)
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                issueHeader
                bodyEditor
                if !isNewIssue, !comments.isEmpty {
                    commentsSection
                }
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .safeAreaInset(edge: .bottom) {
            if isNewIssue {
                createBar
            }
        }
    }

    // MARK: - Issue Header

    private var issueHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let issue {
                HStack(alignment: .center, spacing: 8) {
                    stateBadge(for: issue)
                    Text("#\(issue.number)")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 13, design: .monospaced))
                }
            }
            TextField("Title", text: $title)
                .textFieldStyle(.plain)
                .font(.title2.bold())
                .accessibilityLabel("Issue title")
            Divider()
        }
    }

    private func stateBadge(for issue: Issue) -> some View {
        HStack(spacing: 4) {
            Image(systemName: issue.state == .open ? "circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 11))
            Text(issue.state == .open ? "Open" : "Closed")
                .font(.subheadline.weight(.medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(issue.state == .open ? Color.green : Color.purple)
        .clipShape(Capsule())
        .accessibilityLabel(issue.state == .open ? "Open issue" : "Closed issue")
    }

    // MARK: - Body Editor

    private var bodyEditor: some View {
        TextEditor(text: $issueBody)
            .font(.body)
            .scrollDisabled(true)
            .frame(minHeight: 150)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("Issue body, supports markdown")
    }

    // MARK: - Comments

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 1)
                Text("Comments (\(comments.count))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize()
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 1)
            }
            .padding(.vertical, 8)

            ForEach(comments, id: \.id) { comment in
                CommentRow(comment: comment)
                if comment.id != comments.last?.id {
                    Divider()
                        .padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: - Create Bar (new issues only)

    private var createBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Spacer()
                Button("Cancel") {
                    navigationStore.isShowingNewIssueForm = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Create Issue") {
                    Task { await createIssue() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                labelsSidebarSection
                assigneesSidebarSection
                milestoneSidebarSection
                if let issue {
                    updatedSection(for: issue)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 200)
    }

    private var labelsSidebarSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sidebarHeading("Labels")
            if availableLabels.isEmpty {
                Text("None")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            } else {
                FlowLayout(spacing: 4) {
                    ForEach(availableLabels, id: \.nodeId) { label in
                        Toggle(isOn: labelBinding(for: label.nodeId)) {
                            Text(label.name)
                                .font(.system(size: 11))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                        }
                        .toggleStyle(.button)
                        .buttonStyle(.bordered)
                        .tint(label.color.map { Color(hex: $0) })
                        .accessibilityLabel("Label: \(label.name)")
                    }
                }
            }
        }
    }

    private var assigneesSidebarSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sidebarHeading("Assignees")
            if availableAssignees.isEmpty {
                Text("None")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(availableAssignees, id: \.nodeId) { user in
                        Toggle(isOn: assigneeBinding(for: user.nodeId)) {
                            HStack(spacing: 6) {
                                Image(systemName: "person.circle.fill")
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 14))
                                Text(user.name)
                                    .font(.system(size: 12))
                            }
                        }
                        .toggleStyle(.button)
                        .buttonStyle(.plain)
                        .accessibilityLabel("Assignee: \(user.name)")
                    }
                }
            }
        }
    }

    private var milestoneSidebarSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sidebarHeading("Milestone")
            Picker("Milestone", selection: $selectedMilestoneId) {
                Text("None").tag(String?.none)
                ForEach(availableMilestones, id: \.nodeId) { milestone in
                    Text(milestone.name).tag(Optional(milestone.nodeId))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .accessibilityLabel("Milestone")
        }
    }

    private func updatedSection(for issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sidebarHeading("Updated")
            Text(relativeTimestamp(for: issue.updatedAt))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private func sidebarHeading(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    // MARK: - Bindings

    private func labelBinding(for nodeId: String) -> Binding<Bool> {
        Binding(
            get: { selectedLabelIds.contains(nodeId) },
            set: { isOn in
                if isOn {
                    selectedLabelIds.insert(nodeId)
                } else {
                    selectedLabelIds.remove(nodeId)
                }
            }
        )
    }

    private func assigneeBinding(for nodeId: String) -> Binding<Bool> {
        Binding(
            get: { selectedAssigneeIds.contains(nodeId) },
            set: { isOn in
                if isOn {
                    selectedAssigneeIds.insert(nodeId)
                } else {
                    selectedAssigneeIds.remove(nodeId)
                }
            }
        )
    }

    // MARK: - Helpers

    private func relativeTimestamp(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Populate from Existing Issue

    private func populateFromIssue() {
        guard let issue else {
            title = ""
            issueBody = ""
            selectedLabelIds = []
            selectedAssigneeIds = []
            selectedMilestoneId = nil
            comments = []
            return
        }
        title = issue.title
        issueBody = issue.body ?? ""
    }

    // MARK: - Load Sidebar Data (from GitHub, with node IDs)

    private func loadSidebarData() async {
        guard let token = authStore.accessToken else { return }
        let parts = repository.nameWithOwner.split(separator: "/")
        guard parts.count == 2 else { return }
        let owner = String(parts[0])
        let name = String(parts[1])

        let client = GraphQLClient()

        do {
            let response: RepoFormDataResponse = try await client.execute(
                query: repoFormDataQuery,
                variables: ["owner": owner, "name": name],
                token: token
            )

            availableLabels = response.repository.labels.nodes.map {
                SelectableItem(nodeId: $0.id, name: $0.name, color: $0.color)
            }
            availableMilestones = response.repository.milestones.nodes.map {
                SelectableItem(nodeId: $0.id, name: $0.title)
            }
            availableAssignees = response.repository.collaborators?.nodes.map {
                SelectableItem(nodeId: $0.id, name: $0.login)
            } ?? []

            // Pre-select current values for existing issues
            if let issue {
                await preselectCurrentValues(for: issue)
            }
        } catch {
            // Non-fatal; pickers will be empty
        }
    }

    /// Match existing issue's labels/assignees/milestone to their node IDs.
    private func preselectCurrentValues(for issue: Issue) async {
        do {
            let (currentLabels, currentAssignees, currentMilestone) = try await database.dbQueue.read { db in
                let labels = try issue.labels.fetchAll(db)
                let assignees = try issue.assignedUsers.fetchAll(db)
                let milestone: Milestone?
                if let milestoneId = issue.milestoneId {
                    milestone = try Milestone.fetchOne(db, key: milestoneId)
                } else {
                    milestone = nil
                }
                return (labels, assignees, milestone)
            }

            // Match by name since DB has numeric IDs and sidebar has node IDs
            let labelNames = Set(currentLabels.map(\.name))
            selectedLabelIds = Set(availableLabels.filter { labelNames.contains($0.name) }.map(\.nodeId))

            let assigneeLogins = Set(currentAssignees.map(\.login))
            selectedAssigneeIds = Set(availableAssignees.filter { assigneeLogins.contains($0.name) }.map(\.nodeId))

            if let milestoneTitle = currentMilestone?.title {
                selectedMilestoneId = availableMilestones.first { $0.name == milestoneTitle }?.nodeId
            }
        } catch {
            // Non-fatal
        }
    }

    // MARK: - Load Comments

    private func loadComments(for issue: Issue) async {
        do {
            comments = try await database.dbQueue.read { db in
                try issue.comments.order(Column("createdAt").asc).fetchAll(db)
            }
        } catch {
            // Non-fatal
        }
    }

    // MARK: - Create Issue

    private func createIssue() async {
        guard let token = authStore.accessToken else { return }
        let parts = repository.nameWithOwner.split(separator: "/")
        guard parts.count == 2 else { return }
        let owner = String(parts[0])
        let name = String(parts[1])

        isCreating = true
        errorMessage = nil

        do {
            let service = GitHubSyncService()
            _ = try await service.createIssue(
                owner: owner,
                name: name,
                title: title.trimmingCharacters(in: .whitespaces),
                body: issueBody.isEmpty ? nil : issueBody,
                labelIds: Array(selectedLabelIds),
                assigneeIds: Array(selectedAssigneeIds),
                milestoneId: selectedMilestoneId,
                token: token
            )

            syncStore.startFullSync(token: token)
            navigationStore.isShowingNewIssueForm = false
        } catch {
            errorMessage = error.localizedDescription
            isCreating = false
        }
    }
}

// MARK: - Sidebar Item

/// A selectable item with a GraphQL node ID, used for labels, assignees, and milestones.
private struct SelectableItem: Identifiable {
    let nodeId: String
    let name: String
    var color: String?

    var id: String { nodeId }
}

// MARK: - Comment Row

private struct CommentRow: View {
    var comment: Comment

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("@\(comment.authorLogin ?? "unknown")")
                    .font(.system(size: 12, weight: .semibold))
                    .accessibilityLabel("Comment by \(comment.authorLogin ?? "unknown")")
                Text("·")
                    .foregroundStyle(.secondary)
                Text(relativeTimestamp)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            MarkdownBody(text: comment.body)
        }
    }

    private var relativeTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: comment.createdAt, relativeTo: Date())
    }
}

// MARK: - GraphQL Query for Sidebar Data

private let repoFormDataQuery = """
query($owner: String!, $name: String!) {
  repository(owner: $owner, name: $name) {
    labels(first: 100, orderBy: { field: NAME, direction: ASC }) {
      nodes { id name color }
    }
    milestones(first: 100, states: [OPEN], orderBy: { field: DUE_DATE, direction: ASC }) {
      nodes { id title }
    }
    collaborators(first: 100) {
      nodes { id login }
    }
  }
}
"""

// MARK: - GraphQL Response Types

private struct RepoFormDataResponse: Decodable {
    let repository: RepoFormData
}

private struct RepoFormData: Decodable {
    let labels: FormLabelNodes
    let milestones: FormMilestoneNodes
    let collaborators: FormCollaboratorNodes?
}

private struct FormLabelNodes: Decodable {
    let nodes: [FormLabelNode]
}

private struct FormLabelNode: Decodable {
    let id: String
    let name: String
    let color: String
}

private struct FormMilestoneNodes: Decodable {
    let nodes: [FormMilestoneNode]
}

private struct FormMilestoneNode: Decodable {
    let id: String
    let title: String
}

private struct FormCollaboratorNodes: Decodable {
    let nodes: [FormCollaboratorNode]
}

private struct FormCollaboratorNode: Decodable {
    let id: String
    let login: String
}
