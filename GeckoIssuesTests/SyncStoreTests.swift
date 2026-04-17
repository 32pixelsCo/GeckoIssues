import Foundation
import Testing
import GRDB
@testable import GeckoIssues

// MARK: - Mock Sync Service

struct MockSyncService: SyncServiceProtocol, Sendable {
    var viewer: GitHubSyncService.ViewerData
    var organizations: [GitHubSyncService.OrganizationData] = []
    var repositories: [GitHubSyncService.RepositoryData]
    var orgRepositories: [String: [GitHubSyncService.RepositoryData]] = [:]
    var issuesByRepo: [String: [GitHubSyncService.IssueData]]

    func fetchViewer(token: String) async throws -> GitHubSyncService.ViewerData {
        viewer
    }

    func fetchViewerWithOrganizations(token: String) async throws -> GitHubSyncService.ViewerWithOrganizationsData {
        GitHubSyncService.ViewerWithOrganizationsData(viewer: viewer, organizations: organizations)
    }

    func fetchRepositories(token: String) async throws -> [GitHubSyncService.RepositoryData] {
        repositories
    }

    func fetchOrganizationRepositories(login: String, token: String) async throws -> [GitHubSyncService.RepositoryData] {
        orgRepositories[login] ?? []
    }

    func fetchIssues(owner: String, name: String, token: String) async throws -> [GitHubSyncService.IssueData] {
        issuesByRepo["\(owner)/\(name)"] ?? []
    }
}

struct FailingSyncService: SyncServiceProtocol, Sendable {
    let error: Error

    func fetchViewer(token: String) async throws -> GitHubSyncService.ViewerData {
        throw error
    }

    func fetchViewerWithOrganizations(token: String) async throws -> GitHubSyncService.ViewerWithOrganizationsData {
        throw error
    }

    func fetchRepositories(token: String) async throws -> [GitHubSyncService.RepositoryData] {
        throw error
    }

    func fetchOrganizationRepositories(login: String, token: String) async throws -> [GitHubSyncService.RepositoryData] {
        throw error
    }

    func fetchIssues(owner: String, name: String, token: String) async throws -> [GitHubSyncService.IssueData] {
        throw error
    }
}

// MARK: - Test Helpers

private func makeViewerData() -> GitHubSyncService.ViewerData {
    GitHubSyncService.ViewerData(databaseId: 1, login: "octocat", avatarUrl: "https://avatar.test/1")
}

private func makeOwnerData(id: Int64 = 1, login: String = "octocat") -> GitHubSyncService.OwnerData {
    GitHubSyncService.OwnerData(databaseId: id, login: login, avatarUrl: "https://avatar.test/\(id)", typeName: "User")
}

private func makeRepoData(
    id: Int64 = 100,
    name: String = "hello-world",
    owner: GitHubSyncService.OwnerData? = nil
) -> GitHubSyncService.RepositoryData {
    GitHubSyncService.RepositoryData(
        databaseId: id,
        name: name,
        nameWithOwner: "\(owner?.login ?? "octocat")/\(name)",
        isPrivate: false,
        description: "A test repo",
        url: "https://github.com/octocat/\(name)",
        owner: owner ?? makeOwnerData()
    )
}

private func makeIssueData(
    id: Int64 = 400,
    number: Int = 1,
    state: String = "OPEN",
    milestone: GitHubSyncService.MilestoneData? = nil,
    labels: [GitHubSyncService.LabelData] = [],
    assignees: [GitHubSyncService.UserData] = [],
    comments: [GitHubSyncService.CommentData] = []
) -> GitHubSyncService.IssueData {
    GitHubSyncService.IssueData(
        databaseId: id,
        number: number,
        title: "Issue #\(number)",
        body: "Body for issue \(number)",
        state: state,
        url: "https://github.com/octocat/hello-world/issues/\(number)",
        createdAt: "2024-01-15T10:30:00Z",
        updatedAt: "2024-01-16T12:00:00Z",
        closedAt: state == "CLOSED" ? "2024-01-16T12:00:00Z" : nil,
        authorLogin: "octocat",
        milestone: milestone,
        labels: labels,
        assignees: assignees,
        comments: comments
    )
}

private func makeMilestoneData(id: Int64 = 200) -> GitHubSyncService.MilestoneData {
    GitHubSyncService.MilestoneData(
        databaseId: id,
        number: 1,
        title: "v1.0",
        description: "First release",
        state: "OPEN",
        dueOn: "2024-06-01T00:00:00Z"
    )
}

