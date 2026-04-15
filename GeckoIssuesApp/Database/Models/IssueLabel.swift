import Foundation
import GRDB

/// Join table linking issues to labels.
struct IssueLabel: Codable, Sendable {
    var issueId: Int64
    var labelId: Int64
}

// MARK: - GRDB Conformance

extension IssueLabel: FetchableRecord, PersistableRecord {
    static let databaseTableName = "issueLabels"

    static let issue = belongsTo(Issue.self)
    var issue: QueryInterfaceRequest<Issue> {
        request(for: IssueLabel.issue)
    }

    static let label = belongsTo(Label.self)
    var label: QueryInterfaceRequest<Label> {
        request(for: IssueLabel.label)
    }
}
