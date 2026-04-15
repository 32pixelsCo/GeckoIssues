import Foundation
import GRDB

/// A GitHub user (used for assignees and comment authors).
struct User: Codable, Sendable {
    var id: Int64
    var login: String
    var avatarURL: String?
}

// MARK: - GRDB Conformance

extension User: FetchableRecord, PersistableRecord {
    static let databaseTableName = "users"

    static let assignees = hasMany(Assignee.self)
}
