import SwiftUI

/// Settings tab identifiers.
enum SettingsTab: String {
    case repositories
    case github
}

/// Root view for the Settings window, containing tabbed panes.
struct SettingsView: View {
    var appStore: AppStore
    var syncStore: SyncStore
    var authStore: AuthStore
    var database: AppDatabase

    @AppStorage("SettingsSelectedTab") private var selectedTab = SettingsTab.repositories.rawValue

    var body: some View {
        TabView(selection: $selectedTab) {
            RepositoriesSettingsTab(
                appStore: appStore,
                syncStore: syncStore,
                authStore: authStore,
                database: database
            )
            .tabItem {
                SwiftUI.Label("Repositories", systemImage: "folder")
            }
            .tag(SettingsTab.repositories.rawValue)

            GitHubSettingsTab(authStore: authStore)
                .tabItem {
                    SwiftUI.Label("GitHub", systemImage: "arrow.triangle.branch")
                }
                .tag(SettingsTab.github.rawValue)
        }
        .frame(width: 740, height: 520)
    }
}
