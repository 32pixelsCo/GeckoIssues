import Foundation
import GRDB

/// A GitHub user or organization account.
struct Account: Codable, Sendable {
    var id: Int64
    var login: String
    var avatarURL: String?
    var type: AccountType
    var syncedAt: Date?

    enum AccountType: String, Codable, DatabaseValueConvertible, Sendable {
        case user = "User"
        case organization = "Organization"
    }
}

// MARK: - GRDB Conformance

extension Account: FetchableRecord, PersistableRecord {
    static let databaseTableName = "accounts"

    static let repositories = hasMany(Repository.self)
    var repositories: QueryInterfaceRequest<Repository> {
        request(for: Account.repositories)
    }
}