private func makeLabelData(id: Int64 = 300) -> GitHubSyncService.LabelData {
    GitHubSyncService.LabelData(databaseId: id, name: "bug", color: "d73a4a", description: "Something broken")
}

private func makeUserData(id: Int64 = 500, login: String = "assignee") -> GitHubSyncService.UserData {
    GitHubSyncService.UserData(databaseId: id, login: login, avatarUrl: nil)
}

private func makeCommentData(id: Int64 = 600) -> GitHubSyncService.CommentData {
    GitHubSyncService.CommentData(
        databaseId: id,
        authorLogin: "commenter",
        body: "A comment",
        createdAt: "2024-01-15T11:00:00Z",
        updatedAt: "2024-01-15T11:00:00Z"
    )
}

// MARK: - Tests

@Suite("SyncStore")
struct SyncStoreTests {

    @Test("Full sync persists account, repos, issues, labels, milestones, assignees, comments")
    @MainActor
    func fullSyncPersistsAllData() async throws {
        let db = try AppDatabase.inMemory()
        let milestone = makeMilestoneData()
        let label = makeLabelData()
        let assignee = makeUserData()
        let comment = makeCommentData()
        let issue = makeIssueData(
            milestone: milestone,
            labels: [label],
            assignees: [assignee],
            comments: [comment]
        )

        let mock = MockSyncService(
            viewer: makeViewerData(),
            repositories: [makeRepoData()],
            issuesByRepo: ["octocat/hello-world": [issue]]
        )

        let store = SyncStore(database: db, syncService: mock)
        store.startFullSync(token: "test-token")

        // Wait for sync to complete
        while true {
            try await Task.sleep(for: .milliseconds(50))
            if case .completed = store.state { break }
            if case .error(let msg) = store.state { throw SyncTestError.syncFailed(msg) }
        }

        // Verify account
        let accounts = try await db.dbQueue.read { db in
            try Account.fetchAll(db)
        }
        #expect(accounts.count == 1)
        #expect(accounts[0].login == "octocat")

        // Verify repository
        let repos = try await db.dbQueue.read { db in
            try Repository.fetchAll(db)
        }
        #expect(repos.count == 1)
        #expect(repos[0].name == "hello-world")
        #expect(repos[0].syncedAt != nil)

        // Verify milestone
        let milestones = try await db.dbQueue.read { db in
            try Milestone.fetchAll(db)
        }
        #expect(milestones.count == 1)
        #expect(milestones[0].title == "v1.0")

        // Verify label
        let labels = try await db.dbQueue.read { db in
            try GeckoIssues.Label.fetchAll(db)
        }
        #expect(labels.count == 1)
        #expect(labels[0].name == "bug")

        // Verify issue
        let issues = try await db.dbQueue.read { db in
            try GeckoIssues.Issue.fetchAll(db)
        }
        #expect(issues.count == 1)
        #expect(issues[0].title == "Issue #1")
        #expect(issues[0].state == .open)
        #expect(issues[0].milestoneId == 200)

        // Verify assignee join
        let assignees = try await db.dbQueue.read { db in
            try Assignee.fetchAll(db)
        }
        #expect(assignees.count == 1)
        #expect(assignees[0].userId == 500)

        // Verify issue label join
        let issueLabels = try await db.dbQueue.read { db in
            try IssueLabel.fetchAll(db)
        }
        #expect(issueLabels.count == 1)
        #expect(issueLabels[0].labelId == 300)

        // Verify comment
        let comments = try await db.dbQueue.read { db in
            try GeckoIssues.Comment.fetchAll(db)
        }
        #expect(comments.count == 1)
        #expect(comments[0].body == "A comment")
    }

    @Test("Sync state transitions through expected phases")
    @MainActor
    func syncStateTransitions() async throws {
        let db = try AppDatabase.inMemory()
        let mock = MockSyncService(
            viewer: makeViewerData(),
            repositories: [makeRepoData()],
            issuesByRepo: ["octocat/hello-world": []]
        )

        let store = SyncStore(database: db, syncService: mock)
        #expect(store.state == .idle)

        store.startFullSync(token: "test-token")

        // Wait for completion
        while true {
            try await Task.sleep(for: .milliseconds(50))
            if case .completed = store.state { break }
            if case .error(let msg) = store.state { throw SyncTestError.syncFailed(msg) }
        }

        if case .completed = store.state {
            // Expected
        } else {
            #expect(Bool(false), "Expected .completed state")
        }
    }

