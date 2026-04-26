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
        case checkingForUpdates
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
    private var refreshTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        database: AppDatabase,
        syncService: any SyncServiceProtocol = GitHubSyncService()
    ) {
        self.database = database
        self.syncService = syncService
        restoreLastSyncDate()
    }

    /// Preview initializer — sets an explicit initial state without a real database or service.
    init(previewState: SyncState) {
        self.database = try! AppDatabase.inMemory()
        self.syncService = GitHubSyncService()
        self.state = previewState
    }

    private func restoreLastSyncDate() {
        if let lastSynced = try? database.dbQueue.read({ db in
            try Date.fetchOne(db, sql: """
                SELECT MAX(syncedAt) FROM repositories WHERE tracked = 1 AND syncedAt IS NOT NULL
                """)
        }) {
            state = .completed(lastSynced)
        }
    }

    // MARK: - Sync

    /// Refresh all tracked repos by re-fetching their issues from GitHub.
    ///
    /// Reads the set of tracked repo IDs from the local database and only
    /// fetches issues for those repos. Uses incremental sync (fetching only
    /// issues updated since the last sync) when a cursor exists. Pass
    /// `force: true` to ignore stored cursors and do a full re-fetch.
    ///
    /// Does not discover new repos — use
    /// `startSyncForRepos(repoIds:token:)` for that.
    func startFullSync(token: String, force: Bool = false) {
        if case .syncing = state { return }

        errorMessage = nil
        syncTask = Task {
            do {
                let trackedRepos = try await database.dbQueue.read { db in
                    try Repository
                        .filter(Column("tracked") == true)
                        .fetchAll(db)
                }

                guard !trackedRepos.isEmpty else {
                    logger.info("No tracked repos to sync")
                    state = .completed(Date())
                    return
                }

                logger.info("Starting refresh sync for \(trackedRepos.count) tracked repos")

                let repoEntries = trackedRepos.map {
                    (id: $0.id, nameWithOwner: $0.nameWithOwner, syncedAt: force ? nil : $0.syncedAt)
                }

                // Repos with a syncedAt cursor can be batched into a single request
                let incrementalRepos = repoEntries.filter { $0.syncedAt != nil }
                let fullSyncRepos = repoEntries.filter { $0.syncedAt == nil }

                if !incrementalRepos.isEmpty {
                    try await syncIssuesBatched(incrementalRepos, token: token, totalRepos: repoEntries.count)
                }

                // Repos without a cursor need individual full fetches
                if !fullSyncRepos.isEmpty {
                    try await syncIssues(for: fullSyncRepos, token: token)
                }

                state = .completed(Date())
                logger.info("Sync completed")
            } catch is CancellationError {
                state = .idle
                logger.info("Sync cancelled")
            } catch {
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

    /// Discover repos from GitHub and sync issues for the specified repo IDs.
    ///
    /// All repos and org memberships are persisted to the DB, but issues are only
    /// fetched for repos in `repoIds`. Used during onboarding and when adding
    /// repos via Settings.
    func startSyncForRepos(repoIds: Set<Int64>, token: String) {
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
                logger.info("Starting discovery sync (\(repoIds.count) repos)")

                let viewerData = try await syncService.fetchViewerWithOrganizations(token: token)
                let viewer = viewerData.viewer
                let orgAccounts = viewerData.organizations
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
                let orgLoginsFromRepos = Set(
                    repos
                        .filter { $0.owner.typeName == "Organization" }
                        .map(\.owner.login)
                )
                let orgLoginsFromMemberships = Set(orgAccounts.map(\.login))
                let orgLogins = orgLoginsFromRepos.union(orgLoginsFromMemberships)
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

                // Step 3: Save accounts + all repos; mark selected repos as tracked
                try await persistAccountsAndRepos(viewer: viewer, orgAccounts: orgAccounts, repos: repos, trackedRepoIds: repoIds)

                // Step 4: Fetch and persist issues for selected repos only
                let reposToSync = repos.filter { repoIds.contains($0.databaseId) }
                let repoEntries = reposToSync.map {
                    (id: $0.databaseId, nameWithOwner: $0.nameWithOwner, syncedAt: nil as Date?)
                }
                try await syncIssues(for: repoEntries, token: token)

                state = .completed(Date())
                logger.info("Sync completed")
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

    // MARK: - Background Refresh

    /// Start periodic background sync on the given interval.
    ///
    /// Each tick triggers an incremental sync via `startFullSync`. If a sync
    /// is already in progress the tick is skipped. Call `stopBackgroundRefresh()`
    /// when the app resigns active.
    func startBackgroundRefresh(interval: TimeInterval, token: String) {
        stopBackgroundRefresh()
        logger.info("Background refresh started (interval: \(interval)s)")

        refreshTask = Task {
            // Sync immediately on start, then wait the interval between syncs
            while !Task.isCancelled {
                if case .syncing = state {
                    logger.info("Background refresh skipped — sync already in progress")
                } else {
                    logger.info("Background refresh triggered")
                    startFullSync(token: token)
                }

                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    /// Stop the periodic background refresh timer.
    func stopBackgroundRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    // MARK: - Private Sync

    /// Fetch issues for multiple repos in a single GraphQL request.
    ///
    /// Sends one batched query for all incremental repos. For repos where
    /// the first page has `hasNextPage`, falls back to individual paginated
    /// fetches for the remaining pages.
    private func syncIssuesBatched(
        _ repos: [(id: Int64, nameWithOwner: String, syncedAt: Date?)],
        token: String,
        totalRepos: Int
    ) async throws {
        state = .syncing(SyncProgress(
            phase: .checkingForUpdates,
            repositoriesSynced: 0,
            repositoriesTotal: totalRepos
        ))

        let batchInput = repos.map { repo -> (owner: String, name: String, since: Date) in
            let parts = repo.nameWithOwner.split(separator: "/", maxSplits: 1)
            return (owner: String(parts[0]), name: String(parts[1]), since: repo.syncedAt!)
        }

        logger.info("Batched incremental sync for \(repos.count) repos (single request)")
        let results = try await syncService.fetchIssuesBatched(repos: batchInput, token: token)
        try Task.checkCancellation()

        for (index, result) in results.enumerated() {
            try Task.checkCancellation()
            let repo = repos[index]

            state = .syncing(SyncProgress(
                phase: .syncingRepository(repo.nameWithOwner),
                repositoriesSynced: index,
                repositoriesTotal: totalRepos
            ))

            var allIssues = result.issues

            // If the first page wasn't enough, fetch remaining pages individually
            if result.hasNextPage, let cursor = result.endCursor {
                let parts = repo.nameWithOwner.split(separator: "/", maxSplits: 1)
                logger.info("Fetching additional pages for \(repo.nameWithOwner)")
                let remaining = try await syncService.fetchIssues(
                    owner: String(parts[0]),
                    name: String(parts[1]),
                    since: repo.syncedAt,
                    token: token
                )
                // The individual fetch re-fetches all pages; merge by deduplicating
                let batchedIds = Set(allIssues.map(\.databaseId))
                allIssues.append(contentsOf: remaining.filter { !batchedIds.contains($0.databaseId) })
            }

            if !allIssues.isEmpty {
                logger.info("Persisting \(allIssues.count) issues for \(repo.nameWithOwner)")
            }
            try await persistIssues(allIssues, repositoryId: repo.id)
        }
    }

    /// Fetch and persist issues for the given repos, updating sync progress.
    ///
    /// When `syncedAt` is non-nil for a repo, performs an incremental fetch
    /// (only issues updated since that date). When nil, fetches all issues.
    private func syncIssues(
        for repos: [(id: Int64, nameWithOwner: String, syncedAt: Date?)],
        token: String
    ) async throws {
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

            if repo.syncedAt != nil {
                logger.info("Incremental sync for \(repo.nameWithOwner) (since \(repo.syncedAt!))")
            } else {
                logger.info("Full sync for \(repo.nameWithOwner)")
            }

            let issues = try await syncService.fetchIssues(
                owner: owner,
                name: name,
                since: repo.syncedAt,
                token: token
            )
            logger.info("Fetched \(issues.count) issues for \(repo.nameWithOwner)")

            try await persistIssues(issues, repositoryId: repo.id)
        }
    }

    // MARK: - Persistence

    private func persistAccountsAndRepos(
        viewer: GitHubSyncService.ViewerData,
        orgAccounts: [GitHubSyncService.OrganizationData],
        repos: [GitHubSyncService.RepositoryData],
        trackedRepoIds: Set<Int64>?
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

            // Upsert all org memberships so AccountPicker shows every org
            var seenOwners: Set<Int64> = [viewer.databaseId]
            for org in orgAccounts where !seenOwners.contains(org.databaseId) {
                seenOwners.insert(org.databaseId)
                var orgAccount = Account(
                    id: org.databaseId,
                    login: org.login,
                    avatarURL: org.avatarUrl,
                    type: .organization,
                    syncedAt: nil
                )
                try orgAccount.save(db)
            }

            // Collect unique repo owners and upsert
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

            // Upsert repositories; tracked is additive — newly selected repos
            // are marked tracked without unmarking previously tracked repos.
            for repo in repos {
                let isNewlySelected = trackedRepoIds?.contains(repo.databaseId) == true
                let existing = try Repository.fetchOne(db, key: repo.databaseId)
                let wasTracked = existing?.tracked ?? false
                var repository = Repository(
                    id: repo.databaseId,
                    accountId: repo.owner.databaseId,
                    name: repo.name,
                    nameWithOwner: repo.nameWithOwner,
                    isPrivate: repo.isPrivate,
                    description: repo.description,
                    url: repo.url,
                    syncedAt: existing?.syncedAt,
                    tracked: isNewlySelected || wasTracked
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
