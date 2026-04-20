#if DEBUG
import Foundation

/// A canned implementation of `SyncServiceProtocol` for use in SwiftUI previews.
struct PreviewSyncService: SyncServiceProtocol {

    var orgs: [GitHubSyncService.OrganizationData] = []
    var repos: [GitHubSyncService.RepositoryData] = []

    func fetchViewer(token: String) async throws -> GitHubSyncService.ViewerData {
        GitHubSyncService.ViewerData(databaseId: 1, login: "octocat", avatarUrl: nil)
    }

    func fetchViewerWithOrganizations(token: String) async throws -> GitHubSyncService.ViewerWithOrganizationsData {
        GitHubSyncService.ViewerWithOrganizationsData(
            viewer: GitHubSyncService.ViewerData(databaseId: 1, login: "octocat", avatarUrl: nil),
            organizations: orgs
        )
    }

    func fetchRepositories(token: String) async throws -> [GitHubSyncService.RepositoryData] {
        repos
    }

    func fetchOrganizationRepositories(login: String, token: String) async throws -> [GitHubSyncService.RepositoryData] {
        repos
    }

    func fetchIssues(owner: String, name: String, token: String) async throws -> [GitHubSyncService.IssueData] {
        []
    }
}

// MARK: - Sample Data

extension GitHubSyncService.OrganizationData {
    static let preview = GitHubSyncService.OrganizationData(databaseId: 42, login: "32pixels", avatarUrl: nil)
}

extension GitHubSyncService.RepositoryData {
    static func preview(id: Int64, name: String, isPrivate: Bool = false) -> Self {
        GitHubSyncService.RepositoryData(
            databaseId: id,
            name: name,
            nameWithOwner: "octocat/\(name)",
            isPrivate: isPrivate,
            description: nil,
            url: "https://github.com/octocat/\(name)",
            owner: GitHubSyncService.OwnerData(databaseId: 1, login: "octocat", avatarUrl: nil, typeName: "User")
        )
    }
}
#endif
