import SwiftUI

/// Compact "this week so far" card. Surfaces only when there are past days
/// with ratings — otherwise stays hidden so the Plan tab doesn't get cluttered.
struct WeeklyRecapCard: View {
    let week: [DayPlan]
    let ratings: [String: [Int]]
    let ratingFeedback: [String: [String]]
    let unratedDays: Set<String>
    let todayIdx: Int

    private struct DayRecap {
        let day: DayPlan
        let stars: Int
        let note: String?
    }

    /// Past days (idx < todayIdx) where unratedDays no longer contains the day —
    /// i.e. the user has rated them. Plus we pull the most recent rating + note
    /// from the parallel arrays so the card reflects the latest feedback.
    private var rated: [DayRecap] {
        let past = Array(week.prefix(todayIdx))
        return past.compactMap { day in
            guard !unratedDays.contains(day.day),
                  let stars = ratings[day.mealId]?.last
            else { return nil }
            let notes = ratingFeedback[day.mealId] ?? []
            let lastNote = (notes.last?.isEmpty == false) ? notes.last : nil
            return DayRecap(day: day, stars: stars, note: lastNote)
        }
    }

    private var totalPast: Int { todayIdx }
    private var avgStars: Double {
        guard !rated.isEmpty else { return 0 }
        let sum = rated.reduce(0) { $0 + $1.stars }
        return Double(sum) / Double(rated.count)
    }
    private var bestDay: DayRecap? {
        rated.max(by: { $0.stars < $1.stars })
    }
    private var worstNote: (DayRecap)? {
        rated
            .filter { $0.note != nil && $0.stars <= 3 }
            .min(by: { $0.stars < $1.stars })
    }

    var body: some View {
        if !rated.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(T.ink2)
                        Text("THIS WEEK SO FAR")
                            .font(AppFont.text(10.5, weight: .bold))
                            .kerning(1.2)
                            .foregroundStyle(T.ink2)
                    }
                    Spacer()
                    Text("\(rated.count)/\(totalPast) rated · \(String(format: "%.1f", avgStars))★")
                        .font(AppFont.mono(11, weight: .semibold))
                        .foregroundStyle(T.ink)
                }

                // Per-rated-day mini row
                HStack(spacing: 8) {
                    ForEach(Array(rated.enumerated()), id: \.offset) { _, r in
                        VStack(spacing: 2) {
                            Text(r.day.day)
                                .font(AppFont.text(10.5, weight: .bold))
                                .foregroundStyle(T.ink2)
                            Text(String(repeating: "★", count: r.stars))
                                .font(AppFont.mono(9, weight: .bold))
                                .foregroundStyle(starColor(r.stars))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(T.paperDeep)
                        )
                    }
                }

                // Surface a low-rating note as the "lesson" line
                if let bad = worstNote, let note = bad.note {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.bubble.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(T.warn)
                        Text("\(bad.day.day): \(note)")
                            .font(AppFont.text(11.5))
                            .foregroundStyle(T.ink2)
                            .lineLimit(2)
                    }
                } else if let best = bestDay, best.stars >= 4 {
                    let title = Planner.meal(byId: best.day.mealId).title
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(T.accent2)
                        Text("Hit: \(best.day.day)'s \(title)")
                            .font(AppFont.text(11.5))
                            .foregroundStyle(T.ink2)
                            .lineLimit(1)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(T.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(T.ruleSoft, lineWidth: 1)
                    )
            )
        }
    }

    private func starColor(_ stars: Int) -> Color {
        if stars >= 4 { return T.accent2 }
        if stars <= 2 { return T.warn }
        return T.ink3
    }
}
