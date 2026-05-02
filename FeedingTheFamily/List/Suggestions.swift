import Foundation

/// One observation of the user adding a custom item to a list. Stamped with a
/// date so we can compute "seen across N weeks".
struct DatedCustomItem: Codable, Hashable {
    var name: String
    var qty: String
    var aisle: Aisle
    var addedAt: Date
}

/// A suggestion the app surfaces — promote this to a staple.
struct LearnedSuggestion: Identifiable, Hashable {
    let id: String                   // name|aisle, used as the dismiss key
    let name: String
    let qty: String
    let aisle: Aisle
    let weeksSeen: Int
    let reason: String
}

enum Suggestions {
    /// Demo suggestions surfaced from day one so the feature is visible without
    /// real history. Hidden once the user adds them as staples or dismisses them.
    static let seeded: [LearnedSuggestion] = [
        LearnedSuggestion(id: "avocados|produce",       name: "avocados",      qty: "4",        aisle: .produce, weeksSeen: 4, reason: "added 4 weeks in a row"),
        LearnedSuggestion(id: "cold brew|pantry",       name: "cold brew",     qty: "1 carton", aisle: .pantry,  weeksSeen: 3, reason: "added every shop day"),
        LearnedSuggestion(id: "string cheese|dairy",    name: "string cheese", qty: "1 pack",   aisle: .dairy,   weeksSeen: 3, reason: "added 3 weeks in a row"),
    ]

    /// Compute live suggestions from the user's actual custom-item history.
    /// Counts unique ISO weeks per (name + aisle); surfaces items seen ≥3 weeks
    /// and not already in staples or seeded.
    static func learned(from history: [DatedCustomItem], staples: [GroceryItem]) -> [LearnedSuggestion] {
        guard !history.isEmpty else { return [] }
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2

        // Group history rows by (name|aisle), tracking weeks seen + most recent qty.
        struct Bucket {
            var weeks: Set<Date> = []  // week-start dates
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

        let stapleNames = Set(staples.map { "\($0.name)|\($0.aisle.rawValue)" })

        return buckets
            .filter { $0.value.weeks.count >= 3 && !stapleNames.contains($0.key) }
            .map { (key, bucket) in
                LearnedSuggestion(
                    id: key,
                    name: bucket.name,
                    qty: bucket.lastQty,
                    aisle: bucket.aisle,
                    weeksSeen: bucket.weeks.count,
                    reason: "added \(bucket.weeks.count) weeks running"
                )
            }
            .sorted { $0.weeksSeen > $1.weeksSeen }
    }
}
