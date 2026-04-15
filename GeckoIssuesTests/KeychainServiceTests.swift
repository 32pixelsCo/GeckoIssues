import Foundation
import Testing
@testable import GeckoIssues

@Suite("KeychainService Tests")
struct KeychainServiceTests {

    // Use a unique service name per test run to avoid polluting the real Keychain
    private let service = KeychainService(service: "com.32pixels.GeckoIssues.tests.\(ProcessInfo.processInfo.globallyUniqueString)")

    @Test("Save and retrieve access token")
    func saveAndRetrieveAccessToken() throws {
        try service.saveAccessToken("ghp_test_token_123")
        let retrieved = try service.retrieveAccessToken()
        #expect(retrieved == "ghp_test_token_123")
        try service.deleteAccessToken()
    }

    @Test("Retrieve returns nil when no token stored")
    func retrieveReturnsNilWhenEmpty() throws {
        let retrieved = try service.retrieveAccessToken()
        #expect(retrieved == nil)
    }

    @Test("Delete access token")
    func deleteAccessToken() throws {
        try service.saveAccessToken("ghp_to_delete")
        try service.deleteAccessToken()
        let retrieved = try service.retrieveAccessToken()
        #expect(retrieved == nil)
    }

    @Test("Save and retrieve username")
    func saveAndRetrieveUsername() throws {
        try service.saveUsername("octocat")
        let retrieved = try service.retrieveUsername()
        #expect(retrieved == "octocat")
        try service.deleteUsername()
    }

    @Test("Delete all clears token and username")
    func deleteAllClearsEverything() throws {
        try service.saveAccessToken("ghp_token")
        try service.saveUsername("octocat")
        try service.deleteAll()
        #expect(try service.retrieveAccessToken() == nil)
        #expect(try service.retrieveUsername() == nil)
    }

    @Test("Overwrite existing token")
    func overwriteExistingToken() throws {
        try service.saveAccessToken("ghp_old")
        try service.saveAccessToken("ghp_new")
        let retrieved = try service.retrieveAccessToken()
        #expect(retrieved == "ghp_new")
        try service.deleteAccessToken()
    }

    @Test("Delete nonexistent key does not throw")
    func deleteNonexistentKeyDoesNotThrow() throws {
        try service.deleteAccessToken()
        try service.deleteUsername()
    }
}
