import Foundation

enum Trend { case up, down, flat, new }

enum Learning {
    /// Average of the rating history for a meal. 0 if no ratings.
    static func confidence(for mealId: String, ratings: [String: [Int]]) -> Double {
        guard let history = ratings[mealId], !history.isEmpty else { return 0 }
        let sum = history.reduce(0, +)
        return Double(sum) / Double(history.count)
    }

    /// Direction the family's score is moving. Compares the last 2 ratings to earlier ones.
    static func trend(for mealId: String, ratings: [String: [Int]]) -> Trend {
        guard let history = ratings[mealId] else { return .new }
        if history.count < 2 { return .new }
        let recent = Array(history.suffix(2))
        let earlier = history.dropLast(2)
        let recentAvg = Double(recent.reduce(0, +)) / Double(recent.count)
        let earlierAvg = earlier.isEmpty
            ? recentAvg
            : Double(earlier.reduce(0, +)) / Double(earlier.count)
        if recentAvg > earlierAvg + 0.3 { return .up }
        if recentAvg < earlierAvg - 0.3 { return .down }
        return .flat
    }
}
