import Foundation
import Testing
@testable import GeckoIssues

// MARK: - Response Decoding Tests

@Suite("GraphQLClient Response Decoding")
struct GraphQLClientDecodingTests {

    private let client = GraphQLClient()

    @Test("Decodes a successful GraphQL response")
    func decodesSuccessfulResponse() async throws {
        let json = """
        {"data": {"viewer": {"login": "octocat"}}}
        """
        let result: ViewerResponse = try decodeGraphQLData(json)
        #expect(result.viewer.login == "octocat")
    }

    @Test("Throws graphQLErrors when response contains errors")
    func throwsOnGraphQLErrors() async {
        let json = """
        {"data": null, "errors": [{"message": "Field 'foo' not found", "type": "FIELD_ERROR"}]}
        """
        await #expect(throws: GraphQLClientError.self) {
            let _: ViewerResponse = try decodeGraphQLData(json)
        }
    }

    @Test("Throws emptyResponse when data is null and no errors")
    func throwsOnEmptyResponse() async {
        let json = """
        {"data": null}
        """
        await #expect(throws: GraphQLClientError.self) {
            let _: ViewerResponse = try decodeGraphQLData(json)
        }
    }

    @Test("Decodes GraphQL errors with all fields")
    func decodesGraphQLErrorFields() throws {
        let json = """
        {"data": null, "errors": [{"message": "Not found", "type": "NOT_FOUND", "path": ["repository", "issue"]}]}
        """
        do {
            let _: ViewerResponse = try decodeGraphQLData(json)
            Issue.record("Expected GraphQLClientError")
        } catch let error as GraphQLClientError {
            if case .graphQLErrors(let errors) = error {
                #expect(errors.count == 1)
                #expect(errors[0].message == "Not found")
                #expect(errors[0].type == "NOT_FOUND")
                #expect(errors[0].path == ["repository", "issue"])
            } else {
                Issue.record("Expected .graphQLErrors, got \(error)")
            }
        }
    }

    @Test("Decodes nested data structures")
    func decodesNestedStructures() throws {
        let json = """
        {"data": {"repository": {"issues": {"nodes": [{"title": "Bug"}, {"title": "Feature"}], "pageInfo": {"hasNextPage": false, "endCursor": null}}}}}
        """
        let result: RepositoryIssuesResponse = try decodeGraphQLData(json)
        #expect(result.repository.issues.nodes.count == 2)
        #expect(result.repository.issues.nodes[0].title == "Bug")
        #expect(result.repository.issues.pageInfo.hasNextPage == false)
    }
}

// MARK: - Error Equatable Tests

@Suite("GraphQLClientError Equatable")
struct GraphQLClientErrorTests {

    @Test("Unauthorized errors are equal")
    func unauthorizedEquality() {
        #expect(GraphQLClientError.unauthorized == GraphQLClientError.unauthorized)
    }

    @Test("Rate limited errors compare correctly")
    func rateLimitedEquality() {
        let a = GraphQLClientError.rateLimited(retryAfter: 60, message: "limit")
        let b = GraphQLClientError.rateLimited(retryAfter: 60, message: "limit")
        let c = GraphQLClientError.rateLimited(retryAfter: 30, message: "limit")
        #expect(a == b)
        #expect(a != c)
    }

    @Test("HTTP errors compare correctly")
    func httpErrorEquality() {
        let a = GraphQLClientError.httpError(statusCode: 500, body: "error")
        let b = GraphQLClientError.httpError(statusCode: 500, body: "error")
        let c = GraphQLClientError.httpError(statusCode: 502, body: "error")
        #expect(a == b)
        #expect(a != c)
    }

    @Test("Different error cases are not equal")
    func differentCasesNotEqual() {
        #expect(GraphQLClientError.unauthorized != GraphQLClientError.emptyResponse)
    }
}

// MARK: - Error Description Tests

@Suite("GraphQLClientError Descriptions")
struct GraphQLClientErrorDescriptionTests {

    @Test("Unauthorized has user-facing description")
    func unauthorizedDescription() {
        let error = GraphQLClientError.unauthorized
        #expect(error.errorDescription?.contains("sign in") == true)
    }

    @Test("Rate limited with retry shows seconds")
    func rateLimitedDescription() {
        let error = GraphQLClientError.rateLimited(retryAfter: 45, message: "")
        #expect(error.errorDescription?.contains("45") == true)
    }

    @Test("Rate limited without retry has fallback message")
    func rateLimitedNoRetryDescription() {
        let error = GraphQLClientError.rateLimited(retryAfter: nil, message: "")
        #expect(error.errorDescription?.contains("wait") == true)
    }

    @Test("HTTP error includes status code")
    func httpErrorDescription() {
        let error = GraphQLClientError.httpError(statusCode: 503, body: "")
        #expect(error.errorDescription?.contains("503") == true)
    }

    @Test("GraphQL error surfaces first message")
    func graphQLErrorDescription() {
        let errors = [GraphQLError(message: "Something broke", type: nil, path: nil)]
        let error = GraphQLClientError.graphQLErrors(errors)
        #expect(error.errorDescription == "Something broke")
    }
}

// MARK: - PageInfo Tests

@Suite("GraphQLClient.PageInfo")
struct PageInfoTests {

    @Test("Decodes page info with next page")
    func decodesWithNextPage() throws {
        let json = """
        {"hasNextPage": true, "endCursor": "Y3Vyc29yOnYyOpHOBg=="}
        """
        let pageInfo = try JSONDecoder().decode(GraphQLClient.PageInfo.self, from: Data(json.utf8))
        #expect(pageInfo.hasNextPage == true)
        #expect(pageInfo.endCursor == "Y3Vyc29yOnYyOpHOBg==")
    }

    @Test("Decodes page info without next page")
    func decodesWithoutNextPage() throws {
        let json = """
        {"hasNextPage": false, "endCursor": null}
        """
        let pageInfo = try JSONDecoder().decode(GraphQLClient.PageInfo.self, from: Data(json.utf8))
        #expect(pageInfo.hasNextPage == false)
        #expect(pageInfo.endCursor == nil)
    }
}

// MARK: - Test Helpers

/// Helper to test the decode path without making a network request.
private func decodeGraphQLData<T: Decodable>(_ json: String) throws -> T {
    let data = Data(json.utf8)
    let envelope = try JSONDecoder().decode(TestEnvelope<T>.self, from: data)

    if let errors = envelope.errors, !errors.isEmpty {
        throw GraphQLClientError.graphQLErrors(errors)
    }
    guard let responseData = envelope.data else {
        throw GraphQLClientError.emptyResponse
    }
    return responseData
}

private struct TestEnvelope<T: Decodable>: Decodable {
    let data: T?
    let errors: [GraphQLError]?
}

// MARK: - Test Response Types

private struct ViewerResponse: Decodable {
    let viewer: Viewer

    struct Viewer: Decodable {
        let login: String
    }
}

private struct RepositoryIssuesResponse: Decodable {
    let repository: Repository

    struct Repository: Decodable {
        let issues: IssueConnection
    }

    struct IssueConnection: Decodable {
        let nodes: [Issue]
        let pageInfo: GraphQLClient.PageInfo
    }

    struct Issue: Decodable {
        let title: String
    }
}
