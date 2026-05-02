import SwiftUI

struct FourWeekTrendCard: View {
    let weeks: [[DayNutrition?]]
    let goal: NutritionGoal

    private var summaries: [WeekSummary] {
        weeks.map { NutritionData.summary(of: $0) }
    }
    private var current: WeekSummary { summaries.last ?? WeekSummary(kcal: 0, protein: 0, carbs: 0, fat: 0, days: 0, avgKcal: 0, avgProtein: 0) }
    private var previous: WeekSummary { summaries.dropLast().last ?? current }
    private var maxAvg: Double {
        Double(summaries.map(\.avgKcal).max() ?? goal.kcal) * 1.05
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("4-week trend")
                        .font(AppFont.text(11, weight: .medium))
                        .foregroundStyle(T.ink3)
                    Text("avg kcal / logged day")
                        .font(AppFont.mono(10.5))
                        .foregroundStyle(T.ink3)
                }
                Spacer()
                deltaBadges
            }
            .padding(.bottom, 14)

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(0..<summaries.count, id: \.self) { i in
                    weekBar(idx: i)
                }
            }
            .frame(height: 80)

            Text(insight)
                .font(AppFont.text(11.5))
                .foregroundStyle(T.ink2)
                .padding(.top, 12)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Radius.card)
                .fill(T.card)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.card)
                        .strokeBorder(T.ruleSoft, lineWidth: 1)
                )
        )
    }

    private func weekBar(idx: Int) -> some View {
        let summary = summaries[idx]
        let isCurrent = idx == summaries.count - 1
        let pctOfGoal = Double(summary.avgKcal) / Double(goal.kcal)
        let pctLabel = summary.days > 0 ? "\(Int(pctOfGoal * 100))%" : "—"
        let h = summary.days > 0
            ? CGFloat(Double(summary.avgKcal) / maxAvg) * 64
            : CGFloat(6)
        return VStack(spacing: 6) {
            Text(pctLabel)
                .font(AppFont.mono(10, weight: .semibold))
                .foregroundStyle(isCurrent ? T.ink : T.ink3)
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 4)
                .fill(isCurrent ? T.accent : (summary.days > 0 ? T.ink : T.ruleSoft))
                .frame(height: h)
            Text(idx == summaries.count - 1 ? "now" : "\(summaries.count - 1 - idx)w ago")
                .font(AppFont.mono(9))
                .foregroundStyle(T.ink3)
        }
        .frame(maxWidth: .infinity)
    }

    private var deltaBadges: some View {
        let kcalDelta = current.avgKcal - previous.avgKcal
        let proteinDelta = current.avgProtein - previous.avgProtein
        return VStack(alignment: .trailing, spacing: 4) {
            deltaBadge(value: kcalDelta, suffix: " kcal")
            deltaBadge(value: proteinDelta, suffix: "g protein")
        }
    }

    private func deltaBadge(value: Int, suffix: String) -> some View {
        let arrow = value > 0 ? "↑" : (value < 0 ? "↓" : "→")
        let color: Color = value > 0 ? T.accent2 : (value < 0 ? T.warn : T.ink3)
        let formatted = value == 0 ? "—" : "\(value > 0 ? "+" : "")\(value)\(suffix)"
        return HStack(spacing: 3) {
            Text(arrow)
                .font(AppFont.mono(11, weight: .bold))
            Text(formatted)
                .font(AppFont.mono(10))
        }
        .foregroundStyle(color)
    }

    private var insight: String {
        guard current.days > 0 else { return "Start logging this week to see a trend." }
        let kcalDelta = current.avgKcal - previous.avgKcal
        let proteinOnTarget = current.avgProtein >= Int(Double(goal.protein) * 0.95)
        if kcalDelta > 100 && proteinOnTarget {
            return "↑ Eating more this week than last. Protein is on target."
        } else if kcalDelta < -100 {
            return "↓ Eating lighter this week. Watch protein."
        } else if proteinOnTarget {
            return "Steady week. Protein is on target."
        } else {
            return "Steady week. Protein a bit under goal."
        }
    }
}
