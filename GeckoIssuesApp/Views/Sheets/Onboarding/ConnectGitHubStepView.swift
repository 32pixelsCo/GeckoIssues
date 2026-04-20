import SwiftUI

/// Step 1 of the onboarding wizard: connect to GitHub via OAuth Device Flow.
///
/// Shows a three-step vertical progress list: Authenticate → Enter code → Authorize device.
struct ConnectGitHubStepView: View {
    var authStore: AuthStore
    var onCancel: () -> Void
    var onContinue: () -> Void

    @FocusState private var continueButtonFocused: Bool
    @FocusState private var signInButtonFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Text("Connect to GitHub")
                .font(.system(size: 15, weight: .semibold))
                .padding(.top, 24)


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

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Continue", action: onContinue)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!authStore.isAuthenticated)
                    .focused($continueButtonFocused)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .onChange(of: authStore.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                continueButtonFocused = true
            }
        }
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

// MARK: - Step Row

enum AuthStepState {
    case upcoming   // hollow circle, dimmed title
    case active     // filled accent circle, normal title, content shown
    case waiting    // hollow circle + spinner inline, dimmed title
    case completed  // green checkmark
}

private struct AuthStepRow<Content: View>: View {
    let number: Int
    let title: String
    let state: AuthStepState
    let isLast: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Left column: indicator + connector line
            VStack(spacing: 0) {
                indicator
                    .frame(width: 24, height: 24)
                if !isLast {
                    Rectangle()
                        .fill(connectorColor)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .padding(.vertical, 4)
                }
            }
            .frame(width: 24)
            .frame(maxHeight: .infinity, alignment: .top)

            // Right column: title + optional content
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 13, weight: state == .upcoming ? .regular : .medium))
                        .foregroundStyle(state == .upcoming ? Color.secondary : Color.primary)
                    if state == .waiting {
                        ProgressView()
                            .controlSize(.mini)
                            .scaleEffect(0.75)
                    }
                }
                content()
            }
            .padding(.top, 3)
            .padding(.bottom, isLast ? 0 : 16)
        }
    }

    @ViewBuilder
    private var indicator: some View {
        switch state {
        case .upcoming, .waiting:
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.35), lineWidth: 1.5)
                Text("\(number)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        case .active:
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                Text("\(number)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            }
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(Color.accentColor)
        }
    }

    private var connectorColor: Color {
        state == .completed ? .accentColor.opacity(0.35) : Color.secondary.opacity(0.2)
    }
}

// MARK: - Previews

#Preview("Unauthenticated") {
    ConnectGitHubStepView(
        authStore: AuthStore(previewState: .unauthenticated),
        onCancel: {},
        onContinue: {}
    )
    .frame(width: 520, height: 460)
}

#Preview("Authorizing") {
    ConnectGitHubStepView(
        authStore: AuthStore(previewState: .authorizing(userCode: "ABCD-1234", verificationURL: "https://github.com/login/device")),
        onCancel: {},
        onContinue: {}
    )
    .frame(width: 520, height: 460)
}

#Preview("Authenticated") {
    ConnectGitHubStepView(
        authStore: AuthStore(previewState: .authenticated(username: "octocat")),
        onCancel: {},
        onContinue: {}
    )
    .frame(width: 520, height: 460)
}
