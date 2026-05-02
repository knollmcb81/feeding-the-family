import Foundation
import UIKit

/// Sends a photo to Claude via the Anthropic Messages API and parses the
/// response into a SnapFixture. Used in place of the cycling mock when the
/// user has set their API key in Settings.
/// Generates a real Meal from a saved inspiration via Claude.
/// Falls back to the deterministic synthesis when no API key is set.
enum AnthropicRecipe {
    enum RecipeError: LocalizedError {
        case missingKey
        case http(Int, String)
        case network(Error)
        case decode(String)
        var errorDescription: String? {
            switch self {
            case .missingKey:           return "No Anthropic API key set."
            case .http(let c, let m):   return "API error (\(c)): \(m)"
            case .network(let e):       return "Network error: \(e.localizedDescription)"
            case .decode(let m):        return "Couldn't parse Claude's response: \(m)"
            }
        }
    }

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let model = "claude-sonnet-4-6"

    static func generate(from inspiration: SnapEntry, rules: Rules, apiKey: String) async throws -> Meal {
        let key = apiKey
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        guard !key.isEmpty else { throw RecipeError.missingKey }

        let itemsList = inspiration.items.map { "- \($0.name) (\($0.qty), \($0.kcal) kcal)" }.joined(separator: "\n")
        let avoidList = rules.avoidIngredients.joined(separator: ", ")
        let prompt = """
        I want to recreate a meal for my family.

        Saved meal: "\(inspiration.title)"
        Detected items:
        \(itemsList.isEmpty ? "(no item detail)" : itemsList)

        Family: \(rules.householdAdults) adult\(rules.householdAdults == 1 ? "" : "s") and \
        \(rules.householdKids) kid\(rules.householdKids == 1 ? "" : "s"). \
        Avoid: \(avoidList.isEmpty ? "(none)" : avoidList).
        Weeknight cap: \(rules.weeknightMax) min.

        Write a real recipe that produces something close to this meal, scaled to \
        feed the household. Keep it to about \(rules.weeknightMax) minutes total.

        Return ONLY a single JSON object — no prose, no markdown fences. Shape:
        {
          "title": "short recipe title",
          "time": int_minutes,
          "kid": true|false,
          "tags": ["string", ...],
          "protein": "fresh_beef" | "fresh_chicken" | "fresh_chick_b" | "fresh_chuck" | "fresh_steak" | "fresh_pork" | "fresh_turkey" | "fresh_bacon" | "pantry_beans" | "pantry_eggs",
          "ingredients": [
            { "name": "...", "qty": "1 lb", "aisle": "produce|meat|dairy|bakery|pantry|frozen" }
          ],
          "steps": ["step 1", "step 2", ...]
        }

        Rules:
        - 4-8 ingredients. Real qtys you'd put on a grocery list (e.g. "1 lb", "2 cups", "1 jar").
        - 4-7 steps, each one terse and actionable.
        - Don't include any ingredient from the avoid list.
        - Pick the closest matching protein id; default to "pantry_eggs" if there's no animal protein.
        - kid = true only if it's clearly kid-friendly.
        """

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1500,
            "messages": [["role": "user", "content": prompt]]
        ]
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.timeoutInterval = 30
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch {
            throw RecipeError.network(error)
        }

        guard let http = resp as? HTTPURLResponse else { throw RecipeError.http(0, "no http response") }
        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "<no body>"
            throw RecipeError.http(http.statusCode, msg)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstText = content.first(where: { ($0["type"] as? String) == "text" }),
              let text = firstText["text"] as? String
        else { throw RecipeError.decode("missing content[].text") }

        return try parse(text, mealId: "insp-\(inspiration.id.uuidString.prefix(8))")
    }

    private static func parse(_ text: String, mealId: String) throws -> Meal {
        let trimmed = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let firstBrace = trimmed.firstIndex(of: "{"),
              let lastBrace = trimmed.lastIndex(of: "}")
        else { throw RecipeError.decode("no JSON object: \(trimmed.prefix(200))") }

        let jsonStr = String(trimmed[firstBrace...lastBrace])
        guard let data = jsonStr.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw RecipeError.decode("invalid JSON: \(jsonStr.prefix(200))") }

        let title = (obj["title"] as? String) ?? "Inspired meal"
        let time = (obj["time"] as? Int) ?? Int((obj["time"] as? Double) ?? 35)
        let kid = (obj["kid"] as? Bool) ?? false
        let tags = (obj["tags"] as? [String]) ?? ["inspiration"]
        let proteinId = (obj["protein"] as? String) ?? "pantry_eggs"
        let rawIngs = (obj["ingredients"] as? [[String: Any]]) ?? []
        let steps = (obj["steps"] as? [String]) ?? ["No steps yet."]

        let ings: [Ingredient] = rawIngs.compactMap { row in
            guard let name = row["name"] as? String else { return nil }
            let qty = (row["qty"] as? String) ?? ""
            let aisleStr = (row["aisle"] as? String) ?? "produce"
            let aisle = Aisle(rawValue: aisleStr) ?? .produce
            return Ingredient(name: name.lowercased(), qty: qty, aisle: aisle)
        }

        return Meal(
            id: mealId,
            title: title,
            time: time,
            kid: kid,
            tags: tags + ["inspiration"],
            proteinId: proteinId,
            ings: ings,
            steps: steps
        )
    }
}

