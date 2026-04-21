import SwiftUI

/// Settings tab for managing the GitHub connection.
struct GitHubSettingsTab: View {
    var authStore: AuthStore

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            switch authStore.state {
            case .unauthenticated:
                disconnectedView
            case .authorizing(let userCode, _):
                authorizingView(userCode: userCode)
            case .authenticated(let username):
                connectedView(username: username)
            }

            if let error = authStore.errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Disconnected

    private var disconnectedView: some View {
        Group {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Connect to GitHub")
                .font(.system(size: 15, weight: .semibold))

            Text("Sign in with your GitHub account to sync repositories and issues.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            Button("Sign In with GitHub") {
                authStore.signIn()
            }
            .accessibilityLabel("Sign in with GitHub")
        }
    }

    // MARK: - Authorizing

    private func authorizingView(userCode: String) -> some View {
        Group {
            ProgressView()
                .controlSize(.small)

            Text("Enter this code on GitHub")
                .font(.system(size: 15, weight: .semibold))

            Text(userCode)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .textSelection(.enabled)
                .accessibilityLabel("Device code: \(userCode)")

            Text("A browser window has opened to github.com.\nPaste the code above to sign in.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            HStack(spacing: 12) {
                Button("Copy Code") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(userCode, forType: .string)
                }
                .accessibilityLabel("Copy device code to clipboard")

                Button("Cancel") {
                    authStore.cancelSignIn()
                }
                .accessibilityLabel("Cancel sign in")
            }
        }
    }

    // MARK: - Connected

    private func connectedView(username: String) -> some View {
        Group {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.green)

            Text("Connected as @\(username)")
                .font(.system(size: 15, weight: .semibold))

            Button("Sign Out") {
                authStore.signOut()
            }
            .accessibilityLabel("Sign out of GitHub")
        }
    }
}
