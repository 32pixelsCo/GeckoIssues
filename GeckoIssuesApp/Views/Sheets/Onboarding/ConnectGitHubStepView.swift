import SwiftUI

/// Step 1 of the onboarding wizard: connect to GitHub via OAuth Device Flow.
struct ConnectGitHubStepView: View {
    var authStore: AuthStore
    var onCancel: () -> Void
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("Get Started")
                .font(.system(size: 15, weight: .semibold))
                .padding(.top, 24)

            Text("Connect GitHub")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            Spacer().frame(height: 24)

            authContent
                .padding(.horizontal, 40)

            Spacer()

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Continue", action: onContinue)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!authStore.isAuthenticated)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Auth Content

    @ViewBuilder
    private var authContent: some View {
        switch authStore.state {
        case .unauthenticated:
            unauthenticatedView

        case .authorizing(let userCode, _):
            authorizingView(userCode: userCode)

        case .authenticated(let username):
            connectedView(username: username)
        }
    }

    // MARK: - Unauthenticated

    private var unauthenticatedView: some View {
        VStack(spacing: 16) {
            Button {
                authStore.signIn()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                    Text("Sign in with GitHub")
                }
                .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .accessibilityLabel("Sign in with GitHub")

            Text("Opens your browser to authorize Gecko Issues.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let error = authStore.errorMessage {
                errorView(error)
            }
        }
    }

    // MARK: - Authorizing

    private func authorizingView(userCode: String) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.regular)

            Text("Waiting for authorization...")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("Enter this code on GitHub:")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(userCode)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .textSelection(.enabled)
                    .accessibilityLabel("Authorization code: \(userCode)")
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
            )

            Button("Cancel Sign In") {
                authStore.cancelSignIn()
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Cancel sign in")
        }
    }

    // MARK: - Connected

    private func connectedView(username: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.green)

            Text("Connected as @\(username)")
                .font(.system(size: 14, weight: .medium))
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.green.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.green.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Error

    private func errorView(_ error: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(error)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.red.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.red.opacity(0.2), lineWidth: 1)
                )
        )
    }
}
