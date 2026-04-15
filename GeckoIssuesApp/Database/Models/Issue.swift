import Foundation
import GRDB

/// A GitHub issue belonging to a repository.
struct Issue: Codable, Sendable {
    var id: Int64
    var repositoryId: Int64
    var number: Int
    var title: String
    var body: String?
    var state: IssueState
    var milestoneId: Int64?
    var authorLogin: String?
    var createdAt: Date
    var updatedAt: Date
    var closedAt: Date?
    var url: String

    enum IssueState: String, Codable, DatabaseValueConvertible, Sendable {
        case open = "OPEN"
        case closed = "CLOSED"
    }
}

// MARK: - GRDB Conformance

extension Issue: FetchableRecord, PersistableRecord {
    static let databaseTableName = "issues"

    static let repository = belongsTo(Repository.self)
    var repository: QueryInterfaceRequest<Repository> {
        request(for: Issue.repository)
    }

    static let milestone = belongsTo(Milestone.self)
    var milestone: QueryInterfaceRequest<Milestone> {
        request(for: Issue.milestone)
    }

    static let issueLabels = hasMany(IssueLabel.self)
    static let labels = hasMany(Label.self, through: issueLabels, using: IssueLabel.label)
    var labels: QueryInterfaceRequest<Label> {
        request(for: Issue.labels)
    }

    static let assignees = hasMany(Assignee.self)
    static let assignedUsers = hasMany(User.self, through: assignees, using: Assignee.user)
    var assignedUsers: QueryInterfaceRequest<User> {
        request(for: Issue.assignedUsers)
    }

    static let comments = hasMany(Comment.self)
    var comments: QueryInterfaceRequest<Comment> {
        request(for: Issue.comments)
    }
}
