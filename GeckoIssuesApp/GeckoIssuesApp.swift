import SwiftUI

@main
struct GeckoIssuesApp: App {
    @State private var appStore = AppStore()
    @State private var navigationStore = NavigationStore()
    @State private var authStore = AuthStore()
    @State private var database: AppDatabase
    @State private var syncStore: SyncStore

    init() {
        let db = try! AppDatabase()
        _database = State(initialValue: db)
        _syncStore = State(initialValue: SyncStore(database: db))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                appStore: appStore,
                navigationStore: navigationStore,
                syncStore: syncStore,
                authStore: authStore,
                database: database
            )
        }
    }
}
