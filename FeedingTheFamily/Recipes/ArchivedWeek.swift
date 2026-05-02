import Foundation

/// Snapshot of a past week's plan. Captured automatically when the app detects
/// a Monday rollover and the previously-saved week is older than today's Monday.
struct ArchivedWeek: Identifiable, Codable, Hashable {
    /// Stable id — ISO date of the week's Monday ("2026-04-27").
    let id: String
    let mondayDate: Date
    let week: [DayPlan]

    var label: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        let monday = mondayDate
        let sunday = Calendar.current.date(byAdding: .day, value: 6, to: monday)!
        return "\(f.string(from: monday)) – \(f.string(from: sunday))"
    }

    var headline: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "Week of \(f.string(from: mondayDate))"
    }
}

extension SeedData {
    /// Demo archived weeks so the History view has content from day one.
    /// Real archives accumulate as weeks roll over.
    static var demoArchivedWeeks: [ArchivedWeek] {
        let cal = Calendar.current
        guard let twoWeeksAgo = cal.date(byAdding: .day, value: -14, to: Today.monday),
              let oneWeekAgo  = cal.date(byAdding: .day, value: -7,  to: Today.monday)
        else { return [] }

        let f = DateFormatter()
        f.dateFormat = "MMM d"

        func makeWeek(starting monday: Date, picks: [String]) -> [DayPlan] {
            zip(Today.labels, 0..<7).map { label, idx in
                let date = cal.date(byAdding: .day, value: idx, to: monday)!
                return DayPlan(
                    day: label,
                    date: f.string(from: date),
                    mealId: picks[idx],
                    locked: false,
                    slot: idx >= 5 ? .weekend : (idx == 1 || idx == 3 ? .quick : .cook)
                )
            }
        }

        let isoFmt = ISO8601DateFormatter()
        isoFmt.formatOptions = [.withFullDate]

        return [
            ArchivedWeek(
                id: isoFmt.string(from: oneWeekAgo),
                mondayDate: oneWeekAgo,
                week: makeWeek(starting: oneWeekAgo, picks: [
                    "burgers", "ramen-bowl", "leftovers", "daddy-dinner",
                    "italian-beef", "mama-pizza", "enchiladas",
                ])
            ),
            ArchivedWeek(
                id: isoFmt.string(from: twoWeeksAgo),
                mondayDate: twoWeeksAgo,
                week: makeWeek(starting: twoWeeksAgo, picks: [
                    "korean-beef", "turkey-ginger", "leftovers", "hot-dogs",
                    "lemon-caper", "pork-loin", "beef-skillet",
                ])
            ),
        ]
    }
}
