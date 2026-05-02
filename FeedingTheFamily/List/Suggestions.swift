import Foundation

/// One observation of the user adding a custom item to a list. Stamped with a
/// date so we can compute "seen across N weeks".
struct DatedCustomItem: Codable, Hashable {
    var name: String
    var qty: String
    var aisle: Aisle
    var addedAt: Date
}

/// A suggestion the app surfaces. Two kinds:
/// - `.promote` — add this item as a new weekly staple
/// - `.qtyBump` — change an existing staple's qty (the user keeps adding more)
struct LearnedSuggestion: Identifiable, Hashable {
    enum Kind: Hashable { case promote, qtyBump(currentQty: String) }

    let id: String                   // name|aisle, used as the dismiss key
    let name: String
    let qty: String
    let aisle: Aisle
    let weeksSeen: Int
    let reason: String
    let kind: Kind
}

enum Suggestions {
    /// Demo suggestions surfaced from day one so the feature is visible without
    /// real history. Hidden once the user adds them as staples or dismisses them.
    static let seeded: [LearnedSuggestion] = [
        LearnedSuggestion(id: "avocados|produce",    name: "avocados",      qty: "4",        aisle: .produce, weeksSeen: 4, reason: "added 4 weeks in a row",  kind: .promote),
        LearnedSuggestion(id: "cold brew|pantry",    name: "cold brew",     qty: "1 carton", aisle: .pantry,  weeksSeen: 3, reason: "added every shop day",     kind: .promote),
        LearnedSuggestion(id: "string cheese|dairy", name: "string cheese", qty: "1 pack",   aisle: .dairy,   weeksSeen: 3, reason: "added 3 weeks in a row",  kind: .promote),
    ]

    /// Compute live suggestions from the user's actual custom-item history.
    /// Two kinds get emitted:
    /// - `.promote` for items seen ≥3 weeks that aren't yet a staple
    /// - `.qtyBump` for items seen ≥3 weeks that ARE a staple but the user keeps
    ///   adding more, suggesting the staple qty should go up.
    static func learned(from history: [DatedCustomItem], staples: [GroceryItem]) -> [LearnedSuggestion] {
        guard !history.isEmpty else { return [] }
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2

        struct Bucket {
            var weeks: Set<Date> = []
            var lastQty: String = ""
            var aisle: Aisle = .produce
            var name: String = ""
        }
        var buckets: [String: Bucket] = [:]
        for row in history {
            let key = "\(row.name)|\(row.aisle.rawValue)"
            let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: row.addedAt)) ?? row.addedAt
            var b = buckets[key] ?? Bucket()
            b.weeks.insert(weekStart)
            b.lastQty = row.qty
            b.aisle = row.aisle
            b.name = row.name
            buckets[key] = b
        }

        let stapleByKey: [String: GroceryItem] = Dictionary(
            uniqueKeysWithValues: staples.map { ("\($0.name)|\($0.aisle.rawValue)", $0) }
        )

        return buckets
            .filter { $0.value.weeks.count >= 3 }
            .compactMap { (key, bucket) -> LearnedSuggestion? in
                if let staple = stapleByKey[key] {
                    // Already a staple — only suggest a qty bump if the user's recent
                    // qty differs from the staple qty (and is non-empty).
                    let currentStapleQty = staple.qty.joined(separator: " + ")
                    let userQty = bucket.lastQty.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !userQty.isEmpty, userQty != currentStapleQty else { return nil }
                    return LearnedSuggestion(
                        id: key,
                        name: bucket.name,
                        qty: userQty,
                        aisle: bucket.aisle,
                        weeksSeen: bucket.weeks.count,
                        reason: "you've been adding \(userQty) for \(bucket.weeks.count) weeks running",
                        kind: .qtyBump(currentQty: currentStapleQty)
                    )
                } else {
                    // Not yet a staple — promote it.
                    return LearnedSuggestion(
                        id: key,
                        name: bucket.name,
                        qty: bucket.lastQty,
                        aisle: bucket.aisle,
                        weeksSeen: bucket.weeks.count,
                        reason: "added \(bucket.weeks.count) weeks running",
                        kind: .promote
                    )
                }
            }
            .sorted { $0.weeksSeen > $1.weeksSeen }
    }
}
