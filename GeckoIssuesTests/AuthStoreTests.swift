import Foundation
import Testing
@testable import GeckoIssues

@Suite("AuthStore Keychain Integration Tests")
struct AuthStoreTests {

    private let testService = "com.32pixels.GeckoIssues.tests.\(ProcessInfo.processInfo.globallyUniqueString)"

    @Test("Restores session from Keychain on init")
    @MainActor
    func restoresSessionFromKeychain() throws {
        let keychain = KeychainService(service: testService)
        try keychain.saveAccessToken("ghp_restored_token")
        try keychain.saveUsername("testuser")

        let store = AuthStore(keychainService: keychain)

        #expect(store.accessToken == "ghp_restored_token")
        #expect(store.state == .authenticated(username: "testuser"))
        #expect(store.isAuthenticated == true)

        try keychain.deleteAll()
    }

    @Test("Does not restore session when Keychain is empty")
    @MainActor
    func doesNotRestoreWhenEmpty() throws {
        let keychain = KeychainService(service: testService)

        let store = AuthStore(keychainService: keychain)

        #expect(store.accessToken == nil)
        #expect(store.state == .unauthenticated)
        #expect(store.isAuthenticated == false)
    }

    @Test("Does not restore session when only token exists (no username)")
    @MainActor
    func doesNotRestoreWithoutUsername() throws {
        let keychain = KeychainService(service: testService)
        try keychain.saveAccessToken("ghp_token_only")

        let store = AuthStore(keychainService: keychain)

        #expect(store.accessToken == nil)
        #expect(store.state == .unauthenticated)

        try keychain.deleteAll()
    }

    @Test("Sign out clears Keychain credentials")
    @MainActor
    func signOutClearsKeychain() throws {
        let keychain = KeychainService(service: testService)
        try keychain.saveAccessToken("ghp_sign_out_token")
        try keychain.saveUsername("signoutuser")

        let store = AuthStore(keychainService: keychain)
        store.signOut()

        #expect(try keychain.retrieveAccessToken() == nil)
        #expect(try keychain.retrieveUsername() == nil)
        #expect(store.accessToken == nil)
        #expect(store.state == .unauthenticated)
    }
}
