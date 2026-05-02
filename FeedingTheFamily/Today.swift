import Foundation

/// Resolves "today" relative to a Mon–Sun week. Centralizes all date/index math
/// so the Plan / List / Snap headers stay in sync.
enum Today {
    static let labels = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]

    /// Today's date.
    static var date: Date { Date() }

    /// Monday of the current week (Mon-based).
    static var monday: Date {
        var cal = Calendar.current
        cal.firstWeekday = 2  // Monday
        let weekday = cal.component(.weekday, from: date)  // 1=Sun..7=Sat
        let offset = ((weekday - 2) + 7) % 7               // days since Monday
        return cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: date))!
    }

    /// Index 0...6 within this week (0 = Mon).
    static var todayIdx: Int {
        let cal = Calendar.current
        let mondayDay = cal.startOfDay(for: monday)
        let todayDay = cal.startOfDay(for: date)
        return cal.dateComponents([.day], from: mondayDay, to: todayDay).day ?? 0
    }

    /// Date for a given day index (0=Mon..6=Sun).
    static func date(for idx: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: idx, to: monday)!
    }

    /// "May 1"-style label for the given day index.
    static func dateLabel(for idx: Int) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date(for: idx))
    }

    /// Monday of the week N weeks ahead of this one (0 = current).
    static func monday(weeksAhead: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: 7 * weeksAhead, to: monday)!
    }

    /// "May 4"-style label for a day in a future week.
    static func dateLabel(weeksAhead: Int, dayIdx: Int) -> String {
        let base = monday(weeksAhead: weeksAhead)
        let date = Calendar.current.date(byAdding: .day, value: dayIdx, to: base)!
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    /// "Fri · May 1"-style label for today.
    static var todayHeaderLabel: String {
        let day = labels[todayIdx]
        return "\(day) · \(dateLabel(for: todayIdx))"
    }

    /// "Week of May 1" — used in the Plan header.
    static var weekHeaderLabel: String {
        "Week of \(dateLabel(for: 0))"
    }

    /// Returns the day index (0..6) of the next occurrence of `dayLabel` ("Sun", etc.)
    /// from today onward. Used to find the upcoming shop day.
    static func nextOccurrence(of dayLabel: String) -> Int {
        guard let target = labels.firstIndex(of: dayLabel) else { return 6 }
        var idx = todayIdx
        while idx != target {
            idx = (idx + 1) % 7
            if idx == todayIdx { break }  // safety
        }
        return target
    }
}

extension SeedData {
    /// Same meals as `week`, but with day labels and dates derived from `Today`.
    static var dynamicWeek: [DayPlan] {
        zip(week, 0..<7).map { template, idx in
            DayPlan(
                day: Today.labels[idx],
                date: Today.dateLabel(for: idx),
                mealId: template.mealId,
                locked: template.locked,
                slot: template.slot
            )
        }
    }
}
