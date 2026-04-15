import Foundation
import Testing
import GRDB
@testable import GeckoIssues

// Disambiguate from Testing.Issue and Testing.Comment
typealias GeckoIssue = GeckoIssues.Issue
typealias GeckoComment = GeckoIssues.Comment

@Suite("Database Schema")
struct DatabaseTests {

    // MARK: - Helpers

    private func makeDatabase() throws -> AppDatabase {
        try AppDatabase.inMemory()
    }

    private func makeAccount(id: Int64 = 1, login: String = "octocat") -> Account {
        Account(id: id, login: login, avatarURL: "https://avatars.githubusercontent.com/u/\(id)", type: .user, syncedAt: nil)
    }

    private func makeRepository(id: Int64 = 100, accountId: Int64 = 1) -> Repository {
        Repository(id: id, accountId: accountId, name: "hello-world", nameWithOwner: "octocat/hello-world", isPrivate: false, description: "A test repo", url: "https://github.com/octocat/hello-world", syncedAt: nil)
    }

    private func makeMilestone(id: Int64 = 200, repositoryId: Int64 = 100) -> Milestone {
        Milestone(id: id, repositoryId: repositoryId, number: 1, title: "v1.0", descriptionText: "First release", state: .open, dueOn: nil)
    }

    private func makeLabel(id: Int64 = 300, repositoryId: Int64 = 100) -> Label {
        Label(id: id, repositoryId: repositoryId, name: "bug", color: "d73a4a", descriptionText: "Something isn't working")
    }

    private func makeIssue(id: Int64 = 400, repositoryId: Int64 = 100, milestoneId: Int64? = nil) -> GeckoIssue {
        let now = Date()
        return GeckoIssue(id: id, repositoryId: repositoryId, number: 1, title: "Found a bug", body: "Description here", state: .open, milestoneId: milestoneId, authorLogin: "octocat", createdAt: now, updatedAt: now, closedAt: nil, url: "https://github.com/octocat/hello-world/issues/1")
    }

    private func makeUser(id: Int64 = 500, login: String = "assignee") -> User {
        User(id: id, login: login, avatarURL: nil)
    }

    private func makeComment(id: Int64 = 600, issueId: Int64 = 400) -> GeckoComment {
        let now = Date()
        return GeckoComment(id: id, issueId: issueId, authorLogin: "octocat", body: "A comment", createdAt: now, updatedAt: now)
    }

    /// Insert prerequisite records (account + repository) and return them.
    private func insertPrerequisites(in db: AppDatabase) throws -> (Account, Repository) {
        let account = makeAccount()
        let repo = makeRepository()
        try db.dbQueue.write { db in
            try account.insert(db)
            try repo.insert(db)
        }
        return (account, repo)
    }

    // MARK: - Account Tests

    @Test("Insert and fetch account")
    func accountRoundTrip() throws {
        let database = try makeDatabase()
        let account = makeAccount()

        try database.dbQueue.write { db in
            try account.insert(db)
        }

        let fetched = try database.dbQueue.read { db in
            try Account.fetchOne(db, key: account.id)
        }

        #expect(fetched != nil)
        #expect(fetched?.login == "octocat")
        #expect(fetched?.type == .user)
    }

    // MARK: - Repository Tests

    @Test("Insert and fetch repository")
    func repositoryRoundTrip() throws {
        let database = try makeDatabase()
        let (_, _) = try insertPrerequisites(in: database)

        let fetched = try database.dbQueue.read { db in
            try Repository.fetchOne(db, key: 100)
        }

        #expect(fetched != nil)
        #expect(fetched?.name == "hello-world")
        #expect(fetched?.nameWithOwner == "octocat/hello-world")
    }

    @Test("Repository belongs to account")
    func repositoryAccountAssociation() throws {
        let database = try makeDatabase()
        let (_, repo) = try insertPrerequisites(in: database)

        let account = try database.dbQueue.read { db in
            try repo.account.fetchOne(db)
        }

        #expect(account?.login == "octocat")
    }

    // MARK: - Milestone Tests

    @Test("Insert and fetch milestone")
    func milestoneRoundTrip() throws {
        let database = try makeDatabase()
        let (_, _) = try insertPrerequisites(in: database)
        let milestone = makeMilestone()

        try database.dbQueue.write { db in
            try milestone.insert(db)
        }

        let fetched = try database.dbQueue.read { db in
            try Milestone.fetchOne(db, key: milestone.id)
        }

        #expect(fetched != nil)
        #expect(fetched?.title == "v1.0")
        #expect(fetched?.state == .open)
    }

    // MARK: - Label Tests

    @Test("Insert and fetch label")
    func labelRoundTrip() throws {
        let database = try makeDatabase()
        let (_, _) = try insertPrerequisites(in: database)
        let label = makeLabel()

        try database.dbQueue.write { db in
            try label.insert(db)
        }

        let fetched = try database.dbQueue.read { db in
            try Label.fetchOne(db, key: label.id)
        }

        #expect(fetched != nil)
        #expect(fetched?.name == "bug")
        #expect(fetched?.color == "d73a4a")
    }

