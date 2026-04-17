import SwiftUI

struct ContentView: View {
    var appStore: AppStore
    var navigationStore: NavigationStore
    var syncStore: SyncStore
    var authStore: AuthStore
    var database: AppDatabase

    var body: some View {
        NavigationSplitView {
            RepositoryListView(appStore: appStore, syncStore: syncStore, database: database)
                .navigationTitle("Repositories")
        } content: {
            if appStore.selectedRepository != nil {
                IssueListView(appStore: appStore, syncStore: syncStore, database: database)
            } else {
                ContentUnavailableView(
                    "Select a Repository",
                    systemImage: "folder",
                    description: Text("Choose a repository from the sidebar.")
                )
            }
        } detail: {
            if let issue = appStore.selectedIssue {
                IssueDetailView(issue: issue, database: database)
            } else if appStore.selectedRepository == nil {
                authAndSyncView
            } else {
                ContentUnavailableView(
                    "No Issue Selected",
                    systemImage: "doc.text",
                    description: Text("Select an issue to view its details.")
                )
            }
        }
        .sheet(item: Bindable(navigationStore).activeSheet) { route in
            switch route {
            case .onboarding:
                OnboardingWizardSheet(
                    authStore: authStore,
                    syncStore: syncStore,
                    appStore: appStore,
                    database: database
                )
            }
        }
        .task {
            if !authStore.isAuthenticated {
                navigationStore.activeSheet = .onboarding
            }
        }
    }

    // MARK: - Auth & Sync

    @ViewBuilder
    private var authAndSyncView: some View {
        VStack(spacing: 16) {
            switch authStore.state {
            case .unauthenticated:
                Text("Not signed in")
                    .foregroundStyle(.secondary)
                Button("Sign In with GitHub") {
                    navigationStore.activeSheet = .onboarding
                }

            case .authorizing(let userCode, _):
                Text("Enter this code on GitHub:")
                    .foregroundStyle(.secondary)
                Text(userCode)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .textSelection(.enabled)
                Button("Cancel") {
                    authStore.cancelSignIn()
                }

            case .authenticated(let username):
                Text("Signed in as **\(username)**")

                syncStatusView

                HStack {
                    Button("Sign Out") {
                        authStore.signOut()
                    }
                }
            }

            if let error = authStore.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.callout)
            }
        }
        .padding()
    }

    // MARK: - Sync Status

    @ViewBuilder
    private var syncStatusView: some View {
        switch syncStore.state {
        case .idle:
            Button("Sync Now") {
                guard let token = authStore.accessToken else { return }
                syncStore.startFullSync(token: token)
            }

        case .syncing(let progress):
            VStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)

                switch progress.phase {
                case .fetchingAccount:
                    Text("Fetching account...")
                        .foregroundStyle(.secondary)
                case .fetchingRepositories:
                    Text("Fetching repositories...")
                        .foregroundStyle(.secondary)
                case .syncingRepository(let name):
                    Text("Syncing \(name)...")
                        .foregroundStyle(.secondary)
                    if progress.repositoriesTotal > 0 {
                        Text("\(progress.repositoriesSynced) of \(progress.repositoriesTotal) repositories")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Button("Cancel Sync") {
                syncStore.cancelSync()
            }

        case .completed:
            SwiftUI.Label("Sync complete", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)

            Button("Sync Again") {
                guard let token = authStore.accessToken else { return }
                syncStore.startFullSync(token: token)
            }

        case .error(let message):
            SwiftUI.Label("Sync failed", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)

            Button("Retry Sync") {
                guard let token = authStore.accessToken else { return }
                syncStore.startFullSync(token: token)
            }
        }
    }
}
