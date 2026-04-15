import Foundation
import AppKit

/// Manages OAuth Device Flow authentication with GitHub.
///
/// Orchestrates the sign-in lifecycle: initiating device flow, polling for
/// authorization, storing the access token, and handling errors. Keychain
/// persistence is handled separately — this store holds the token in memory.
@MainActor @Observable
final class AuthStore {

    // MARK: - Types

    enum AuthState: Equatable {
        case unauthenticated
        case authorizing(userCode: String, verificationURL: String)
        case authenticated(username: String)
    }

    // MARK: - Properties

    private(set) var state: AuthState = .unauthenticated
    private(set) var accessToken: String?
    var errorMessage: String?

    var isAuthenticated: Bool { accessToken != nil }

    // MARK: - Dependencies

    private let deviceFlowService: DeviceFlowService

    // MARK: - Internal

    private var pollTask: Task<Void, Never>?

    // MARK: - Initialization

    init(deviceFlowService: DeviceFlowService = DeviceFlowService()) {
        self.deviceFlowService = deviceFlowService
    }

    // MARK: - Sign In

    /// Start the GitHub Device Flow sign-in process.
    func signIn() {
        guard case .unauthenticated = state else { return }

        errorMessage = nil
        pollTask = Task {
            do {
                let deviceCode = try await deviceFlowService.requestDeviceCode()

                state = .authorizing(
                    userCode: deviceCode.userCode,
                    verificationURL: deviceCode.verificationURI
                )

                // Open the verification URL in the default browser
                if let url = URL(string: deviceCode.verificationURI) {
                    NSWorkspace.shared.open(url)
                }

                let token = try await deviceFlowService.pollForAccessToken(
                    deviceCode: deviceCode.deviceCode,
                    interval: deviceCode.interval
                )

                accessToken = token

                let username = try await fetchUsername(token: token)
                state = .authenticated(username: username)

            } catch is CancellationError {
                state = .unauthenticated
            } catch let error as URLError where error.code == .notConnectedToInternet
                || error.code == .timedOut
                || error.code == .cannotConnectToHost {
                errorMessage = "You appear to be offline. Please check your internet connection and try again."
                state = .unauthenticated
            } catch {
                errorMessage = error.localizedDescription
                state = .unauthenticated
            }
        }
    }

    /// Cancel an in-progress sign-in.
    func cancelSignIn() {
        pollTask?.cancel()
        pollTask = nil
        state = .unauthenticated
        errorMessage = nil
    }

    // MARK: - Sign Out

    /// Sign out and clear the access token.
    func signOut() {
        pollTask?.cancel()
        pollTask = nil
        accessToken = nil
        state = .unauthenticated
        errorMessage = nil
    }

    // MARK: - Helpers

    /// Fetch the authenticated user's login name from the GitHub API.
    private func fetchUsername(token: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.github.com/user")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw DeviceFlowError.httpError(
                (response as? HTTPURLResponse)?.statusCode ?? 0,
                String(data: data, encoding: .utf8) ?? ""
            )
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        guard let login = json["login"] as? String else {
            throw DeviceFlowError.pollFailed("Failed to fetch GitHub username.")
        }

        return login
    }
}
