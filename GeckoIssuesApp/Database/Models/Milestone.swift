import Foundation
import GRDB

/// A milestone definition belonging to a repository.
struct Milestone: Codable, Sendable {
    var id: Int64
    var repositoryId: Int64
    var number: Int
    var title: String
    var descriptionText: String?
    var state: MilestoneState
    var dueOn: Date?

    enum MilestoneState: String, Codable, DatabaseValueConvertible, Sendable {
        case open = "OPEN"
        case closed = "CLOSED"
    }

    enum CodingKeys: String, CodingKey {
        case id, repositoryId, number, title, state, dueOn
        case descriptionText = "description"
    }
}

// MARK: - GRDB Conformance

extension Milestone: FetchableRecord, PersistableRecord {
    static let databaseTableName = "milestones"

    static let repository = belongsTo(Repository.self)
    var repository: QueryInterfaceRequest<Repository> {
        request(for: Milestone.repository)
    }

    static let issues = hasMany(Issue.self)
    var issues: QueryInterfaceRequest<Issue> {
        request(for: Milestone.issues)
    }
}
