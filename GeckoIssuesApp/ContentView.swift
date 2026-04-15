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
                }

                if let error = authStore.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
            .padding()
        }
    }
}
