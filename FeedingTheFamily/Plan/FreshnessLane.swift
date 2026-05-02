import SwiftUI

struct FreshnessLane: View {
    let week: [DayPlan]
    let rules: Rules

    private var lastFresh: Int {
        Planner.freshDayIndices(in: week).max() ?? -1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Fresh-meat window")
                    .font(AppFont.text(11, weight: .medium))
                    .foregroundStyle(T.ink3)
                Spacer()
                Text(lastFresh >= 0 ? "last · day \(lastFresh + 1)" : "none")
                    .font(AppFont.mono(10))
                    .foregroundStyle(T.ink)
            }
            HStack(spacing: 3) {
                ForEach(Array(week.enumerated()), id: \.element.id) { idx, day in
                    cell(idx: idx, day: day)
                }
            }
        }
    }

    @ViewBuilder
    private func cell(idx: Int, day: DayPlan) -> some View {
        let m = Planner.meal(byId: day.mealId)
        let p = Planner.protein(for: m)
        let isFreshMeat = p.perish == .fresh
        let okFresh = Planner.isFreshOK(dayIdx: idx, rules: rules)
        let violating = isFreshMeat && !okFresh
        let bg: Color = violating ? T.warn
            : isFreshMeat ? T.ink
            : okFresh ? T.paperDeep
            : T.ruleSoft
        let fg: Color = (isFreshMeat || violating) ? T.accent : T.ink3
        let isShopDay = day.day == rules.shopDay
        let isTopUpDay = day.day == rules.topUpDay

        RoundedRectangle(cornerRadius: 4)
            .fill(bg)
            .frame(height: 26)
            .overlay {
                Text(String(day.day.prefix(1)).uppercased())
                    .font(AppFont.mono(9, weight: .semibold))
                    .kerning(0.5)
                    .foregroundStyle(fg)
            }
            .overlay(alignment: .topTrailing) {
                if isShopDay || isTopUpDay {
                    Image(systemName: "bag.fill")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(fg.opacity(0.85))
                        .padding(2)
                }
            }
            .frame(maxWidth: .infinity)
    }
}
