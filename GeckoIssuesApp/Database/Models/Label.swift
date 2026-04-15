import Foundation
import GRDB

/// A label definition belonging to a repository.
struct Label: Codable, Sendable {
    var id: Int64
    var repositoryId: Int64
    var name: String
    var color: String
    var descriptionText: String?

    enum CodingKeys: String, CodingKey {
        case id, repositoryId, name, color
        case descriptionText = "description"
    }
}

// MARK: - GRDB Conformance

extension Label: FetchableRecord, PersistableRecord {
    static let databaseTableName = "labels"

    static let repository = belongsTo(Repository.self)
    var repository: QueryInterfaceRequest<Repository> {
        request(for: Label.repository)
    }

    static let issueLabels = hasMany(IssueLabel.self)
    static let issues = hasMany(Issue.self, through: issueLabels, using: IssueLabel.issue)
    var issues: QueryInterfaceRequest<Issue> {
        request(for: Label.issues)
    }
}
