import SwiftUI

struct ContentView: View {
    var appStore: AppStore
    var navigationStore: NavigationStore
    var syncStore: SyncStore
    var authStore: AuthStore
    var database: AppDatabase

    @AppStorage("backgroundRefreshInterval") private var refreshInterval = RefreshInterval.fiveMinutes.rawValue

    var body: some View {
        NavigationSplitView {
            RepositoryListView(appStore: appStore, syncStore: syncStore, database: database)
                .navigationTitle("Repositories")
        } detail: {
            VStack(spacing: 0) {
                StableSplitView(
                    leadingMinWidth: 200,
                    leadingIdealWidth: 250,
                    leadingMaxWidth: 400
                ) {
                    issueListColumn
                } trailing: {
                    issueDetailColumn
                }
                SyncStatusBar(syncStore: syncStore, authStore: authStore)
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
            syncStore.startNetworkMonitoring()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            startBackgroundRefreshIfAuthenticated()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
            syncStore.stopBackgroundRefresh()
        }
        .onChange(of: refreshInterval) {
            startBackgroundRefreshIfAuthenticated()
        }
    }

    // MARK: - Columns

    @ViewBuilder
    private var issueListColumn: some View {
        if appStore.selectedRepository != nil {
            IssueListView(appStore: appStore, syncStore: syncStore, database: database)
        } else {
            ContentUnavailableView(
                "Select a Repository",
                systemImage: "folder",
                description: Text("Choose a repository from the sidebar.")
            )
        }
    }

    @ViewBuilder
    private var issueDetailColumn: some View {
        if let issue = appStore.selectedIssue {
            IssueDetailView(issue: issue, database: database)
        } else {
            ContentUnavailableView(
                "No Issue Selected",
                systemImage: "doc.text",
                description: Text("Select an issue to view its details.")
            )
        }
    }

    // MARK: - Background Refresh

    private func startBackgroundRefreshIfAuthenticated() {
        guard let token = authStore.accessToken else { return }
        syncStore.startBackgroundRefresh(interval: TimeInterval(refreshInterval), token: token)
    }
}
