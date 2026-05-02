import Foundation

/// Picks the right URL + auth header for a Claude call.
///
/// Two modes:
/// - **Direct**: posts to `api.anthropic.com/v1/messages` with `x-api-key`
///   = the user's Anthropic key. Works out-of-the-box; key sits in Keychain
///   on the device.
/// - **Backend**: posts to `{backendBaseURL}/v1/messages` with `Authorization:
///   Bearer {backendAuthToken}`. The backend holds the real Anthropic key.
///   Required model for App Store distribution.
///
/// All call sites construct identical Anthropic-shaped JSON bodies — only
/// the URL + auth header differ. The backend reference implementation in
/// `backend/` accepts the same body and proxies upstream.
enum ClaudeRouter {
    static let directURL = URL(string: "https://api.anthropic.com/v1/messages")!

    struct Request {
        let url: URL
        var headers: [String: String]
    }

    /// Build a request configured either for direct Anthropic or for the
    /// user's backend. Caller still attaches the JSON body.
    static func request(
        anthropicKey: String,
        backendBaseURL: String,
        backendAuthToken: String
    ) -> Request {
        let key = anthropicKey
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        let backendURL = backendBaseURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let backendToken = backendAuthToken
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !backendURL.isEmpty {
            // Normalize: trim trailing slash so we can append "/v1/messages".
            let trimmedBase = backendURL.hasSuffix("/")
                ? String(backendURL.dropLast())
                : backendURL
            let resolved = URL(string: "\(trimmedBase)/v1/messages") ?? directURL
            return Request(
                url: resolved,
                headers: [
                    "content-type": "application/json",
                    "authorization": "Bearer \(backendToken)",
                ]
            )
        }

        return Request(
            url: directURL,
            headers: [
                "content-type": "application/json",
                "x-api-key": key,
                "anthropic-version": "2023-06-01",
            ]
        )
    }

    /// Convenience: returns whether the user has BOTH a configured backend URL
    /// (non-empty) and at least *some* auth, so callers can know whether the
    /// `anthropicKey` is required for them.
    static func usingBackend(_ url: String) -> Bool {
        !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
