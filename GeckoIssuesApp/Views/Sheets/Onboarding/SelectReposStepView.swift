import SwiftUI

/// Step 3 of the onboarding wizard: choose which repositories to sync.
struct SelectReposStepView: View {
    var authStore: AuthStore
    var syncService: GitHubSyncService
    var selectedOrg: OrgOption
    @Binding var selectedRepoIds: Set<Int64>
    var onBack: () -> Void
    var onContinue: () -> Void

    @State private var repos: [RepoOption] = []
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

            if !repos.isEmpty {
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
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.quaternary)
                )
                .padding(.bottom, 6)

                List(filteredRepos) { repo in
                    RepoRow(
                        repo: repo,
                        isSelected: selectedRepoIds.contains(repo.id),
                        onToggle: { toggleRepo(repo.id) }
                    )
                }
                .listStyle(.bordered)
                .frame(height: 180)
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

    private var filteredRepos: [RepoOption] {
        guard !filterText.isEmpty else { return repos }
        return repos.filter { $0.name.localizedCaseInsensitiveContains(filterText) }
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
            let repoData: [GitHubSyncService.RepositoryData]
            if selectedOrg.isPersonalAccount {
                repoData = try await syncService.fetchRepositories(token: token)
            } else {
                repoData = try await syncService.fetchOrganizationRepositories(
                    login: selectedOrg.login,
                    token: token
                )
            }
            repos = repoData.map { r in
                RepoOption(
                    id: r.databaseId,
                    name: r.name,
                    nameWithOwner: r.nameWithOwner,
                    isPrivate: r.isPrivate
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
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
