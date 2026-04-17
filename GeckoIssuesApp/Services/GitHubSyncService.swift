import Foundation
import os

// MARK: - Protocol

/// Abstraction over GitHub data fetching for testability.
protocol SyncServiceProtocol: Sendable {
    func fetchViewer(token: String) async throws -> GitHubSyncService.ViewerData
    func fetchViewerWithOrganizations(token: String) async throws -> GitHubSyncService.ViewerWithOrganizationsData
    func fetchRepositories(token: String) async throws -> [GitHubSyncService.RepositoryData]
    func fetchOrganizationRepositories(login: String, token: String) async throws -> [GitHubSyncService.RepositoryData]
    func fetchIssues(owner: String, name: String, token: String) async throws -> [GitHubSyncService.IssueData]
}

// MARK: - Service

/// Fetches repositories, issues, and related data from GitHub's GraphQL API.
struct GitHubSyncService: SyncServiceProtocol, Sendable {

    private let client: GraphQLClient
    private static let logger = Logger(subsystem: "com.32pixels.GeckoIssues", category: "GitHubSyncService")

    init(client: GraphQLClient = GraphQLClient()) {
        self.client = client
    }

    // MARK: - Fetch Viewer

    func fetchViewer(token: String) async throws -> ViewerData {
        let response: ViewerResponse = try await client.execute(
            query: Queries.viewer,
            token: token
        )
        let v = response.viewer
        return ViewerData(
            databaseId: v.databaseId,
            login: v.login,
            avatarUrl: v.avatarUrl
        )
    }

    // MARK: - Fetch Repositories

    func fetchRepositories(token: String) async throws -> [RepositoryData] {
        let nodes: [RepoNode] = try await client.executePaginated(
            query: Queries.repositories,
            token: token
        ) { (response: ViewerReposResponse) in
            let conn = response.viewer.repositories
            return GraphQLClient.Page(
                data: conn.nodes,
                pageInfo: conn.pageInfo
            )
        }

        return nodes.map { node in
            RepositoryData(
                databaseId: node.databaseId,
                name: node.name,
                nameWithOwner: node.nameWithOwner,
                isPrivate: node.isPrivate,
                description: node.description,
                url: node.url,
                owner: OwnerData(
                    databaseId: node.owner.databaseId,
                    login: node.owner.login,
                    avatarUrl: node.owner.avatarUrl,
                    typeName: node.owner.typeName
                )
            )
        }
    }

    // MARK: - Fetch Organization Repositories

    func fetchOrganizationRepositories(login: String, token: String) async throws -> [RepositoryData] {
        let nodes: [RepoNode] = try await client.executePaginated(
            query: Queries.organizationRepositories,
            variables: ["login": login],
            token: token
        ) { (response: OrgReposResponse) in
            let conn = response.organization.repositories
            return GraphQLClient.Page(
                data: conn.nodes,
                pageInfo: conn.pageInfo
            )
        }

        return nodes.map { node in
            RepositoryData(
                databaseId: node.databaseId,
                name: node.name,
                nameWithOwner: node.nameWithOwner,
                isPrivate: node.isPrivate,
                description: node.description,
                url: node.url,
                owner: OwnerData(
                    databaseId: node.owner.databaseId,
                    login: node.owner.login,
                    avatarUrl: node.owner.avatarUrl,
                    typeName: node.owner.typeName
                )
            )
        }
    }

    // MARK: - Fetch Issues

    func fetchIssues(owner: String, name: String, token: String) async throws -> [IssueData] {
        let nodes: [IssueNode] = try await client.executePaginated(
            query: Queries.issues,
            variables: ["owner": owner, "name": name],
            token: token
        ) { (response: RepoIssuesResponse) in
            let conn = response.repository.issues
            return GraphQLClient.Page(
                data: conn.nodes,
                pageInfo: conn.pageInfo
            )
        }

        return nodes.map(mapIssueNode)
    }

    // MARK: - Fetch Viewer + Organizations

    func fetchViewerWithOrganizations(token: String) async throws -> ViewerWithOrganizationsData {
        let response: ViewerWithOrgsResponse = try await client.execute(
            query: Queries.viewerWithOrgs,
            token: token
        )
        let v = response.viewer
        return ViewerWithOrganizationsData(
            viewer: ViewerData(databaseId: v.databaseId, login: v.login, avatarUrl: v.avatarUrl),
            organizations: v.organizations.nodes.map { org in
                OrganizationData(databaseId: org.databaseId, login: org.login, avatarUrl: org.avatarUrl)
            }
        )
    }

