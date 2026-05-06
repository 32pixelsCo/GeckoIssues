import SwiftUI
import GRDB

/// Form for creating a new GitHub issue, displayed in the detail column.
struct NewIssueView: View {
    var repository: Repository
    var appStore: AppStore
    var navigationStore: NavigationStore
    var syncStore: SyncStore
    var authStore: AuthStore
    var database: AppDatabase

    @State private var title = ""
    @State private var issueBody = ""
    @State private var selectedLabelIds: Set<String> = []
    @State private var selectedAssigneeIds: Set<String> = []
    @State private var selectedMilestoneId: String?

    @State private var availableLabels: [SelectableLabel] = []
    @State private var availableAssignees: [SelectableUser] = []
    @State private var availableMilestones: [SelectableMilestone] = []

    @State private var isLoading = false
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                formContent
                    .padding(20)
            }
            Divider()
            footer
        }
        .frame(minWidth: 300)
        .task {
            await loadFormData()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("New Issue")
                .font(.headline)
            Spacer()
            Button {
                navigationStore.isShowingNewIssueForm = false
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close new issue form")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Form Content

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            VStack(alignment: .leading, spacing: 4) {
                Text("Title")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("Issue title", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Issue title")
            }

            // Body
            VStack(alignment: .leading, spacing: 4) {
                Text("Body")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextEditor(text: $issueBody)
                    .font(.body)
                    .frame(minHeight: 150)
                    .border(Color(nsColor: .separatorColor))
                    .accessibilityLabel("Issue body, supports markdown")
            }

            // Labels
            VStack(alignment: .leading, spacing: 4) {
                Text("Labels")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                labelPicker
            }

            // Assignees
            VStack(alignment: .leading, spacing: 4) {
                Text("Assignees")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                assigneePicker
            }

            // Milestone
            VStack(alignment: .leading, spacing: 4) {
                Text("Milestone")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                milestonePicker
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
    }

    // MARK: - Pickers

    private var labelPicker: some View {
        FlowLayout(spacing: 6) {
            ForEach(availableLabels, id: \.nodeId) { label in
                Toggle(isOn: Binding(
                    get: { selectedLabelIds.contains(label.nodeId) },
                    set: { isOn in
                        if isOn {
                            selectedLabelIds.insert(label.nodeId)
                        } else {
                            selectedLabelIds.remove(label.nodeId)
                        }
                    }
                )) {
                    Text(label.name)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                }
                .toggleStyle(.button)
                .buttonStyle(.bordered)
                .tint(label.swiftUIColor)
                .accessibilityLabel("Label: \(label.name)")
            }
        }
    }

    private var assigneePicker: some View {
        FlowLayout(spacing: 6) {
            ForEach(availableAssignees, id: \.nodeId) { user in
                Toggle(isOn: Binding(
                    get: { selectedAssigneeIds.contains(user.nodeId) },
                    set: { isOn in
                        if isOn {
                            selectedAssigneeIds.insert(user.nodeId)
                        } else {
                            selectedAssigneeIds.remove(user.nodeId)
                        }
                    }
                )) {
                    Text(user.login)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                }
                .toggleStyle(.button)
                .buttonStyle(.bordered)
                .accessibilityLabel("Assignee: \(user.login)")
            }
        }
    }

    private var milestonePicker: some View {
        Picker("Milestone", selection: $selectedMilestoneId) {
            Text("None").tag(String?.none)
            ForEach(availableMilestones, id: \.nodeId) { milestone in
                Text(milestone.title).tag(Optional(milestone.nodeId))
            }
        }
        .labelsHidden()
        .accessibilityLabel("Milestone")
    }

    // MARK: - Footer

    private var footer: some View {
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
    }

    // MARK: - Data Loading

    private func loadFormData() async {
        guard let token = authStore.accessToken else { return }
        isLoading = true
        defer { isLoading = false }

        let parts = repository.nameWithOwner.split(separator: "/")
        guard parts.count == 2 else { return }
        let owner = String(parts[0])
        let name = String(parts[1])

        let client = GraphQLClient()

        // Fetch labels, milestones, and collaborators with their node IDs
        do {
            let response: RepoFormDataResponse = try await client.execute(
                query: repoFormDataQuery,
                variables: ["owner": owner, "name": name],
                token: token
            )

            availableLabels = response.repository.labels.nodes.map {
                SelectableLabel(nodeId: $0.id, name: $0.name, color: $0.color)
            }
            availableMilestones = response.repository.milestones.nodes.map {
                SelectableMilestone(nodeId: $0.id, title: $0.title)
            }
            availableAssignees = response.repository.collaborators?.nodes.map {
                SelectableUser(nodeId: $0.id, login: $0.login)
            } ?? []
        } catch {
            // Non-fatal; pickers will be empty
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

            // Trigger sync to pull the new issue into the local DB
            syncStore.startFullSync(token: token)

            // Close the form
            navigationStore.isShowingNewIssueForm = false
        } catch {
            errorMessage = error.localizedDescription
            isCreating = false
        }
    }
}

// MARK: - Form Data Types

private struct SelectableLabel {
    let nodeId: String
    let name: String
    let color: String

    var swiftUIColor: Color {
        Color(hex: color)
    }
}

private struct SelectableUser {
    let nodeId: String
    let login: String
}

private struct SelectableMilestone {
    let nodeId: String
    let title: String
}

// MARK: - GraphQL Query for Form Data

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
    let labels: LabelNodes
    let milestones: MilestoneNodes
    let collaborators: CollaboratorNodes?
}

private struct LabelNodes: Decodable {
    let nodes: [LabelNode]
}

private struct LabelNode: Decodable {
    let id: String
    let name: String
    let color: String
}

private struct MilestoneNodes: Decodable {
    let nodes: [MilestoneNode]
}

private struct MilestoneNode: Decodable {
    let id: String
    let title: String
}

private struct CollaboratorNodes: Decodable {
    let nodes: [CollaboratorNode]
}

private struct CollaboratorNode: Decodable {
    let id: String
    let login: String
}

// MARK: - Flow Layout

/// A simple flow layout that wraps items to the next line when they exceed the available width.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(subviews: subviews, containerWidth: proposal.width ?? .infinity)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, containerWidth: bounds.width)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(subviews[index].sizeThatFits(.unspecified))
            )
        }
    }

    private func layout(subviews: Subviews, containerWidth: CGFloat) -> LayoutResult {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > containerWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return LayoutResult(
            positions: positions,
            size: CGSize(width: containerWidth, height: y + rowHeight)
        )
    }

    private struct LayoutResult {
        var positions: [CGPoint]
        var size: CGSize
    }
}

