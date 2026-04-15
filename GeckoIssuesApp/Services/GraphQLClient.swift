import Foundation
import os

/// Lightweight GitHub GraphQL API client.
///
/// Sends queries to `https://api.github.com/graphql`, attaches the OAuth bearer token,
/// decodes typed responses via `Codable`, and handles errors, rate limiting, and
/// cursor-based pagination.
struct GraphQLClient: Sendable {

    private static let endpoint = URL(string: "https://api.github.com/graphql")!
    private static let logger = Logger(subsystem: "com.32pixels.GeckoIssues", category: "GraphQLClient")

    // MARK: - Execute

    /// Execute a GraphQL query and decode the response into `T`.
    ///
    /// The decoded type `T` maps to the `"data"` field of the GraphQL response envelope.
    /// For example, if the response is `{ "data": { "viewer": { "login": "octocat" } } }`,
    /// define a struct matching that shape and pass it as `T`.
    func execute<T: Decodable & Sendable>(
        query: String,
        variables: [String: any Encodable & Sendable]? = nil,
        token: String
    ) async throws -> T {
        let request = try buildRequest(query: query, variables: variables, token: token)
        let (data, response) = try await performRequest(request)

        try validateHTTPResponse(response, data: data)

        return try decodeGraphQLResponse(data)
    }

    // MARK: - Pagination

    /// Result of a single page fetch, including page info for cursor-based pagination.
    struct Page<T: Sendable>: Sendable {
        let data: T
        let pageInfo: PageInfo
    }

    /// Standard GitHub GraphQL pagination info.
    struct PageInfo: Decodable, Sendable {
        let hasNextPage: Bool
        let endCursor: String?
    }

    /// Fetch all pages of a paginated GraphQL connection.
    ///
    /// - Parameters:
    ///   - query: The GraphQL query. Must accept an `$after: String` variable for the cursor.
    ///   - variables: Initial variables (without `after` — it's injected automatically).
    ///   - token: OAuth bearer token.
    ///   - maxPages: Safety limit on the number of pages to fetch (default 100).
    ///   - extractPage: Closure that pulls the items and `PageInfo` from each decoded response.
    /// - Returns: All collected items across every page.
    func executePaginated<T: Decodable & Sendable, Item: Sendable>(
        query: String,
        variables: [String: any Encodable & Sendable]? = nil,
        token: String,
        maxPages: Int = 100,
        extractPage: @Sendable (T) -> Page<[Item]>
    ) async throws -> [Item] {
        var allItems: [Item] = []
        var cursor: String?
        var pagesRemaining = maxPages

        while pagesRemaining > 0 {
            var vars = variables ?? [:]
            vars["after"] = cursor

            let response: T = try await execute(query: query, variables: vars, token: token)
            let page = extractPage(response)

            allItems.append(contentsOf: page.data)

            guard page.pageInfo.hasNextPage, let next = page.pageInfo.endCursor else {
                break
            }

            cursor = next
            pagesRemaining -= 1
        }

        return allItems
    }

    // MARK: - Request Building

