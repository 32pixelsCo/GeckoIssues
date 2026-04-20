#if DEBUG
import Foundation

/// A canned implementation of `SyncServiceProtocol` for use in SwiftUI previews.
struct PreviewSyncService: SyncServiceProtocol {

    var viewer: GitHubSyncService.ViewerData = GitHubSyncService.ViewerData(databaseId: 1, login: "octocat", avatarUrl: nil)
    var orgs: [GitHubSyncService.OrganizationData] = []
    /// Repos returned for the personal account (`fetchRepositories`).
    var personalRepos: [GitHubSyncService.RepositoryData] = []
    /// Repos returned per org login (`fetchOrganizationRepositories`). Falls back to `personalRepos` if not set.
    var orgRepos: [String: [GitHubSyncService.RepositoryData]] = [:]

    /// Convenience init for simple cases where all accounts share the same repo list.
    init(orgs: [GitHubSyncService.OrganizationData] = [], repos: [GitHubSyncService.RepositoryData] = []) {
        self.orgs = orgs
        self.personalRepos = repos
    }

    /// Full init with per-org repo lists and a custom viewer.
    init(
        viewer: GitHubSyncService.ViewerData,
        orgs: [GitHubSyncService.OrganizationData],
        personalRepos: [GitHubSyncService.RepositoryData],
        orgRepos: [String: [GitHubSyncService.RepositoryData]]
    ) {
        self.viewer = viewer
        self.orgs = orgs
        self.personalRepos = personalRepos
        self.orgRepos = orgRepos
    }

    func fetchViewer(token: String) async throws -> GitHubSyncService.ViewerData {
        viewer
    }

    func fetchViewerWithOrganizations(token: String) async throws -> GitHubSyncService.ViewerWithOrganizationsData {
        GitHubSyncService.ViewerWithOrganizationsData(viewer: viewer, organizations: orgs)
    }

    func fetchRepositories(token: String) async throws -> [GitHubSyncService.RepositoryData] {
        personalRepos
    }

    func fetchOrganizationRepositories(login: String, token: String) async throws -> [GitHubSyncService.RepositoryData] {
        orgRepos[login] ?? personalRepos
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
    static func preview(id: Int64, name: String, owner: String = "octocat", isPrivate: Bool = false) -> Self {
        GitHubSyncService.RepositoryData(
            databaseId: id,
            name: name,
            nameWithOwner: "\(owner)/\(name)",
            isPrivate: isPrivate,
            description: nil,
            url: "https://github.com/\(owner)/\(name)",
            owner: GitHubSyncService.OwnerData(databaseId: 1, login: owner, avatarUrl: nil, typeName: "User")
        )
    }
}
#endif
