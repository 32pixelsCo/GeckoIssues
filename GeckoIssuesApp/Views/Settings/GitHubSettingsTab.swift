import SwiftUI

/// Settings tab for managing the GitHub connection.
///
/// When connected, shows a green checkmark with Disconnect/Reauthorize actions.
/// When disconnected or reauthorizing, shows the 3-step auth stepper inline.
struct GitHubSettingsTab: View {
    var authStore: AuthStore

    @FocusState private var signInButtonFocused: Bool

    var body: some View {
        if authStore.isAuthenticated {
            connectedView
        } else {
            stepperView
        }
    }

    // MARK: - Connected

    private var connectedView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.green)

            if case .authenticated(let username) = authStore.state {
                Text("Connected as @\(username)")
                    .font(.system(size: 15, weight: .semibold))
            }

            Button("Reauthorize") {
                authStore.signOut()
            }
            .accessibilityLabel("Reauthorize GitHub connection")

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Stepper

    private var stepperView: some View {
        VStack(spacing: 0) {
            Text("Connect to GitHub")
                .font(.system(size: 15, weight: .semibold))
                .padding(.top, 32)

            Spacer().frame(height: 32)

            VStack(alignment: .leading, spacing: 0) {
                AuthStepRow(
                    number: 1,
                    title: "Sign in",
                    state: step1State,
                    isLast: false
                ) {
                    authenticateContent
                }

                AuthStepRow(
                    number: 2,
                    title: "Enter code",
                    state: step2State,
                    isLast: false
                ) {
                    enterCodeContent
                }

                AuthStepRow(
                    number: 3,
                    title: "Authorize device",
                    state: step3State,
                    isLast: true
                ) {
                    if case .authenticated(let username) = authStore.state {
                        Text("Successfully connected as \(username).")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.leading, 40)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Step States

    private var step1State: AuthStepState {
        switch authStore.state {
        case .unauthenticated: .active
        case .authorizing, .authenticated: .completed
        }
    }

    private var step2State: AuthStepState {
        switch authStore.state {
        case .unauthenticated: .upcoming
        case .authorizing: .active
        case .authenticated: .completed
        }
    }

    private var step3State: AuthStepState {
        switch authStore.state {
        case .unauthenticated: .upcoming
        case .authorizing: .waiting
        case .authenticated: .completed
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var authenticateContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Open your browser, sign in, then return here to get your code.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("Sign in with GitHub") {
                    authStore.signIn()
                }
                .controlSize(.large)
                .accessibilityLabel("Sign in with GitHub")
                .disabled(step1State == .completed)
                .focused($signInButtonFocused)

                if step1State == .completed {
                    Button {
                        authStore.signOut()
                        signInButtonFocused = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.circlepath")
                            Text("Restart")
                        }
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Restart sign-in")
                }
            }

            if let error = authStore.errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var enterCodeContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("After signing in, enter this code when prompted:")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                if case .authorizing(let userCode, _) = authStore.state {
                    Text(userCode)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .textSelection(.enabled)
                        .accessibilityLabel("Authorization code: \(userCode)")
                    CopyButton(value: userCode)
                } else {
                    Text("XXXX-XXXX")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}
