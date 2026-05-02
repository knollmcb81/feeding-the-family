import Foundation
import UIKit

/// Fetch a recipe page, hand the cleaned HTML to Claude, parse the JSON response
/// into a Meal. Used by the "Import from URL" action on the Recipes tab.
enum RecipeImporter {
    enum ImportError: LocalizedError {
        case missingKey
        case invalidURL
        case fetchFailed(String)
        case http(Int, String)
        case network(Error)
        case noContent
        case decode(String)
        var errorDescription: String? {
            switch self {
            case .missingKey:           return "An Anthropic API key is required to import recipes. Add one in Settings → AI Vision."
            case .invalidURL:           return "That doesn't look like a valid web address."
            case .fetchFailed(let m):   return "Couldn't load that page: \(m)"
            case .http(let c, let m):   return "API error (\(c)): \(m)"
            case .network(let e):       return "Network error: \(e.localizedDescription)"
            case .noContent:            return "The page didn't return any text content."
            case .decode(let m):        return "Couldn't parse Claude's response: \(m)"
            }
        }
    }

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let model = "claude-sonnet-4-6"
    private static let maxHTMLChars = 30_000

    /// Same shape as `importFrom(urlString:)` but takes raw text — useful for
    /// paywalled recipes (paste the body), email recipes friends sent you, or
    /// hand-typed family recipes.
    static func importFromText(
        text: String,
        apiKey: String,
        backendBaseURL: String = "",
        backendAuthToken: String = ""
    ) async throws -> Meal {
        let usingBackend = ClaudeRouter.usingBackend(backendBaseURL)
        let trimmedKey = apiKey
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        if !usingBackend && trimmedKey.isEmpty { throw ImportError.missingKey }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { throw ImportError.noContent }

        // Truncate same as URL-fetched HTML — keeps token usage predictable.
        let truncated = String(trimmedText.prefix(maxHTMLChars))

        let prompt = """
        Below is the body of a recipe (from a website, email, message, or hand-typed). \
        Extract a structured recipe.

        Source text:
        ---
        \(truncated)
        ---

        Return ONLY a single JSON object — no prose, no markdown fences. Shape:
        {
          "title": "short recipe title",
          "time": int_minutes_total,
          "kid": true|false,
          "tags": ["string", ...],
          "protein": "fresh_beef" | "fresh_chicken" | "fresh_chick_b" | "fresh_chuck" | "fresh_steak" | "fresh_pork" | "fresh_turkey" | "fresh_bacon" | "pantry_beans" | "pantry_eggs",
          "ingredients": [
            { "name": "...", "qty": "1 lb", "aisle": "produce|meat|dairy|bakery|pantry|frozen" }
          ],
          "steps": ["step 1", "step 2", ...]
        }

        Rules:
        - Use real qtys you'd put on a grocery list.
        - kid = true only if it's clearly kid-friendly.
        - If the text doesn't contain a recognizable recipe, return {"title":"Couldn't find a recipe","time":0,"kid":false,"tags":[],"protein":"pantry_eggs","ingredients":[],"steps":[]}.
        """

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2000,
            "messages": [["role": "user", "content": prompt]]
        ]
        let routed = ClaudeRouter.request(
            anthropicKey: trimmedKey,
            backendBaseURL: backendBaseURL,
            backendAuthToken: backendAuthToken
        )
        var req = URLRequest(url: routed.url)
        req.httpMethod = "POST"
        for (k, v) in routed.headers { req.setValue(v, forHTTPHeaderField: k) }
        req.timeoutInterval = 30
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch {
            throw ImportError.network(error)
        }
        guard let http = resp as? HTTPURLResponse else { throw ImportError.http(0, "no http response") }
        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "<no body>"
            throw ImportError.http(http.statusCode, msg)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstText = content.first(where: { ($0["type"] as? String) == "text" }),
              let textOut = firstText["text"] as? String
        else { throw ImportError.decode("missing content[].text") }

