import SwiftUI

@main
struct GeckoIssuesApp: App {
    @State private var appStore = AppStore()
    @State private var navigationStore = NavigationStore()
    @State private var syncStore = SyncStore()
    @State private var authStore = AuthStore()

    var body: some Scene {
        WindowGroup {
            ContentView(
                appStore: appStore,
                navigationStore: navigationStore,
                syncStore: syncStore,
                authStore: authStore
            )
        }
    }
}
