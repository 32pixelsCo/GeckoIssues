import Foundation

/// Handles the GitHub OAuth Device Flow network requests.
///
/// Device Flow: app requests a device code -> user enters code at github.com/login/device
/// -> app polls until authorized -> receives access token.
struct DeviceFlowService: Sendable {
    static let clientID = "REPLACE_WITH_CLIENT_ID"

    private static let scope = "repo read:org read:project"
    private static let deviceCodeURL = URL(string: "https://github.com/login/device/code")!
    private static let accessTokenURL = URL(string: "https://github.com/login/oauth/access_token")!

    // MARK: - Response Types

    struct DeviceCodeResponse: Sendable {
        let deviceCode: String
        let userCode: String
        let verificationURI: String
        let expiresIn: Int
        let interval: Int
    }

    // MARK: - Device Flow

    /// Step 1: Request a device code from GitHub.
    func requestDeviceCode() async throws -> DeviceCodeResponse {
        var request = URLRequest(url: Self.deviceCodeURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "client_id=\(Self.clientID)&scope=\(Self.scope)"
        request.httpBody = Data(body.utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        guard let deviceCode = json["device_code"] as? String,
              let userCode = json["user_code"] as? String,
              let verificationURI = json["verification_uri"] as? String else {
            let errorDesc = json["error_description"] as? String ?? "Unknown error"
            throw DeviceFlowError.deviceCodeFailed(errorDesc)
        }

        return DeviceCodeResponse(
            deviceCode: deviceCode,
            userCode: userCode,
            verificationURI: verificationURI,
            expiresIn: json["expires_in"] as? Int ?? 900,
            interval: json["interval"] as? Int ?? 5
        )
    }

    /// Step 2: Poll for the access token until the user authorizes.
    ///
    /// Returns the access token string on success.
    /// Throws `CancellationError` if the task is cancelled.
    func pollForAccessToken(deviceCode: String, interval: Int) async throws -> String {
        var pollInterval = interval

        while !Task.isCancelled {
            try await Task.sleep(for: .seconds(pollInterval))
            try Task.checkCancellation()

            var request = URLRequest(url: Self.accessTokenURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

            let body = "client_id=\(Self.clientID)&device_code=\(deviceCode)&grant_type=urn:ietf:params:oauth:grant-type:device_code"
            request.httpBody = Data(body.utf8)

            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

            if let token = json["access_token"] as? String {
                return token
            }

            let error = json["error"] as? String ?? ""
            switch error {
            case "authorization_pending":
                continue
            case "slow_down":
                pollInterval += 5
                continue
            case "expired_token":
                throw DeviceFlowError.codeExpired
            case "access_denied":
                throw DeviceFlowError.accessDenied
            default:
                let desc = json["error_description"] as? String ?? error
                throw DeviceFlowError.pollFailed(desc)
            }
        }

        throw CancellationError()
    }

    // MARK: - Helpers

    private func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw DeviceFlowError.httpError(httpResponse.statusCode, body)
        }
    }
}

// MARK: - Errors

enum DeviceFlowError: LocalizedError {
    case deviceCodeFailed(String)
    case codeExpired
    case accessDenied
    case pollFailed(String)
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .deviceCodeFailed(let desc):
            "Failed to start sign-in: \(desc)"
        case .codeExpired:
            "The sign-in code expired. Please try again."
        case .accessDenied:
            "Access was denied. Please try again."
        case .pollFailed(let desc):
            "Sign-in failed: \(desc)"
        case .httpError(let code, _):
            "GitHub returned an error (HTTP \(code))."
        }
    }
}
