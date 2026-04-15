import Foundation
import KeychainAccess

/// Manages secure storage of OAuth credentials in the macOS Keychain.
///
/// Uses the KeychainAccess library scoped to the app's bundle identifier.
/// All operations are synchronous and safe to call from any context.
struct KeychainService: Sendable {

    // MARK: - Constants

    private static let accessTokenKey = "github_access_token"
    private static let usernameKey = "github_username"

    // MARK: - Properties

    private nonisolated(unsafe) let keychain: Keychain

    // MARK: - Initialization

    init(service: String = Bundle.main.bundleIdentifier ?? "com.32pixels.GeckoIssues") {
        self.keychain = Keychain(service: service)
    }

    // MARK: - Access Token

    /// Save an OAuth access token to the Keychain.
    func saveAccessToken(_ token: String) throws {
        try keychain.set(token, key: Self.accessTokenKey)
    }

    /// Retrieve the stored OAuth access token, if any.
    func retrieveAccessToken() throws -> String? {
        try keychain.get(Self.accessTokenKey)
    }

    /// Delete the stored OAuth access token.
    func deleteAccessToken() throws {
        try keychain.remove(Self.accessTokenKey)
    }

    // MARK: - Username

    /// Save the authenticated GitHub username to the Keychain.
    func saveUsername(_ username: String) throws {
        try keychain.set(username, key: Self.usernameKey)
    }

    /// Retrieve the stored GitHub username, if any.
    func retrieveUsername() throws -> String? {
        try keychain.get(Self.usernameKey)
    }

    /// Delete the stored GitHub username.
    func deleteUsername() throws {
        try keychain.remove(Self.usernameKey)
    }

    // MARK: - Bulk Operations

    /// Delete all stored credentials (token and username).
    func deleteAll() throws {
        try deleteAccessToken()
        try deleteUsername()
    }
}