    private func mapIssueNode(_ node: IssueNode) -> IssueData {
        IssueData(
            databaseId: node.databaseId,
            number: node.number,
            title: node.title,
            body: node.body,
            state: node.state,
            url: node.url,
            createdAt: node.createdAt,
            updatedAt: node.updatedAt,
            closedAt: node.closedAt,
            authorLogin: node.author?.login,
            milestone: node.milestone.map { m in
                MilestoneData(
                    databaseId: numericId(from: m.id),
                    number: m.number,
                    title: m.title,
                    description: m.description,
                    state: m.state,
                    dueOn: m.dueOn
                )
            },
            labels: node.labels.nodes.map { l in
                LabelData(
                    databaseId: numericId(from: l.id),
                    name: l.name,
                    color: l.color,
                    description: l.description
                )
            },
            assignees: node.assignees.nodes.map { u in
                UserData(databaseId: u.databaseId, login: u.login, avatarUrl: u.avatarUrl)
            },
            comments: node.comments.nodes.map { c in
                CommentData(
                    databaseId: numericId(from: c.id),
                    authorLogin: c.author?.login,
                    body: c.body,
                    createdAt: c.createdAt,
                    updatedAt: c.updatedAt
                )
            }
        )
    }
}

// MARK: - Public Data Types

extension GitHubSyncService {

    struct ViewerData: Sendable {
        let databaseId: Int64
        let login: String
        let avatarUrl: String?
    }

    struct OwnerData: Sendable {
        let databaseId: Int64
        let login: String
        let avatarUrl: String?
        let typeName: String // "User" or "Organization"
    }

    struct RepositoryData: Sendable {
        let databaseId: Int64
        let name: String
        let nameWithOwner: String
        let isPrivate: Bool
        let description: String?
        let url: String
        let owner: OwnerData
    }

    struct MilestoneData: Sendable {
        let databaseId: Int64
        let number: Int
        let title: String
        let description: String?
        let state: String // "OPEN" or "CLOSED"
        let dueOn: String?
    }

    struct LabelData: Sendable {
        let databaseId: Int64
        let name: String
        let color: String
        let description: String?
    }

    struct UserData: Sendable {
        let databaseId: Int64
        let login: String
        let avatarUrl: String?
    }

    struct CommentData: Sendable {
        let databaseId: Int64
        let authorLogin: String?
        let body: String
        let createdAt: String
        let updatedAt: String
    }

    struct OrganizationData: Sendable {
        let databaseId: Int64
        let login: String
        let avatarUrl: String?
    }

    struct ViewerWithOrganizationsData: Sendable {
        let viewer: ViewerData
        let organizations: [OrganizationData]
    }

    struct IssueData: Sendable {
        let databaseId: Int64
        let number: Int
        let title: String
        let body: String?
        let state: String // "OPEN" or "CLOSED"
        let url: String
        let createdAt: String
        let updatedAt: String
        let closedAt: String?
        let authorLogin: String?
        let milestone: MilestoneData?
        let labels: [LabelData]
        let assignees: [UserData]
        let comments: [CommentData]
    }
}

// MARK: - GraphQL Response Types (private)

private struct ViewerResponse: Decodable, Sendable {
    let viewer: ViewerNode
}

private struct ViewerNode: Decodable, Sendable {
    let databaseId: Int64
    let login: String
    let avatarUrl: String?
}

private struct ViewerReposResponse: Decodable, Sendable {
    let viewer: ViewerReposNode
}

private struct ViewerReposNode: Decodable, Sendable {
    let repositories: RepoConnection
}

private struct RepoConnection: Decodable, Sendable {
    let nodes: [RepoNode]
    let pageInfo: GraphQLClient.PageInfo
}

private struct RepoNode: Decodable, Sendable {
    let databaseId: Int64
    let name: String
    let nameWithOwner: String
    let isPrivate: Bool
    let description: String?
    let url: String
    let owner: OwnerNode
}

private struct OwnerNode: Decodable, Sendable {
    let databaseId: Int64
    let login: String
    let avatarUrl: String?
    let typeName: String

    enum CodingKeys: String, CodingKey {
        case databaseId, login, avatarUrl
        case typeName = "__typename"
    }
}

private struct ViewerWithOrgsResponse: Decodable, Sendable {
    let viewer: ViewerWithOrgsNode
}

private struct ViewerWithOrgsNode: Decodable, Sendable {
    let databaseId: Int64
    let login: String
    let avatarUrl: String?
    let organizations: OrgMemberConnection
}

private struct OrgMemberConnection: Decodable, Sendable {
    let nodes: [OrgMemberNode]
}

private struct OrgMemberNode: Decodable, Sendable {
    let databaseId: Int64
    let login: String
    let avatarUrl: String?
}

private struct OrgReposResponse: Decodable, Sendable {
    let organization: OrgReposNode
}

private struct OrgReposNode: Decodable, Sendable {
    let repositories: RepoConnection
}

private struct RepoIssuesResponse: Decodable, Sendable {
    let repository: RepositoryIssuesNode
}