    // MARK: - Issue Tests

    @Test("Insert and fetch issue")
    func issueRoundTrip() throws {
        let database = try makeDatabase()
        let (_, _) = try insertPrerequisites(in: database)
        let issue = makeIssue()

        try database.dbQueue.write { db in
            try issue.insert(db)
        }

        let fetched = try database.dbQueue.read { db in
            try GeckoIssue.fetchOne(db, key: issue.id)
        }

        #expect(fetched != nil)
        #expect(fetched?.title == "Found a bug")
        #expect(fetched?.state == .open)
        #expect(fetched?.number == 1)
    }

    @Test("Issue with milestone association")
    func issueWithMilestone() throws {
        let database = try makeDatabase()
        let (_, _) = try insertPrerequisites(in: database)
        let milestone = makeMilestone()
        let issue = makeIssue(milestoneId: milestone.id)

        try database.dbQueue.write { db in
            try milestone.insert(db)
            try issue.insert(db)
        }

        let fetchedMilestone = try database.dbQueue.read { db in
            try issue.milestone.fetchOne(db)
        }

        #expect(fetchedMilestone?.title == "v1.0")
    }

    // MARK: - Issue Labels Tests

    @Test("Issue labels join table")
    func issueLabelRoundTrip() throws {
        let database = try makeDatabase()
        let (_, _) = try insertPrerequisites(in: database)
        let label = makeLabel()
        let issue = makeIssue()

        try database.dbQueue.write { db in
            try label.insert(db)
            try issue.insert(db)
            try IssueLabel(issueId: issue.id, labelId: label.id).insert(db)
        }

        let labels = try database.dbQueue.read { db in
            try issue.labels.fetchAll(db)
        }

        #expect(labels.count == 1)
        #expect(labels.first?.name == "bug")
    }

    // MARK: - User & Assignee Tests

    @Test("Insert and fetch user")
    func userRoundTrip() throws {
        let database = try makeDatabase()
        let user = makeUser()

        try database.dbQueue.write { db in
            try user.insert(db)
        }

        let fetched = try database.dbQueue.read { db in
            try User.fetchOne(db, key: user.id)
        }

        #expect(fetched != nil)
        #expect(fetched?.login == "assignee")
    }

    @Test("Issue assignees through join table")
    func assigneeRoundTrip() throws {
        let database = try makeDatabase()
        let (_, _) = try insertPrerequisites(in: database)
        let issue = makeIssue()
        let user = makeUser()

        try database.dbQueue.write { db in
            try issue.insert(db)
            try user.insert(db)
            try Assignee(issueId: issue.id, userId: user.id).insert(db)
        }

        let assignedUsers = try database.dbQueue.read { db in
            try issue.assignedUsers.fetchAll(db)
        }

        #expect(assignedUsers.count == 1)
        #expect(assignedUsers.first?.login == "assignee")
    }

    // MARK: - Comment Tests

    @Test("Insert and fetch comment")
    func commentRoundTrip() throws {
        let database = try makeDatabase()
        let (_, _) = try insertPrerequisites(in: database)
        let issue = makeIssue()
        let comment = makeComment(issueId: issue.id)

        try database.dbQueue.write { db in
            try issue.insert(db)
            try comment.insert(db)
        }

        let comments = try database.dbQueue.read { db in
            try issue.comments.fetchAll(db)
        }

        #expect(comments.count == 1)
        #expect(comments.first?.body == "A comment")
    }

    // MARK: - Cascade Delete Tests

    @Test("Deleting account cascades to repositories and issues")
    func cascadeDelete() throws {
        let database = try makeDatabase()
        let (account, _) = try insertPrerequisites(in: database)
        let issue = makeIssue()

        try database.dbQueue.write { db in
            try issue.insert(db)
            _ = try Account.deleteOne(db, key: account.id)
        }

        let repoCount = try database.dbQueue.read { db in
            try Repository.fetchCount(db)
        }
        let issueCount = try database.dbQueue.read { db in
            try GeckoIssue.fetchCount(db)
        }

        #expect(repoCount == 0)
        #expect(issueCount == 0)
    }

    // MARK: - Schema Tests

    @Test("Database creates successfully")
    func databaseCreation() throws {
        let database = try makeDatabase()

        let tableNames = try database.dbQueue.read { db in
            try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
        }

        #expect(tableNames.contains("accounts"))
        #expect(tableNames.contains("repositories"))
        #expect(tableNames.contains("issues"))
        #expect(tableNames.contains("labels"))
        #expect(tableNames.contains("issueLabels"))
        #expect(tableNames.contains("milestones"))
        #expect(tableNames.contains("users"))
        #expect(tableNames.contains("assignees"))
        #expect(tableNames.contains("comments"))
    }
}
