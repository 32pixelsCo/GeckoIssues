import SwiftUI
import GRDB

/// Displays a full issue detail: title, state badge, rendered markdown body,
/// and a right sidebar with labels, assignees, milestone, and timestamp.
struct IssueDetailView: View {
    var issue: Issue
    var database: AppDatabase

    @State private var labels: [Label] = []
    @State private var assignees: [User] = []
    @State private var milestone: Milestone?
    @State private var comments: [Comment] = []

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            mainContent
            Divider()
            sidebar
        }
        .task(id: issue.id) {
            await loadDetail()
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                issueHeader
                if let body = issue.body, !body.isEmpty {
                    MarkdownBody(text: body)
                } else {
                    Text("No description provided.")
                        .foregroundStyle(.secondary)
                        .italic()
                }
                if !comments.isEmpty {
                    commentsSection
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Issue Header

    private var issueHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                stateBadge
                Text("#\(issue.number)")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13, design: .monospaced))
            }
            Text(issue.title)
                .font(.title2.bold())
                .textSelection(.enabled)
            Divider()
        }
    }

    private var stateBadge: some View {
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

    // MARK: - Sidebar

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !labels.isEmpty {
                    labelsSection
                }
                if !assignees.isEmpty {
                    assigneesSection
                }
                if let milestone {
                    milestoneSection(milestone)
                }
                updatedSection
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 200)
    }

    private var labelsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sidebarHeading("Labels")
            VStack(alignment: .leading, spacing: 4) {
                ForEach(labels, id: \.id) { label in
                    LabelBadge(label: label)
                }
            }
        }
    }

    private var assigneesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sidebarHeading("Assignees")
            VStack(alignment: .leading, spacing: 4) {
                ForEach(assignees, id: \.id) { user in
                    HStack(spacing: 6) {
                        Image(systemName: "person.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 16))
                        Text(user.login)
                            .font(.system(size: 12))
                    }
                    .accessibilityLabel("Assigned to \(user.login)")
                }
            }
        }
    }

    private func milestoneSection(_ milestone: Milestone) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sidebarHeading("Milestone")
            HStack(spacing: 4) {
                Image(systemName: "signpost.right.fill")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
                Text(milestone.title)
                    .font(.system(size: 12))
            }
        }
    }

    private var updatedSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sidebarHeading("Updated")
            Text(relativeTimestamp)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private func sidebarHeading(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    // MARK: - Helpers

    private var relativeTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: issue.updatedAt, relativeTo: Date())
    }

    // MARK: - Data Loading

    private func loadDetail() async {
        do {
            let (loadedLabels, loadedAssignees, loadedMilestone, loadedComments) = try await database.dbQueue.read { db in
                let labels = try issue.labels.fetchAll(db)
                let assignees = try issue.assignedUsers.fetchAll(db)
                let milestone: Milestone?
                if let milestoneId = issue.milestoneId {
                    milestone = try Milestone.fetchOne(db, key: milestoneId)
                } else {
                    milestone = nil
                }
                let comments = try issue.comments.order(Column("createdAt").asc).fetchAll(db)
                return (labels, assignees, milestone, comments)
            }
            labels = loadedLabels
            assignees = loadedAssignees
            milestone = loadedMilestone
            comments = loadedComments
        } catch {
            // Non-fatal; sidebar stays empty
        }
    }
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
