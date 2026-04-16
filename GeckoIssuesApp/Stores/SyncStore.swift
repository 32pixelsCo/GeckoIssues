import Foundation
import GRDB
import os

/// Manages GitHub sync lifecycle, background refresh, and online/offline state.
@MainActor @Observable
final class SyncStore {

    // MARK: - Types

    enum SyncState: Equatable {
        case idle
        case syncing(SyncProgress)
        case completed(Date)
        case error(String)
    }

    struct SyncProgress: Equatable {
        var phase: SyncPhase
        var repositoriesSynced: Int
        var repositoriesTotal: Int
    }

    enum SyncPhase: Equatable {
        case fetchingAccount
        case fetchingRepositories
        case syncingRepository(String)
    }

    // MARK: - Properties

    private(set) var state: SyncState = .idle
    var errorMessage: String?

    // MARK: - Dependencies

    private let database: AppDatabase
    private let syncService: any SyncServiceProtocol
    private let logger = Logger(subsystem: "com.32pixels.GeckoIssues", category: "SyncStore")

    // MARK: - Internal

    private var syncTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        database: AppDatabase,
        syncService: any SyncServiceProtocol = GitHubSyncService()
    ) {
        self.database = database
        self.syncService = syncService
    }

    // MARK: - Full Sync

    /// Start a full sync of all repositories and issues from GitHub.
    func startFullSync(token: String) {
        if case .syncing = state { return }

        errorMessage = nil
        syncTask = Task {
            do {
                // Step 1: Fetch viewer
                state = .syncing(SyncProgress(
                    phase: .fetchingAccount,
                    repositoriesSynced: 0,
                    repositoriesTotal: 0
                ))
                logger.info("Starting full sync")

                let viewer = try await syncService.fetchViewer(token: token)
                try Task.checkCancellation()

                // Step 2: Fetch all repositories
                state = .syncing(SyncProgress(
                    phase: .fetchingRepositories,
                    repositoriesSynced: 0,
                    repositoriesTotal: 0
                ))

                var repos = try await syncService.fetchRepositories(token: token)
                try Task.checkCancellation()
                logger.info("Fetched \(repos.count) repositories from viewer")

                // Step 2b: Discover org accounts and fetch their repos directly
                var seenRepoIds = Set(repos.map(\.databaseId))
                let orgLogins = Set(
                    repos
                        .filter { $0.owner.typeName == "Organization" }
                        .map(\.owner.login)
                )
                for orgLogin in orgLogins {
                    try Task.checkCancellation()
                    do {
                        let orgRepos = try await syncService.fetchOrganizationRepositories(
                            login: orgLogin,
                            token: token
                        )
                        var newCount = 0
                        for repo in orgRepos where !seenRepoIds.contains(repo.databaseId) {
                            seenRepoIds.insert(repo.databaseId)
                            repos.append(repo)
                            newCount += 1
                        }
                        if newCount > 0 {
                            logger.info("Fetched \(newCount) additional repos from org \(orgLogin)")
                        }
                    } catch {
                        // Non-fatal: org query may fail if token lacks permission
                        logger.warning("Failed to fetch repos for org \(orgLogin): \(error.localizedDescription)")
                    }
                }

                logger.info("Total repositories: \(repos.count)")

                // Step 3: Save account + repos
                try await persistAccountsAndRepos(viewer: viewer, repos: repos)

                // Step 4: For each repo, fetch and persist issues
                for (index, repo) in repos.enumerated() {
                    try Task.checkCancellation()

                    state = .syncing(SyncProgress(
                        phase: .syncingRepository(repo.nameWithOwner),
                        repositoriesSynced: index,
                        repositoriesTotal: repos.count
                    ))

                    let parts = repo.nameWithOwner.split(separator: "/", maxSplits: 1)
                    let owner = String(parts[0])
                    let name = String(parts[1])

                    let issues = try await syncService.fetchIssues(
                        owner: owner,
                        name: name,
                        token: token
                    )
                    logger.info("Fetched \(issues.count) issues for \(repo.nameWithOwner)")

                    try await persistIssues(issues, repositoryId: repo.databaseId)
                }

                let completedAt = Date()
                state = .completed(completedAt)
                logger.info("Full sync completed")

            } catch is CancellationError {
                state = .idle
                logger.info("Sync cancelled")
            } catch {
                // URLSession and GRDB may wrap CancellationError
                if Task.isCancelled {
                    state = .idle
                    logger.info("Sync cancelled")
                } else {
                    let message = error.localizedDescription
                    state = .error(message)
                    errorMessage = message
                    logger.error("Sync failed: \(message)")
                }
            }
        }
    }

    /// Cancel an in-progress sync.
    func cancelSync() {
        syncTask?.cancel()
        syncTask = nil
    }

    // MARK: - Persistence

    private func persistAccountsAndRepos(
        viewer: GitHubSyncService.ViewerData,
        repos: [GitHubSyncService.RepositoryData]
    ) async throws {
        try await database.dbQueue.write { db in
            // Upsert viewer account
            var account = Account(
                id: viewer.databaseId,
                login: viewer.login,
                avatarURL: viewer.avatarUrl,
                type: .user,
                syncedAt: Date()
            )
            try account.save(db)

            // Collect unique owners and upsert
            var seenOwners: Set<Int64> = [viewer.databaseId]
            for repo in repos {
                let ownerId = repo.owner.databaseId
                guard !seenOwners.contains(ownerId) else { continue }
                seenOwners.insert(ownerId)

                var ownerAccount = Account(
                    id: ownerId,
                    login: repo.owner.login,
                    avatarURL: repo.owner.avatarUrl,
                    type: repo.owner.typeName == "Organization" ? .organization : .user,
                    syncedAt: nil
                )
                try ownerAccount.save(db)
            }

            // Upsert repositories
            for repo in repos {
                var repository = Repository(
                    id: repo.databaseId,
                    accountId: repo.owner.databaseId,
                    name: repo.name,
                    nameWithOwner: repo.nameWithOwner,
                    isPrivate: repo.isPrivate,
                    description: repo.description,
                    url: repo.url,
                    syncedAt: nil
                )
                try repository.save(db)
            }
        }
    }

    private func persistIssues(
        _ issues: [GitHubSyncService.IssueData],
        repositoryId: Int64
    ) async throws {
        try await database.dbQueue.write { db in
            // Collect and deduplicate milestones, labels, users across all issues
            var milestones: [Int64: GitHubSyncService.MilestoneData] = [:]
            var labels: [Int64: GitHubSyncService.LabelData] = [:]
            var users: [Int64: GitHubSyncService.UserData] = [:]

            for issue in issues {
                if let m = issue.milestone {
                    milestones[m.databaseId] = m
                }
                for l in issue.labels {
                    labels[l.databaseId] = l
                }
                for u in issue.assignees {
                    users[u.databaseId] = u
                }
            }

            // Upsert milestones
            for (_, data) in milestones {
                var milestone = Milestone(
                    id: data.databaseId,
                    repositoryId: repositoryId,
                    number: data.number,
                    title: data.title,
                    descriptionText: data.description,
                    state: data.state == "CLOSED" ? .closed : .open,
                    dueOn: parseISO8601Date(data.dueOn)
                )
                try milestone.save(db)
            }

            // Upsert labels
            for (_, data) in labels {
                var label = Label(
                    id: data.databaseId,
                    repositoryId: repositoryId,
                    name: data.name,
                    color: data.color,
                    descriptionText: data.description
                )
                try label.save(db)
            }

            // Upsert users
            for (_, data) in users {
                var user = User(
                    id: data.databaseId,
                    login: data.login,
                    avatarURL: data.avatarUrl
                )
                try user.save(db)
            }

            // Upsert issues with join tables and comments
            for data in issues {
                var issue = Issue(
                    id: data.databaseId,
                    repositoryId: repositoryId,
                    number: data.number,
                    title: data.title,
                    body: data.body,
                    state: data.state == "CLOSED" ? .closed : .open,
                    milestoneId: data.milestone?.databaseId,
                    authorLogin: data.authorLogin,
                    createdAt: parseISO8601Date(data.createdAt) ?? Date(),
                    updatedAt: parseISO8601Date(data.updatedAt) ?? Date(),
                    closedAt: parseISO8601Date(data.closedAt),
                    url: data.url
                )
                try issue.save(db)

                // Replace issue labels
                try IssueLabel
                    .filter(Column("issueId") == data.databaseId)
                    .deleteAll(db)
                for labelData in data.labels {
                    var issueLabel = IssueLabel(
                        issueId: data.databaseId,
                        labelId: labelData.databaseId
                    )
                    try issueLabel.save(db)
                }

                // Replace assignees
                try Assignee
                    .filter(Column("issueId") == data.databaseId)
                    .deleteAll(db)
                for userData in data.assignees {
                    var assignee = Assignee(
                        issueId: data.databaseId,
                        userId: userData.databaseId
                    )
                    try assignee.save(db)
                }

                // Upsert comments
                for commentData in data.comments {
                    var comment = Comment(
                        id: commentData.databaseId,
                        issueId: data.databaseId,
                        authorLogin: commentData.authorLogin,
                        body: commentData.body,
                        createdAt: parseISO8601Date(commentData.createdAt) ?? Date(),
                        updatedAt: parseISO8601Date(commentData.updatedAt) ?? Date()
                    )
                    try comment.save(db)
                }
            }

            // Mark repository as synced
            try db.execute(
                sql: "UPDATE repositories SET syncedAt = ? WHERE id = ?",
                arguments: [Date(), repositoryId]
            )
        }
    }

}

// MARK: - Date Parsing Helper

private func parseISO8601Date(_ string: String?) -> Date? {
    guard let string else { return nil }
    return parseISO8601Date(string)
}

private func parseISO8601Date(_ string: String) -> Date? {
    // ISO8601DateFormatter is not Sendable, so create locally each time.
    // These are only called during sync batch writes, not in hot paths.
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    if let date = formatter.date(from: string) { return date }
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: string)
}
