import SwiftUI

struct ContentView: View {
    var appStore: AppStore
    var navigationStore: NavigationStore
    var syncStore: SyncStore
    var authStore: AuthStore

    var body: some View {
        NavigationSplitView {
            Text("Sidebar")
        } detail: {
            Text("Welcome to Gecko Issues")
        }
    }
}
