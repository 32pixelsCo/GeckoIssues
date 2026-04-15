import Foundation
import GRDB

/// A comment on a GitHub issue.
struct Comment: Codable, Sendable {
    var id: Int64
    var issueId: Int64
    var authorLogin: String?
    var body: String
    var createdAt: Date
    var updatedAt: Date
}

// MARK: - GRDB Conformance

extension Comment: FetchableRecord, PersistableRecord {
    static let databaseTableName = "comments"

    static let issue = belongsTo(Issue.self)
    var issue: QueryInterfaceRequest<Issue> {
        request(for: Comment.issue)
    }
}
