import SwiftUI

// MARK: - Account Group

struct AccountGroup: Identifiable {
    let id: Int64
    let login: String
    let avatarURL: String?
    let isPersonalAccount: Bool
    let repos: [RepoOption]
}

// MARK: - View

/// Combined org + repo selection step: shows all repos grouped by account, sorted alphabetically.
struct SelectReposStepView: View {
    var authStore: AuthStore
    var syncService: any SyncServiceProtocol
    @Binding var selectedRepoIds: Set<Int64>
    var alreadyTrackedRepoIds: Set<Int64> = []
    var onBack: () -> Void
    var onContinue: () -> Void

    @State private var groups: [AccountGroup] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var filterText = ""
    @FocusState private var filterFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text("Select a repository")
                .font(.system(size: 15, weight: .semibold))
                .padding(.top, 24)

            Text("Choose one or more repositories to sync issues from")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Spacer().frame(height: 8)

            repoListContent
                .padding(.horizontal, 40)

            if !groups.isEmpty {
                selectionSummary
                    .padding(.horizontal, 40)
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
            .controlSize(.large)
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
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))
                    TextField("Filter repos...", text: $filterText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .accessibilityLabel("Filter repositories")
                        .focused($filterFocused)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary))

                List {
                    ForEach(filteredGroups) { group in
                        Section {
                            ForEach(group.repos) { repo in
                                RepoRow(
                                    repo: repo,
                                    isSelected: selectedRepoIds.contains(repo.id) || alreadyTrackedRepoIds.contains(repo.id),
                                    isDisabled: alreadyTrackedRepoIds.contains(repo.id),
                                    onToggle: { toggleRepo(repo.id) }
                                )
                            }
                        } header: {
                            AccountHeader(group: group)
                        }
                    }
                }
                .listStyle(.inset)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
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
            return AccountGroup(id: group.id, login: group.login, avatarURL: group.avatarURL, isPersonalAccount: group.isPersonalAccount, repos: matched)
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

            let accounts: [(id: Int64, login: String, avatarURL: String?, isPersonal: Bool)] =
                [(data.viewer.databaseId, data.viewer.login, data.viewer.avatarUrl, true)] +
                data.organizations.map { ($0.databaseId, $0.login, $0.avatarUrl, false) }

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
                        return AccountGroup(id: account.id, login: account.login, avatarURL: account.avatarURL, isPersonalAccount: account.isPersonal, repos: repos)
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
        if errorMessage == nil {
            filterFocused = true
        }
    }
}

// MARK: - Account Header

private struct AccountHeader: View {
    var group: AccountGroup

    var body: some View {
        HStack(spacing: 6) {
            avatar
                .frame(width: 16, height: 16)
                .clipShape(RoundedRectangle(cornerRadius: group.isPersonalAccount ? 8 : 4))
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

    @ViewBuilder
    private var avatar: some View {
        if let urlString = group.avatarURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                fallbackIcon
            }
        } else {
            fallbackIcon
        }
    }

    private var fallbackIcon: some View {
        Image(systemName: group.isPersonalAccount ? "person.circle.fill" : "building.2.fill")
            .font(.system(size: 16))
            .foregroundStyle(.secondary)
    }
}

// MARK: - Repo Row

private struct RepoRow: View {
    var repo: RepoOption
    var isSelected: Bool
    var isDisabled: Bool = false
    var onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 15))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 18)
                Image(systemName: repo.isPrivate ? "lock" : "book.closed")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                Text(repo.name)
                    .font(.system(size: 13))
                Spacer()
            }
            .contentShape(Rectangle())
            .opacity(isDisabled ? 0.4 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .padding(.vertical, 2)
        .accessibilityLabel("\(repo.name)\(repo.isPrivate ? ", private" : "")\(isDisabled ? ", already added" : isSelected ? ", selected" : ", not selected")")
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
        authStore: AuthStore(previewState: .authenticated(username: "jlong")),
        syncService: PreviewSyncService(
            viewer: GitHubSyncService.ViewerData(databaseId: 4173, login: "jlong", avatarUrl: "https://avatars.githubusercontent.com/u/4173?v=4"),
            orgs: [
                GitHubSyncService.OrganizationData(databaseId: 46849640, login: "32pixelsCo", avatarUrl: "https://avatars.githubusercontent.com/u/46849640?v=4"),
                GitHubSyncService.OrganizationData(databaseId: 14429, login: "radiant", avatarUrl: "https://avatars.githubusercontent.com/u/14429?v=4"),
            ],
            personalRepos: [
                .preview(id: 9971036,   name: "css-spinners",        owner: "jlong"),
                .preview(id: 6326674,   name: "cookbook",            owner: "jlong"),
                .preview(id: 160424186, name: "entypo",              owner: "jlong"),
                .preview(id: 13390898,  name: "fontcustom",          owner: "jlong"),
            ],
            orgRepos: [
                "32pixelsCo": [
                    .preview(id: 1131870540, name: "ContextStore",   owner: "32pixelsCo", isPrivate: true),
                    .preview(id: 1211019915, name: "GeckoIssues",    owner: "32pixelsCo", isPrivate: true),
                    .preview(id: 973451841,  name: "TaskpageApp",    owner: "32pixelsCo", isPrivate: true),
                    .preview(id: 166613845,  name: "website",        owner: "32pixelsCo", isPrivate: true),
                ],
                "radiant": [
                    .preview(id: 27046, name: "radiant",                          owner: "radiant"),
                    .preview(id: 27053, name: "radiant-extension-registry",       owner: "radiant"),
                    .preview(id: 27085, name: "radiant-page-attachments-extension", owner: "radiant"),
                    .preview(id: 27088, name: "radiant-search-extension",         owner: "radiant"),
                ],
            ]
        ),
        selectedRepoIds: .constant([1211019915, 9971036]),
        onBack: {},
        onContinue: {}
    )
    .frame(width: 520, height: 460)
}
