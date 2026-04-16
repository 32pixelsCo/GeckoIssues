import SwiftUI
import GRDB

/// Sidebar view displaying synced repositories for the selected account.
struct RepositoryListView: View {
    var appStore: AppStore
    var syncStore: SyncStore
    var database: AppDatabase

    @State private var filterText = ""
    @State private var repositories: [Repository] = []

    var body: some View {
        Group {
            if appStore.accounts.isEmpty {
                ContentUnavailableView(
                    "No Repositories",
                    systemImage: "folder",
                    description: Text("Sync your GitHub account to see repositories here.")
                )
            } else if repositories.isEmpty && filterText.isEmpty {
                ContentUnavailableView(
                    "No Repositories",
                    systemImage: "folder",
                    description: Text("This account has no synced repositories.")
                )
            } else {
                List(selection: selectedRepositoryId) {
                    ForEach(filteredRepositories, id: \.id) { repo in
                        RepositoryRow(repository: repo)
                            .tag(repo.id)
                    }
                }
            }
        }
        .safeAreaInset(edge: .top) {
            if !appStore.accounts.isEmpty {
                AccountPicker(
                    accounts: appStore.accounts,
                    selectedAccount: Binding(
                        get: { appStore.selectedAccount },
                        set: { appStore.selectedAccount = $0 }
                    )
                )
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
        }
        .searchable(text: $filterText, placement: .sidebar, prompt: "Filter repos...")
        .task {
            await appStore.loadAccounts(from: database)
            await loadRepositories()
        }
        .onChange(of: syncStore.state) {
            if case .completed = syncStore.state {
                Task {
                    await appStore.loadAccounts(from: database)
                    await loadRepositories()
                }
            }
        }
        .onChange(of: appStore.selectedAccount?.id) {
            Task { await loadRepositories() }
        }
    }

    // MARK: - Filtering

    private var filteredRepositories: [Repository] {
        guard !filterText.isEmpty else { return repositories }
        return repositories.filter {
            $0.name.localizedCaseInsensitiveContains(filterText)
        }
    }

    // MARK: - Selection

    private var selectedRepositoryId: Binding<Int64?> {
        Binding(
            get: { appStore.selectedRepository?.id },
            set: { newId in
                guard let newId else {
                    appStore.selectedRepository = nil
                    return
                }
                appStore.selectedRepository = repositories.first { $0.id == newId }
            }
        )
    }

    // MARK: - Data Loading

    private func loadRepositories() async {
        guard let account = appStore.selectedAccount else {
            repositories = []
            return
        }
        do {
            repositories = try await database.dbQueue.read { db in
                try Repository
                    .filter(Column("accountId") == account.id)
                    .order(Column("name").collating(.localizedCaseInsensitiveCompare))
                    .fetchAll(db)
            }
        } catch {
            // Non-fatal; repo list stays empty
        }
    }
}

// MARK: - Repository Row

private struct RepositoryRow: View {
    var repository: Repository

    var body: some View {
        SwiftUI.Label(repository.name, systemImage: repository.isPrivate ? "lock" : "folder")
            .accessibilityLabel("\(repository.name)\(repository.isPrivate ? ", private" : "")")
    }
}
