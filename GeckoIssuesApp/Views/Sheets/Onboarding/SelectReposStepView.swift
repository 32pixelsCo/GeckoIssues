import SwiftUI

// MARK: - Account Group

struct AccountGroup: Identifiable {
    let id: Int64
    let login: String
    let isPersonalAccount: Bool
    let repos: [RepoOption]
}

// MARK: - View

/// Combined org + repo selection step: shows all repos grouped by account, sorted alphabetically.
struct SelectReposStepView: View {
    var authStore: AuthStore
    var syncService: any SyncServiceProtocol
    @Binding var selectedRepoIds: Set<Int64>
    var onBack: () -> Void
    var onContinue: () -> Void

    @State private var groups: [AccountGroup] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var filterText = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("Get Started")
                .font(.system(size: 15, weight: .semibold))
                .padding(.top, 24)

            Text("Choose repos to sync")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            Spacer().frame(height: 16)

            repoListContent
                .padding(.horizontal, 40)

            if !groups.isEmpty {
                selectionSummary
                    .padding(.horizontal, 40)
                    .padding(.top, 6)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Back", action: onBack)
                    .keyboardShortcut(.cancelAction)
                Button("Continue", action: onContinue)
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedRepoIds.isEmpty)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .task {
            await loadRepos()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var repoListContent: some View {
        if isLoading {
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.regular)
                Text("Loading repositories...")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: 200)
        } else if let error = errorMessage {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.red)
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    Task { await loadRepos() }
                }
                .accessibilityLabel("Retry loading repositories")
            }
            .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))
                    TextField("Filter repos...", text: $filterText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .accessibilityLabel("Filter repositories")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary))
                .padding(.bottom, 6)

                List {
                    ForEach(filteredGroups) { group in
                        Section {
                            ForEach(group.repos) { repo in
                                RepoRow(
                                    repo: repo,
                                    isSelected: selectedRepoIds.contains(repo.id),
                                    onToggle: { toggleRepo(repo.id) }
                                )
                            }
                        } header: {
                            AccountHeader(group: group)
                        }
                    }
                }
                .listStyle(.bordered)
                .frame(height: 220)
            }
        }
    }

    // MARK: - Selection Summary

    private var selectionSummary: some View {
        let count = selectedRepoIds.count
        return Text(count == 1 ? "1 repo selected" : "\(count) repos selected")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Filtering

    private var filteredGroups: [AccountGroup] {
        guard !filterText.isEmpty else { return groups }
        return groups.compactMap { group in
            let matched = group.repos.filter {
                $0.name.localizedCaseInsensitiveContains(filterText) ||
                group.login.localizedCaseInsensitiveContains(filterText)
            }
            guard !matched.isEmpty else { return nil }
            return AccountGroup(id: group.id, login: group.login, isPersonalAccount: group.isPersonalAccount, repos: matched)
        }
    }

    // MARK: - Toggle

    private func toggleRepo(_ id: Int64) {
        if selectedRepoIds.contains(id) {
            selectedRepoIds.remove(id)
        } else {
            selectedRepoIds.insert(id)
        }
    }

    // MARK: - Data Loading

    private func loadRepos() async {
        guard let token = authStore.accessToken else { return }
        isLoading = true
        errorMessage = nil
        do {
            let data = try await syncService.fetchViewerWithOrganizations(token: token)

            let accounts: [(id: Int64, login: String, isPersonal: Bool)] =
                [(data.viewer.databaseId, data.viewer.login, true)] +
                data.organizations.map { ($0.databaseId, $0.login, false) }

            var fetched: [AccountGroup] = []
            try await withThrowingTaskGroup(of: AccountGroup.self) { group in
                for account in accounts {
                    group.addTask {
                        let repoData: [GitHubSyncService.RepositoryData]
                        if account.isPersonal {
                            repoData = try await syncService.fetchRepositories(token: token)
                        } else {
                            repoData = try await syncService.fetchOrganizationRepositories(
                                login: account.login, token: token
                            )
                        }
                        let repos = repoData
                            .map { RepoOption(id: $0.databaseId, name: $0.name, nameWithOwner: $0.nameWithOwner, isPrivate: $0.isPrivate) }
                            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                        return AccountGroup(id: account.id, login: account.login, isPersonalAccount: account.isPersonal, repos: repos)
                    }
                }
                for try await accountGroup in group {
                    fetched.append(accountGroup)
                }
            }

            groups = fetched.sorted { $0.login.localizedCaseInsensitiveCompare($1.login) == .orderedAscending }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Account Header

private struct AccountHeader: View {
    var group: AccountGroup

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: group.isPersonalAccount ? "person.circle" : "building.2")
                .font(.system(size: 12))
            Text(group.login)
                .font(.system(size: 12, weight: .semibold))
            if group.isPersonalAccount {
                Text("Personal")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.quaternary))
            }
        }
        .accessibilityLabel("\(group.login)\(group.isPersonalAccount ? ", personal account" : ", organization")")
    }
}

// MARK: - Repo Row

private struct RepoRow: View {
    var repo: RepoOption
    var isSelected: Bool
    var onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 15))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 18)
                Image(systemName: repo.isPrivate ? "lock" : "folder")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                Text(repo.name)
                    .font(.system(size: 13))
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
        .accessibilityLabel("\(repo.name)\(repo.isPrivate ? ", private" : "")\(isSelected ? ", selected" : ", not selected")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Previews

#Preview("Loading") {
    SelectReposStepView(
        authStore: AuthStore(previewState: .authenticated(username: "octocat")),
        syncService: PreviewSyncService(),
        selectedRepoIds: .constant([]),
        onBack: {},
        onContinue: {}
    )
    .frame(width: 520, height: 460)
}

#Preview("Loaded") {
    SelectReposStepView(
        authStore: AuthStore(previewState: .authenticated(username: "octocat")),
        syncService: PreviewSyncService(
            orgs: [
                GitHubSyncService.OrganizationData(databaseId: 10, login: "32pixels", avatarUrl: nil),
                GitHubSyncService.OrganizationData(databaseId: 11, login: "github", avatarUrl: nil),
            ],
            repos: [
                .preview(id: 1, name: "gecko-issues"),
                .preview(id: 2, name: "website"),
                .preview(id: 3, name: "api-client", isPrivate: true),
            ]
        ),
        selectedRepoIds: .constant([1, 3]),
        onBack: {},
        onContinue: {}
    )
    .frame(width: 520, height: 460)
}