    @Test("API error sets state to .error without corrupting database")
    @MainActor
    func apiErrorSetsErrorState() async throws {
        let db = try AppDatabase.inMemory()
        let failing = FailingSyncService(error: GraphQLClientError.unauthorized)
        let store = SyncStore(database: db, syncService: failing)

        store.startFullSync(token: "bad-token")

        // Wait for error state
        while true {
            try await Task.sleep(for: .milliseconds(50))
            if case .error = store.state { break }
            if case .completed = store.state {
                throw SyncTestError.syncFailed("Expected error but got completed")
            }
        }

        if case .error = store.state {
            #expect(store.errorMessage != nil)
        } else {
            #expect(Bool(false), "Expected .error state")
        }

        // DB should be empty — no partial data
        let accounts = try await db.dbQueue.read { db in
            try Account.fetchAll(db)
        }
        #expect(accounts.isEmpty)
    }

    @Test("Re-sync updates existing records (upsert)")
    @MainActor
    func reSyncUpdatesExistingRecords() async throws {
        let db = try AppDatabase.inMemory()
        let issue1 = makeIssueData(id: 400, number: 1)

        let mock1 = MockSyncService(
            viewer: makeViewerData(),
            repositories: [makeRepoData()],
            issuesByRepo: ["octocat/hello-world": [issue1]]
        )

        // First sync
        let store1 = SyncStore(database: db, syncService: mock1)
        store1.startFullSync(token: "token")
        while true {
            try await Task.sleep(for: .milliseconds(50))
            if case .completed = store1.state { break }
            if case .error(let msg) = store1.state { throw SyncTestError.syncFailed(msg) }
        }

        // Second sync with updated issue title
        let issue2 = GitHubSyncService.IssueData(
            databaseId: 400,
            number: 1,
            title: "Updated title",
            body: "Updated body",
            state: "CLOSED",
            url: "https://github.com/octocat/hello-world/issues/1",
            createdAt: "2024-01-15T10:30:00Z",
            updatedAt: "2024-01-17T08:00:00Z",
            closedAt: "2024-01-17T08:00:00Z",
            authorLogin: "octocat",
            milestone: nil,
            labels: [],
            assignees: [],
            comments: []
        )

        let mock2 = MockSyncService(
            viewer: makeViewerData(),
            repositories: [makeRepoData()],
            issuesByRepo: ["octocat/hello-world": [issue2]]
        )

        let store2 = SyncStore(database: db, syncService: mock2)
        store2.startFullSync(token: "token")
        while true {
            try await Task.sleep(for: .milliseconds(50))
            if case .completed = store2.state { break }
            if case .error(let msg) = store2.state { throw SyncTestError.syncFailed(msg) }
        }

        // Should still have exactly 1 issue, but updated
        let issues = try await db.dbQueue.read { db in
            try GeckoIssues.Issue.fetchAll(db)
        }
        #expect(issues.count == 1)
        #expect(issues[0].title == "Updated title")
        #expect(issues[0].state == .closed)
    }

    @Test("Sync handles closed issues")
    @MainActor
    func syncHandlesClosedIssues() async throws {
        let db = try AppDatabase.inMemory()
        let openIssue = makeIssueData(id: 400, number: 1, state: "OPEN")
        let closedIssue = makeIssueData(id: 401, number: 2, state: "CLOSED")

        let mock = MockSyncService(
            viewer: makeViewerData(),
            repositories: [makeRepoData()],
            issuesByRepo: ["octocat/hello-world": [openIssue, closedIssue]]
        )

        let store = SyncStore(database: db, syncService: mock)
        store.startFullSync(token: "token")

        while true {
            try await Task.sleep(for: .milliseconds(50))
            if case .completed = store.state { break }
            if case .error(let msg) = store.state { throw SyncTestError.syncFailed(msg) }
        }

        let issues = try await db.dbQueue.read { db in
            try GeckoIssues.Issue.fetchAll(db)
        }
        #expect(issues.count == 2)

        let states = Set(issues.map(\.state))
        #expect(states.contains(.open))
        #expect(states.contains(.closed))
    }

