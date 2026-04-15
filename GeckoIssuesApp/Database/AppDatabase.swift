import Foundation
import GRDB

/// Manages the local SQLite database for offline-first storage.
///
/// Creates the database at `~/.gecko/data.db` on first launch and runs
/// all migrations. Both the app and CLI share this same database.
struct AppDatabase: Sendable {

    /// The database connection.
    let dbQueue: DatabaseQueue

    /// Open or create the database at the default path (`~/.gecko/data.db`).
    init() throws {
        let url = AppDatabase.defaultDatabaseURL
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let dbQueue = try DatabaseQueue(path: url.path)
        try AppDatabase.migrator.migrate(dbQueue)
        self.dbQueue = dbQueue
    }

    /// Open or create a database at a custom path (useful for testing).
    init(path: String) throws {
        let dbQueue = try DatabaseQueue(path: path)
        try AppDatabase.migrator.migrate(dbQueue)
        self.dbQueue = dbQueue
    }

    /// Create an in-memory database (for tests).
    static func inMemory() throws -> AppDatabase {
        let dbQueue = try DatabaseQueue()
        try migrator.migrate(dbQueue)
        return AppDatabase(dbQueue: dbQueue)
    }

    // MARK: - Private

    private init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    /// Default database file location.
    static let defaultDatabaseURL: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".gecko/data.db")
    }()

    // MARK: - Migrations

    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1-create-schema") { db in
            // Enable foreign keys
            try db.execute(sql: "PRAGMA foreign_keys = ON")

            // accounts
            try db.create(table: "accounts") { t in
                t.primaryKey("id", .integer)
                t.column("login", .text).notNull().unique()
                t.column("avatarURL", .text)
                t.column("type", .text).notNull()
                t.column("syncedAt", .datetime)
            }

            // users (for assignees, comment authors)
            try db.create(table: "users") { t in
                t.primaryKey("id", .integer)
                t.column("login", .text).notNull().unique()
                t.column("avatarURL", .text)
            }

            // repositories
            try db.create(table: "repositories") { t in
                t.primaryKey("id", .integer)
                t.column("accountId", .integer).notNull()
                    .references("accounts", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.column("nameWithOwner", .text).notNull().unique()
                t.column("isPrivate", .boolean).notNull().defaults(to: false)
                t.column("description", .text)
                t.column("url", .text).notNull()
                t.column("syncedAt", .datetime)
            }
            try db.create(indexOn: "repositories", columns: ["accountId"])

            // milestones
            try db.create(table: "milestones") { t in
                t.primaryKey("id", .integer)
                t.column("repositoryId", .integer).notNull()
                    .references("repositories", onDelete: .cascade)
                t.column("number", .integer).notNull()
                t.column("title", .text).notNull()
                t.column("description", .text)
                t.column("state", .text).notNull()
                t.column("dueOn", .datetime)
            }
            try db.create(indexOn: "milestones", columns: ["repositoryId"])

            // labels
            try db.create(table: "labels") { t in
                t.primaryKey("id", .integer)
                t.column("repositoryId", .integer).notNull()
                    .references("repositories", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.column("color", .text).notNull()
                t.column("description", .text)
            }
            try db.create(indexOn: "labels", columns: ["repositoryId"])

            // issues
            try db.create(table: "issues") { t in
                t.primaryKey("id", .integer)
                t.column("repositoryId", .integer).notNull()
                    .references("repositories", onDelete: .cascade)
                t.column("number", .integer).notNull()
                t.column("title", .text).notNull()
                t.column("body", .text)
                t.column("state", .text).notNull()
                t.column("milestoneId", .integer)
                    .references("milestones", onDelete: .setNull)
                t.column("authorLogin", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.column("closedAt", .datetime)
                t.column("url", .text).notNull()
                t.uniqueKey(["repositoryId", "number"])
            }
            try db.create(indexOn: "issues", columns: ["repositoryId"])
            try db.create(indexOn: "issues", columns: ["milestoneId"])

            // issueLabels (join table)
            try db.create(table: "issueLabels") { t in
                t.column("issueId", .integer).notNull()
                    .references("issues", onDelete: .cascade)
                t.column("labelId", .integer).notNull()
                    .references("labels", onDelete: .cascade)
                t.primaryKey(["issueId", "labelId"])
            }

            // assignees (join table)
            try db.create(table: "assignees") { t in
                t.column("issueId", .integer).notNull()
                    .references("issues", onDelete: .cascade)
                t.column("userId", .integer).notNull()
                    .references("users", onDelete: .cascade)
                t.primaryKey(["issueId", "userId"])
            }

            // comments
            try db.create(table: "comments") { t in
                t.primaryKey("id", .integer)
                t.column("issueId", .integer).notNull()
                    .references("issues", onDelete: .cascade)
                t.column("authorLogin", .text)
                t.column("body", .text).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            try db.create(indexOn: "comments", columns: ["issueId"])
        }

        return migrator
    }
}