        return try parse(textOut, mealId: "text-\(UUID().uuidString.prefix(8))")
    }

    /// Same shape as `importFrom(urlString:)` but takes a photo. The photo is
    /// resized to ~1024px and sent to Claude with a recipe-extraction prompt.
    /// Works for cookbook pages, magazine recipes, screenshots, handwritten cards.
    static func importFromPhoto(
        imageData: Data,
        apiKey: String,
        backendBaseURL: String = "",
        backendAuthToken: String = ""
    ) async throws -> Meal {
        let usingBackend = ClaudeRouter.usingBackend(backendBaseURL)
        let trimmedKey = apiKey
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        if !usingBackend && trimmedKey.isEmpty { throw ImportError.missingKey }

        let resized = imageData.resizedJPEG(maxDimension: 1024) ?? imageData
        let base64 = resized.base64EncodedString()

        let prompt = """
        Look at this photo of a recipe (cookbook page, magazine, screenshot, \
        handwritten card, etc.) and extract the recipe.

        Return ONLY a single JSON object — no prose, no markdown fences. Shape:
        {
          "title": "short recipe title",
          "time": int_minutes_total,
          "kid": true|false,
          "tags": ["string", ...],
          "protein": "fresh_beef" | "fresh_chicken" | "fresh_chick_b" | "fresh_chuck" | "fresh_steak" | "fresh_pork" | "fresh_turkey" | "fresh_bacon" | "pantry_beans" | "pantry_eggs",
          "ingredients": [
            { "name": "...", "qty": "1 lb", "aisle": "produce|meat|dairy|bakery|pantry|frozen" }
          ],
          "steps": ["step 1", "step 2", ...]
        }

        Rules:
        - Use real qtys you'd put on a grocery list (e.g. "1 lb", "2 cups", "1 jar").
        - kid = true only if it's clearly kid-friendly.
        - If the photo doesn't contain a readable recipe, return {"title":"Couldn't find a recipe","time":0,"kid":false,"tags":[],"protein":"pantry_eggs","ingredients":[],"steps":[]}.
        """

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2000,
            "messages": [[
                "role": "user",
                "content": [
                    [
                        "type": "image",
                        "source": [
                            "type": "base64",
                            "media_type": "image/jpeg",
                            "data": base64
                        ]
                    ],
                    [
                        "type": "text",
                        "text": prompt
                    ]
                ]
            ]]
        ]
        let routed = ClaudeRouter.request(
            anthropicKey: trimmedKey,
            backendBaseURL: backendBaseURL,
            backendAuthToken: backendAuthToken
        )
        var req = URLRequest(url: routed.url)
        req.httpMethod = "POST"
        for (k, v) in routed.headers { req.setValue(v, forHTTPHeaderField: k) }
        req.timeoutInterval = 30
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch {
            throw ImportError.network(error)
        }
        guard let http = resp as? HTTPURLResponse else { throw ImportError.http(0, "no http response") }
        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "<no body>"
            throw ImportError.http(http.statusCode, msg)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstText = content.first(where: { ($0["type"] as? String) == "text" }),
              let text = firstText["text"] as? String
        else { throw ImportError.decode("missing content[].text") }

        return try parse(text, mealId: "photo-\(UUID().uuidString.prefix(8))")
    }

    static func importFrom(
        urlString: String,
        apiKey: String,
        backendBaseURL: String = "",
        backendAuthToken: String = ""
    ) async throws -> Meal {
        let usingBackend = ClaudeRouter.usingBackend(backendBaseURL)
        let trimmedKey = apiKey
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        if !usingBackend && trimmedKey.isEmpty { throw ImportError.missingKey }

        // Allow user to paste with or without scheme; auto-prepend https:// if needed.
        var raw = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !raw.lowercased().hasPrefix("http://") && !raw.lowercased().hasPrefix("https://") {
            raw = "https://" + raw
        }
        guard let url = URL(string: raw), url.host != nil else { throw ImportError.invalidURL }

        // 1. Fetch the page.
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0 (compatible; FeedingTheFamily/1.0)", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 20
        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch {
            throw ImportError.network(error)
        }
        if let http = resp as? HTTPURLResponse, !(200..<400).contains(http.statusCode) {
            throw ImportError.fetchFailed("HTTP \(http.statusCode)")
        }
        guard let html = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1)
        else { throw ImportError.noContent }

        // 2. Strip scripts/styles + collapse whitespace; truncate so we don't blow tokens.
        let cleaned = stripHTML(html).prefix(maxHTMLChars)

        // 3. Ask Claude to extract a structured recipe.
        let prompt = """
        I'm importing a recipe from this URL: \(url.absoluteString)

        Source content (cleaned HTML, may be truncated):
        ---
        \(cleaned)
        ---

        Extract the recipe. Return ONLY a single JSON object — no prose, no markdown fences. Shape:
        {
          "title": "short recipe title",
          "time": int_minutes_total,
          "kid": true|false,
          "tags": ["string", ...],
          "protein": "fresh_beef" | "fresh_chicken" | "fresh_chick_b" | "fresh_chuck" | "fresh_steak" | "fresh_pork" | "fresh_turkey" | "fresh_bacon" | "pantry_beans" | "pantry_eggs",
          "ingredients": [
            { "name": "...", "qty": "1 lb", "aisle": "produce|meat|dairy|bakery|pantry|frozen" }
          ],
          "steps": ["step 1", "step 2", ...]
        }

        Rules:
        - Use real qtys you'd put on a grocery list.
        - kid = true only if it's clearly kid-friendly.
        - If the page doesn't contain a recipe, return { "title": "Couldn't find a recipe", "time": 0, "kid": false, "tags": [], "protein": "pantry_eggs", "ingredients": [], "steps": [] }.
        """

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2000,
            "messages": [["role": "user", "content": prompt]]
        ]
        let routed = ClaudeRouter.request(
            anthropicKey: trimmedKey,
            backendBaseURL: backendBaseURL,
            backendAuthToken: backendAuthToken
        )
        var apiReq = URLRequest(url: routed.url)
        apiReq.httpMethod = "POST"
        for (k, v) in routed.headers { apiReq.setValue(v, forHTTPHeaderField: k) }
        apiReq.timeoutInterval = 30
        apiReq.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (apiData, apiResp): (Data, URLResponse)
        do {
            (apiData, apiResp) = try await URLSession.shared.data(for: apiReq)
        } catch {
            throw ImportError.network(error)
        }
        guard let http = apiResp as? HTTPURLResponse else { throw ImportError.http(0, "no http response") }
        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: apiData, encoding: .utf8) ?? "<no body>"
            throw ImportError.http(http.statusCode, msg)
        }

        guard let json = try? JSONSerialization.jsonObject(with: apiData) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstText = content.first(where: { ($0["type"] as? String) == "text" }),
              let text = firstText["text"] as? String
        else { throw ImportError.decode("missing content[].text") }

        return try parse(text, mealId: "url-\(UUID().uuidString.prefix(8))")
    }

    // ── Helpers ────────────────────────────

    private static func stripHTML(_ html: String) -> String {
        var s = html
        // Drop <script>...</script> and <style>...</style> blocks.
        for tag in ["script", "style", "noscript"] {
            s = s.replacingOccurrences(
                of: "<\(tag)\\b[^>]*>[\\s\\S]*?</\(tag)>",
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        // Strip remaining tags.
        s = s.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        // Collapse whitespace.
        s = s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parse(_ text: String, mealId: String) throws -> Meal {
        let trimmed = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let firstBrace = trimmed.firstIndex(of: "{"),
              let lastBrace = trimmed.lastIndex(of: "}")
        else { throw ImportError.decode("no JSON object: \(trimmed.prefix(200))") }

        let jsonStr = String(trimmed[firstBrace...lastBrace])
        guard let data = jsonStr.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw ImportError.decode("invalid JSON: \(jsonStr.prefix(200))") }

        let title = (obj["title"] as? String) ?? "Imported recipe"
        if title.lowercased().contains("couldn't find") {
            throw ImportError.decode("Page didn't contain a recognizable recipe.")
        }
        let time = (obj["time"] as? Int) ?? Int((obj["time"] as? Double) ?? 30)
        let kid = (obj["kid"] as? Bool) ?? false
        let tags = (obj["tags"] as? [String]) ?? ["imported"]
        let proteinId = (obj["protein"] as? String) ?? "pantry_eggs"
        let rawIngs = (obj["ingredients"] as? [[String: Any]]) ?? []
        let steps = (obj["steps"] as? [String]) ?? []

        let ings: [Ingredient] = rawIngs.compactMap { row in
            guard let name = row["name"] as? String else { return nil }
            let qty = (row["qty"] as? String) ?? ""
            let aisleStr = (row["aisle"] as? String) ?? "produce"
            let aisle = Aisle(rawValue: aisleStr) ?? .produce
            return Ingredient(name: name.lowercased(), qty: qty, aisle: aisle)
        }
        guard !ings.isEmpty || !steps.isEmpty else {
            throw ImportError.decode("No ingredients or steps extracted.")
        }

        return Meal(
            id: mealId,
            title: title,
            time: time,
            kid: kid,
            tags: tags + ["imported"],
            proteinId: proteinId,
            ings: ings,
            steps: steps
        )
    }
}
