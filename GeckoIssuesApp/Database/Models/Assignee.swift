import Foundation
import GRDB

/// Join table linking issues to assigned users.
struct Assignee: Codable, Sendable {
    var issueId: Int64
    var userId: Int64
}

// MARK: - GRDB Conformance

extension Assignee: FetchableRecord, PersistableRecord {
    static let databaseTableName = "assignees"

    static let issue = belongsTo(Issue.self)
    var issue: QueryInterfaceRequest<Issue> {
        request(for: Assignee.issue)
    }

    static let user = belongsTo(User.self)
    var user: QueryInterfaceRequest<User> {
        request(for: Assignee.user)
    }
}
