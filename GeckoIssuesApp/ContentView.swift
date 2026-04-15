import SwiftUI

struct ContentView: View {
    var appStore: AppStore
    var navigationStore: NavigationStore
    var syncStore: SyncStore
    var authStore: AuthStore

    @State private var dbStatus: String?

    var body: some View {
        NavigationSplitView {
            Text("Sidebar")
        } detail: {
            VStack(spacing: 16) {
                switch authStore.state {
                case .unauthenticated:
                    Text("Not signed in")
                        .foregroundStyle(.secondary)
                    Button("Sign In with GitHub") {
                        authStore.signIn()
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
                    Button("Sign Out") {
                        authStore.signOut()
                    }

                    // TODO: Remove — temporary button to verify database creation
                    Button("Create Database") {
                        do {
                            let db = try AppDatabase()
                            let tables = try db.dbQueue.read { db in
                                try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
                            }
                            dbStatus = "Created \(tables.count) tables: \(tables.joined(separator: ", "))"
                        } catch {
                            dbStatus = "Error: \(error.localizedDescription)"
                        }
                    }
                }

                if let error = authStore.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.callout)
                }

                if let dbStatus {
                    Text(dbStatus)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
    }
}
