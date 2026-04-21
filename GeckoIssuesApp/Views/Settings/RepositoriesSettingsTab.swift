import SwiftUI
import GRDB

/// Settings tab for managing tracked repositories — list on the left, detail pane on the right.
struct RepositoriesSettingsTab: View {
    var appStore: AppStore
    var syncStore: SyncStore
    var authStore: AuthStore
    var database: AppDatabase

    @State private var accountGroups: [SettingsAccountGroup] = []
    @State private var selectedRepoId: Int64?
    @State private var showDeleteConfirmation = false
    @State private var showAddReposWizard = false

    var body: some View {
        HStack(spacing: 0) {
            repoList
                .frame(width: 200)

            Divider()

            detailPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            await loadTrackedRepos()
        }
        .onChange(of: syncStore.state) {
            if case .completed = syncStore.state {
                Task { await loadTrackedRepos() }
            }
        }
        .sheet(isPresented: $showAddReposWizard) {
            Task { await loadTrackedRepos() }
        } content: {
            OnboardingWizardSheet(
                authStore: authStore,
                syncStore: syncStore,
                appStore: appStore,
                database: database,
                startStep: .selectRepos,
                alreadyTrackedRepoIds: trackedRepoIds
            )
        }
        .alert(
            "Remove Repository",
            isPresented: $showDeleteConfirmation
        ) {
            Button("Remove", role: .destructive) {
                Task { await deleteSelected() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let repo = selectedRepo {
                Text("This will remove \(repo.nameWithOwner) and all its synced data.")
            }
        }
    }

    // MARK: - Repo List

    private var repoList: some View {
        VStack(spacing: 0) {
            List(selection: $selectedRepoId) {
                ForEach(accountGroups) { group in
                    Section {
                        ForEach(group.repos, id: \.id) { repo in
                            HStack(spacing: 8) {
                                Image(systemName: repo.isPrivate ? "lock" : "folder")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 16)
                                Text(repo.name)
                                    .lineLimit(1)
                            }
                            .tag(repo.id)
                            .accessibilityLabel("\(repo.name)\(repo.isPrivate ? ", private" : "")")
                        }
                    } header: {
                        HStack(spacing: 6) {
                            AccountAvatar(
                                login: group.login,
                                avatarURL: group.avatarURL,
                                size: 16
                            )
                            Text(group.login.uppercased())
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            HStack(spacing: 4) {
                Spacer()
                Divider()
                    .frame(height: 24)
                Button {
                    showAddReposWizard = true
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .disabled(!authStore.isAuthenticated)
                .accessibilityLabel("Add repositories")
                Divider()
                    .frame(height: 24)
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .disabled(selectedRepoId == nil)
                .accessibilityLabel("Remove repository")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Detail Pane

    @ViewBuilder
    private var detailPane: some View {
        if let repo = selectedRepo {
            VStack(spacing: 8) {
                Image(systemName: repo.isPrivate ? "lock.shield" : "folder")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                Text(repo.nameWithOwner)
                    .font(.system(size: 15, weight: .semibold))
                Text("Repository settings coming soon.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Text("No Repository Selected")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Helpers

    private var selectedRepo: Repository? {
        guard let id = selectedRepoId else { return nil }
        return accountGroups.flatMap(\.repos).first { $0.id == id }
    }

    private var trackedRepoIds: Set<Int64> {
        Set(accountGroups.flatMap(\.repos).map(\.id))
    }

    // MARK: - Data Loading

    private func loadTrackedRepos() async {
        do {
            let groups = try await database.dbQueue.read { db in
                let accounts = try Account
                    .joining(required: Account.repositories.filter(Column("tracked") == true))
                    .distinct()
                    .order(
                        Column("type").desc,
                        Column("login").collating(.localizedCaseInsensitiveCompare)
                    )
                    .fetchAll(db)

                return try accounts.map { account in
                    let repos = try Repository
                        .filter(Column("accountId") == account.id)
                        .filter(Column("tracked") == true)
                        .order(Column("name").collating(.localizedCaseInsensitiveCompare))
                        .fetchAll(db)
                    return SettingsAccountGroup(
                        id: account.id,
                        login: account.login,
                        avatarURL: account.avatarURL,
                        repos: repos
                    )
                }
            }
            accountGroups = groups

            // Auto-select first repo if current selection is gone
            if selectedRepoId == nil || !groups.flatMap(\.repos).contains(where: { $0.id == selectedRepoId }) {
                selectedRepoId = groups.first?.repos.first?.id
            }
        } catch {
            // Non-fatal
        }
    }

    // MARK: - Delete

    private func deleteSelected() async {
        guard let repoId = selectedRepoId else { return }
        do {
            try await database.dbQueue.write { db in
                // Untrack the repo and clear its synced data
                try db.execute(
                    sql: "UPDATE repositories SET tracked = 0, syncedAt = NULL WHERE id = ?",
                    arguments: [repoId]
                )
                // Delete issues (cascade will handle labels, comments, assignees)
                try Issue.filter(Column("repositoryId") == repoId).deleteAll(db)
                try Milestone.filter(Column("repositoryId") == repoId).deleteAll(db)
                try Label.filter(Column("repositoryId") == repoId).deleteAll(db)
            }

            // Remove accounts that no longer have tracked repos
            try await database.dbQueue.write { db in
                try db.execute(sql: """
                    DELETE FROM accounts
                    WHERE id NOT IN (
                        SELECT DISTINCT accountId FROM repositories WHERE tracked = 1
                    )
                """)
            }

            selectedRepoId = nil
            await loadTrackedRepos()
            await appStore.loadAccounts(from: database)
        } catch {
            // Non-fatal
        }
    }
}

// MARK: - Settings Account Group

struct SettingsAccountGroup: Identifiable {
    let id: Int64
    let login: String
    let avatarURL: String?
    let repos: [Repository]
}