    @Test("Sync handles multiple repositories")
    @MainActor
    func syncHandlesMultipleRepos() async throws {
        let db = try AppDatabase.inMemory()
        let owner = makeOwnerData()
        let repo1 = makeRepoData(id: 100, name: "repo-one", owner: owner)
        let repo2 = makeRepoData(id: 101, name: "repo-two", owner: owner)

        let issue1 = makeIssueData(id: 400, number: 1)
        let issue2 = makeIssueData(id: 401, number: 1)

        let mock = MockSyncService(
            viewer: makeViewerData(),
            repositories: [repo1, repo2],
            issuesByRepo: [
                "octocat/repo-one": [issue1],
                "octocat/repo-two": [issue2]
            ]
        )

        let store = SyncStore(database: db, syncService: mock)
        store.startFullSync(token: "token")

        while true {
            try await Task.sleep(for: .milliseconds(50))
            if case .completed = store.state { break }
            if case .error(let msg) = store.state { throw SyncTestError.syncFailed(msg) }
        }

        let repos = try await db.dbQueue.read { db in
            try Repository.fetchAll(db)
        }
        #expect(repos.count == 2)

        let issues = try await db.dbQueue.read { db in
            try GeckoIssues.Issue.fetchAll(db)
        }
        #expect(issues.count == 2)

        // Both repos should be marked as synced
        #expect(repos.allSatisfy { $0.syncedAt != nil })
    }

    @Test("Preventing duplicate sync when already syncing")
    @MainActor
    func preventsDuplicateSync() async throws {
        let db = try AppDatabase.inMemory()
        let mock = MockSyncService(
            viewer: makeViewerData(),
            repositories: [],
            issuesByRepo: [:]
        )

        let store = SyncStore(database: db, syncService: mock)
        store.startFullSync(token: "token")

        // Immediately try starting another sync — should be ignored
        store.startFullSync(token: "token")

        while true {
            try await Task.sleep(for: .milliseconds(50))
            if case .completed = store.state { break }
            if case .error(let msg) = store.state { throw SyncTestError.syncFailed(msg) }
        }
    }

    @Test("Sync with organization owner creates org account")
    @MainActor
    func syncCreatesOrgAccount() async throws {
        let db = try AppDatabase.inMemory()
        let orgOwner = GitHubSyncService.OwnerData(
            databaseId: 2,
            login: "my-org",
            avatarUrl: nil,
            typeName: "Organization"
        )
        let repo = makeRepoData(id: 100, name: "org-repo", owner: orgOwner)

        let mock = MockSyncService(
            viewer: makeViewerData(),
            repositories: [repo],
            issuesByRepo: ["my-org/org-repo": []]
        )

        let store = SyncStore(database: db, syncService: mock)
        store.startFullSync(token: "token")

        while true {
            try await Task.sleep(for: .milliseconds(50))
            if case .completed = store.state { break }
            if case .error(let msg) = store.state { throw SyncTestError.syncFailed(msg) }
        }

        let accounts = try await db.dbQueue.read { db in
            try Account.fetchAll(db)
        }
        // Viewer account + org account
        #expect(accounts.count == 2)

        let org = accounts.first { $0.login == "my-org" }
        #expect(org?.type == .organization)
    }
    @Test("Sync fetches additional org repos not returned by viewer query")
    @MainActor
    func syncFetchesOrgRepos() async throws {
        let db = try AppDatabase.inMemory()
        let orgOwner = GitHubSyncService.OwnerData(
            databaseId: 2,
            login: "my-org",
            avatarUrl: nil,
            typeName: "Organization"
        )

        // Viewer query returns only one org repo
        let viewerRepo = makeRepoData(id: 100, name: "repo-a", owner: orgOwner)

        // Org query returns that repo plus two more
        let orgRepoB = makeRepoData(id: 101, name: "repo-b", owner: orgOwner)
        let orgRepoC = makeRepoData(id: 102, name: "repo-c", owner: orgOwner)

        let mock = MockSyncService(
            viewer: makeViewerData(),
            repositories: [viewerRepo],
            orgRepositories: ["my-org": [viewerRepo, orgRepoB, orgRepoC]],
            issuesByRepo: [:]
        )

        let store = SyncStore(database: db, syncService: mock)
        store.startFullSync(token: "token")

        while true {
            try await Task.sleep(for: .milliseconds(50))
            if case .completed = store.state { break }
            if case .error(let msg) = store.state { throw SyncTestError.syncFailed(msg) }
        }

        let repos = try await db.dbQueue.read { db in
            try Repository.fetchAll(db)
        }
        // Should have all 3 repos (1 from viewer + 2 new from org, no duplicates)
        #expect(repos.count == 3)

        let names = Set(repos.map(\.name))
        #expect(names == ["repo-a", "repo-b", "repo-c"])
    }
}

// MARK: - Test Error

private enum SyncTestError: Error {
    case syncFailed(String)
}
