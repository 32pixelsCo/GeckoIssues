import Foundation
import GRDB

/// A GitHub repository belonging to an account.
struct Repository: Codable, Sendable {
    var id: Int64
    var accountId: Int64
    var name: String
    var nameWithOwner: String
    var isPrivate: Bool
    var description: String?
    var url: String
    var syncedAt: Date?
}

// MARK: - GRDB Conformance

extension Repository: FetchableRecord, PersistableRecord {
    static let databaseTableName = "repositories"

    static let account = belongsTo(Account.self)
    var account: QueryInterfaceRequest<Account> {
        request(for: Repository.account)
    }

    static let issues = hasMany(Issue.self)
    var issues: QueryInterfaceRequest<Issue> {
        request(for: Repository.issues)
    }

    static let labels = hasMany(Label.self)
    var labels: QueryInterfaceRequest<Label> {
        request(for: Repository.labels)
    }

    static let milestones = hasMany(Milestone.self)
    var milestones: QueryInterfaceRequest<Milestone> {
        request(for: Repository.milestones)
    }
}