private struct RepositoryIssuesNode: Decodable, Sendable {
    let issues: IssueConnection
}

private struct IssueConnection: Decodable, Sendable {
    let nodes: [IssueNode]
    let pageInfo: GraphQLClient.PageInfo
}

private struct IssueNode: Decodable, Sendable {
    let databaseId: Int64
    let number: Int
    let title: String
    let body: String?
    let state: String
    let url: String
    let createdAt: String
    let updatedAt: String
    let closedAt: String?
    let author: AuthorNode?
    let milestone: MilestoneNode?
    let labels: LabelConnection
    let assignees: AssigneeConnection
    let comments: CommentConnection
}

private struct AuthorNode: Decodable, Sendable {
    let login: String
}

private struct MilestoneNode: Decodable, Sendable {
    let id: String
    let number: Int
    let title: String
    let description: String?
    let state: String
    let dueOn: String?
}

private struct LabelConnection: Decodable, Sendable {
    let nodes: [LabelNode]
}

private struct LabelNode: Decodable, Sendable {
    let id: String
    let name: String
    let color: String
    let description: String?
}

private struct AssigneeConnection: Decodable, Sendable {
    let nodes: [AssigneeNode]
}

private struct AssigneeNode: Decodable, Sendable {
    let databaseId: Int64
    let login: String
    let avatarUrl: String?
}

private struct CommentConnection: Decodable, Sendable {
    let nodes: [CommentNode]
}

private struct CommentNode: Decodable, Sendable {
    let id: String
    let author: AuthorNode?
    let body: String
    let createdAt: String
    let updatedAt: String
}

// MARK: - GraphQL Queries

private enum Queries {

    static let viewerWithOrgs = """
    query {
      viewer {
        databaseId
        login
        avatarUrl
        organizations(first: 100) {
          nodes {
            databaseId
            login
            avatarUrl
          }
        }
      }
    }
    """

    static let viewer = """
    query {
      viewer {
        databaseId
        login
        avatarUrl
      }
    }
    """

    static let repositories = """
    query($after: String) {
      viewer {
        repositories(
          first: 100,
          after: $after,
          ownerAffiliations: [OWNER, COLLABORATOR, ORGANIZATION_MEMBER]
        ) {
          nodes {
            databaseId
            name
            nameWithOwner
            isPrivate
            description
            url
            owner {
              ... on User { databaseId login avatarUrl }
              ... on Organization { databaseId login avatarUrl }
              __typename
            }
          }
          pageInfo { hasNextPage endCursor }
        }
      }
    }
    """

    static let organizationRepositories = """
    query($login: String!, $after: String) {
      organization(login: $login) {
        repositories(
          first: 100,
          after: $after
        ) {
          nodes {
            databaseId
            name
            nameWithOwner
            isPrivate
            description
            url
            owner {
              ... on User { databaseId login avatarUrl }
              ... on Organization { databaseId login avatarUrl }
              __typename
            }
          }
          pageInfo { hasNextPage endCursor }
        }
      }
    }
    """

    static let issues = """
    query($owner: String!, $name: String!, $after: String) {
      repository(owner: $owner, name: $name) {
        issues(
          first: 50,
          after: $after,
          states: [OPEN, CLOSED],
          orderBy: { field: UPDATED_AT, direction: DESC }
        ) {
          nodes {
            databaseId
            number
            title
            body
            state
            url
            createdAt
            updatedAt
            closedAt
            author { login }
            milestone {
              id
              number
              title
              description
              state
              dueOn
            }
            labels(first: 100) {
              nodes { id name color description }
            }
            assignees(first: 100) {
              nodes { databaseId login avatarUrl }
            }
            comments(first: 100) {
              nodes {
                id
                author { login }
                body
                createdAt
                updatedAt
              }
            }
          }
          pageInfo { hasNextPage endCursor }
        }
      }
    }
    """
}

// MARK: - Node ID Helpers

/// Extract a numeric database ID from a GitHub GraphQL node ID.
///
/// GitHub node IDs are base64-encoded strings like `MDk6TWlsZXN0b25lMTIz`
/// which decode to `09:Milestone123`. The trailing digits are the database ID.
/// Falls back to a stable hash if the format is unexpected.
private func numericId(from nodeId: String) -> Int64 {
    if let data = Data(base64Encoded: nodeId),
       let decoded = String(data: data, encoding: .utf8) {
        // Extract trailing digits: "09:Milestone123" → "123"
        let digits = String(decoded.reversed().prefix(while: \.isNumber).reversed())
        if let id = Int64(digits), id > 0 {
            return id
        }
    }
    // Fallback: stable hash for unexpected formats
    var hasher = Hasher()
    hasher.combine(nodeId)
    return Int64(abs(hasher.finalize()))
}