    private func buildRequest(
        query: String,
        variables: [String: any Encodable & Sendable]?,
        token: String
    ) throws -> URLRequest {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        var body: [String: Any] = ["query": query]
        if let variables {
            body["variables"] = try encodableToJSONObject(variables)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return request
    }

    /// Convert a dictionary of `Encodable` values into a `[String: Any]` for `JSONSerialization`.
    private func encodableToJSONObject(
        _ dict: [String: any Encodable & Sendable]
    ) throws -> [String: Any] {
        var result: [String: Any] = [:]
        let encoder = JSONEncoder()
        for (key, value) in dict {
            let data = try encoder.encode(AnyEncodable(value))
            let json = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
            result[key] = json
        }
        return result
    }

    // MARK: - Response Handling

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            throw GraphQLClientError.networkError(error)
        }
    }

    private func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        let status = http.statusCode

        guard (200...299).contains(status) else {
            // Rate limit handling
            if status == 403 || status == 429 {
                let retryAfter = retryAfterInterval(from: http)
                let message = String(data: data, encoding: .utf8) ?? ""
                Self.logger.warning("Rate limited (HTTP \(status)). Retry after \(retryAfter ?? 0)s")
                throw GraphQLClientError.rateLimited(retryAfter: retryAfter, message: message)
            }

            if status == 401 {
                throw GraphQLClientError.unauthorized
            }

            let body = String(data: data, encoding: .utf8) ?? ""
            throw GraphQLClientError.httpError(statusCode: status, body: body)
        }
    }

    private func retryAfterInterval(from response: HTTPURLResponse) -> TimeInterval? {
        // Check Retry-After header first
        if let retryAfter = response.value(forHTTPHeaderField: "Retry-After"),
           let seconds = TimeInterval(retryAfter) {
            return seconds
        }
        // Fall back to x-ratelimit-reset (Unix timestamp)
        if let resetStr = response.value(forHTTPHeaderField: "x-ratelimit-reset"),
           let resetTimestamp = TimeInterval(resetStr) {
            let delay = resetTimestamp - Date().timeIntervalSince1970
            return max(delay, 0)
        }
        return nil
    }

    private func decodeGraphQLResponse<T: Decodable>(_ data: Data) throws -> T {
        let envelope = try JSONDecoder().decode(GraphQLResponseEnvelope<T>.self, from: data)

        if let errors = envelope.errors, !errors.isEmpty {
            Self.logger.error("GraphQL errors: \(errors.map(\.message).joined(separator: ", "))")
            throw GraphQLClientError.graphQLErrors(errors)
        }

        guard let responseData = envelope.data else {
            throw GraphQLClientError.emptyResponse
        }

        return responseData
    }
}

// MARK: - Response Envelope

/// The standard GraphQL response shape: `{ "data": ..., "errors": [...] }`.
private struct GraphQLResponseEnvelope<T: Decodable>: Decodable {
    let data: T?
    let errors: [GraphQLError]?
}

// MARK: - GraphQL Error

/// A single error from the GraphQL response `errors` array.
struct GraphQLError: Decodable, Sendable, CustomStringConvertible {
    let message: String
    let type: String?
    let path: [String]?

    var description: String { message }
}

// MARK: - Client Errors

enum GraphQLClientError: LocalizedError, Equatable {
    case unauthorized
    case rateLimited(retryAfter: TimeInterval?, message: String)
    case httpError(statusCode: Int, body: String)
    case graphQLErrors([GraphQLError])
    case emptyResponse
    case networkError(URLError)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            "GitHub authentication failed. Please sign in again."
        case .rateLimited(let retryAfter, _):
            if let seconds = retryAfter {
                "GitHub rate limit exceeded. Try again in \(Int(seconds)) seconds."
            } else {
                "GitHub rate limit exceeded. Please wait and try again."
            }
        case .httpError(let code, _):
            "GitHub returned an error (HTTP \(code))."
        case .graphQLErrors(let errors):
            errors.first?.message ?? "An unknown GraphQL error occurred."
        case .emptyResponse:
            "GitHub returned an empty response."
        case .networkError(let error):
            error.localizedDescription
        }
    }

    static func == (lhs: GraphQLClientError, rhs: GraphQLClientError) -> Bool {
        switch (lhs, rhs) {
        case (.unauthorized, .unauthorized):
            true
        case (.rateLimited(let a, let am), .rateLimited(let b, let bm)):
            a == b && am == bm
        case (.httpError(let a, let ab), .httpError(let b, let bb)):
            a == b && ab == bb
        case (.graphQLErrors(let a), .graphQLErrors(let b)):
            a.map(\.message) == b.map(\.message)
        case (.emptyResponse, .emptyResponse):
            true
        case (.networkError(let a), .networkError(let b)):
            a.code == b.code
        default:
            false
        }
    }
}

// MARK: - Helpers

/// Type-erased `Encodable` wrapper for encoding heterogeneous dictionaries.
private struct AnyEncodable: Encodable {
    private let _encode: @Sendable (Encoder) throws -> Void

    init(_ value: any Encodable & Sendable) {
        _encode = { encoder in try value.encode(to: encoder) }
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
