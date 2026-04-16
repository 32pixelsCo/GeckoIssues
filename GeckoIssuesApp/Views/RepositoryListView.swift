import SwiftUI
import GRDB

/// Sidebar view displaying synced repositories grouped by owner/organization.
struct RepositoryListView: View {
    var appStore: AppStore
    var syncStore: SyncStore
    var database: AppDatabase

    @State private var filterText = ""
    @State private var groupedRepositories: [(account: Account, repositories: [Repository])] = []

    var body: some View {
        Group {
            if groupedRepositories.isEmpty && filterText.isEmpty {
                ContentUnavailableView(
                    "No Repositories",
                    systemImage: "folder",
                    description: Text("Sync your GitHub account to see repositories here.")
                )
            } else {
                List(selection: selectedRepositoryId) {
                    ForEach(filteredGroups, id: \.account.id) { group in
                        DisclosureGroup(group.account.login) {
                            ForEach(group.repositories, id: \.id) { repo in
                                RepositoryRow(repository: repo)
                                    .tag(repo.id)
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $filterText, placement: .sidebar, prompt: "Filter repos...")
        .task {
            await loadRepositories()
        }
        .onChange(of: syncStore.state) {
            if case .completed = syncStore.state {
                Task { await loadRepositories() }
            }
        }
    }

    // MARK: - Filtering

    private var filteredGroups: [(account: Account, repositories: [Repository])] {
        guard !filterText.isEmpty else { return groupedRepositories }

        let query = filterText.lowercased()
        return groupedRepositories.compactMap { group in
            let filtered = group.repositories.filter {
                $0.name.localizedCaseInsensitiveContains(query)
            }
            guard !filtered.isEmpty else { return nil }
            return (account: group.account, repositories: filtered)
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
                let repo = groupedRepositories
                    .flatMap(\.repositories)
                    .first { $0.id == newId }
                appStore.selectedRepository = repo
            }
        )
    }

    // MARK: - Data Loading

    private func loadRepositories() async {
        do {
            let groups = try await database.dbQueue.read { db in
                let accounts = try Account
                    .order(Column("login").collating(.localizedCaseInsensitiveCompare))
                    .fetchAll(db)

                return try accounts.map { account in
                    let repos = try account.repositories
                        .order(Column("name").collating(.localizedCaseInsensitiveCompare))
                        .fetchAll(db)
                    return (account: account, repositories: repos)
                }
            }
            groupedRepositories = groups.filter { !$0.repositories.isEmpty }
        } catch {
            // Database read failures are non-fatal; sidebar stays empty
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