enum AnthropicVision {
    /// Lightweight key-validity check. Sends 1 token and inspects the status code.
    /// 200 = good, 401 = bad key, anything else = a useful error to show the user.
    static func testKey(_ apiKey: String) async -> Result<Void, VisionError> {
        let key = apiKey
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        guard !key.isEmpty else { return .failure(.missingKey) }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1,
            "messages": [["role": "user", "content": "ok"]],
        ]
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.timeoutInterval = 15
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { return .failure(.http(0, "no http response")) }
            if (200..<300).contains(http.statusCode) { return .success(()) }
            let msg = String(data: data, encoding: .utf8) ?? "<no body>"
            return .failure(.http(http.statusCode, msg))
        } catch {
            return .failure(.network(error))
        }
    }

    enum VisionError: LocalizedError {
        case missingKey
        case imageEncodingFailed
        case network(Error)
        case http(Int, String)
        case decode(String)

        var errorDescription: String? {
            switch self {
            case .missingKey:           return "No Anthropic API key set. Add one in Settings."
            case .imageEncodingFailed:  return "Couldn't encode the photo."
            case .network(let e):       return "Network error: \(e.localizedDescription)"
            case .http(let code, let msg): return "API error (\(code)): \(msg)"
            case .decode(let msg):      return "Couldn't parse Claude's response: \(msg)"
            }
        }
    }

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let model = "claude-sonnet-4-6"

    static func classify(imageData: Data, apiKey: String) async throws -> SnapFixture {
        // Aggressively strip whitespace, newlines, and any stray quote chars that
        // can sneak in from clipboards. A single \n breaks the HTTP header.
        let key = apiKey
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        guard !key.isEmpty else { throw VisionError.missingKey }

        // Resize so we don't upload 12MP photos. Vision models tolerate ~1024px well.
        let resized = imageData.resizedJPEG(maxDimension: 1024) ?? imageData
        let base64 = resized.base64EncodedString()

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
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

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.timeoutInterval = 30
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch {
            throw VisionError.network(error)
        }

        guard let http = resp as? HTTPURLResponse else {
            throw VisionError.http(0, "no http response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "<no body>"
            throw VisionError.http(http.statusCode, msg)
        }

        // Anthropic shape: { content: [{ type: "text", text: "..." }] }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstText = content.first(where: { ($0["type"] as? String) == "text" }),
              let text = firstText["text"] as? String
        else {
            throw VisionError.decode("missing content[].text")
        }

        return try parseFixture(from: text)
    }

    // ── Prompt + parsing ───────────────────────────

    private static let prompt = """
    You're analyzing a photo of food. Identify each visible food item and estimate macros.

    Return ONLY a single JSON object — no prose, no markdown fences. Shape:
    {
      "title": "short name like 'Dinner plate' or 'Bag of popcorn'",
      "confidence": 0-100,
      "items": [
        { "name": "...", "qty": "approximate qty like '~1 cup' or '~6 oz'",
          "kcal": int, "protein": number_grams, "carbs": number_grams, "fat": number_grams }
      ]
    }

    Rules:
    - If it's a single item (e.g. a bag of popcorn), still return one item with realistic qty/macros.
    - If you can't identify any food, return { "title": "Unknown", "confidence": 10, "items": [] }.
    - Macros must be realistic. Snacks/single packages should match nutrition label totals.
    - Title should be brief, 1-3 words.
    """

    private static func parseFixture(from text: String) throws -> SnapFixture {
        // Trim possible code fences, then locate the first { ... } block.
        let trimmed = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let firstBrace = trimmed.firstIndex(of: "{"),
              let lastBrace = trimmed.lastIndex(of: "}")
        else {
            throw VisionError.decode("no JSON object in response: \(trimmed.prefix(200))")
        }
        let jsonStr = String(trimmed[firstBrace...lastBrace])
        guard let jsonData = jsonStr.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        else {
            throw VisionError.decode("invalid JSON: \(jsonStr.prefix(200))")
        }

        let title = (obj["title"] as? String) ?? "Snap"
        let confidence = (obj["confidence"] as? Int)
            ?? Int((obj["confidence"] as? Double) ?? 50)
        let rawItems = (obj["items"] as? [[String: Any]]) ?? []

        let items: [SnapItem] = rawItems.compactMap { row in
            guard let name = row["name"] as? String else { return nil }
            return SnapItem(
                name: name,
                qty: (row["qty"] as? String) ?? "",
                kcal: (row["kcal"] as? Int) ?? Int((row["kcal"] as? Double) ?? 0),
                protein: doubleVal(row["protein"]),
                carbs:   doubleVal(row["carbs"]),
                fat:     doubleVal(row["fat"])
            )
        }

        return SnapFixture(title: title, confidence: confidence, items: items, source: .ai)
    }

    private static func doubleVal(_ v: Any?) -> Double {
        if let d = v as? Double { return d }
        if let i = v as? Int { return Double(i) }
        if let s = v as? String, let d = Double(s) { return d }
        return 0
    }
}

extension Data {
    /// Decode → resize the longer side down to `maxDimension` → re-encode JPEG.
    /// Cheap on-device shrink so we don't upload a 4K photo.
    func resizedJPEG(maxDimension: CGFloat, quality: CGFloat = 0.8) -> Data? {
        guard let image = UIImage(data: self) else { return nil }
        let size = image.size
        let long = Swift.max(size.width, size.height)
        guard long > maxDimension else {
            return image.jpegData(compressionQuality: quality)
        }
        let scale = maxDimension / long
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
