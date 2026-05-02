import SwiftUI

struct ThisWeekCard: View {
    let week: [DayNutrition?]
    let goal: NutritionGoal
    let todayIdx: Int

    private var summary: WeekSummary { NutritionData.summary(of: week) }
    private var maxBar: Double { Double(goal.kcal) * 1.3 }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("This week")
                        .font(AppFont.text(11, weight: .medium))
                        .foregroundStyle(T.ink3)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1fk", Double(summary.kcal) / 1000.0))
                            .font(AppFont.text(22, weight: .bold))
                            .kerning(-0.7)
                            .foregroundStyle(T.ink)
                        Text("kcal")
                            .font(AppFont.text(12))
                            .foregroundStyle(T.ink3)
                    }
                    Text("\(summary.days) of 7 days")
                        .font(AppFont.mono(11))
                        .foregroundStyle(T.ink3)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("AVG / DAY")
                        .font(AppFont.text(10, weight: .semibold))
                        .kerning(0.4)
                        .foregroundStyle(T.ink3)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(summary.avgKcal)")
                            .font(AppFont.text(16, weight: .bold))
                            .kerning(-0.3)
                            .foregroundStyle(T.ink)
                        Text("kcal")
                            .font(AppFont.text(11))
                            .foregroundStyle(T.ink3)
                    }
                    Text("\(summary.avgProtein)g protein")
                        .font(AppFont.mono(11))
                        .foregroundStyle(T.ink2)
                }
            }
            .padding(.bottom, 14)

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(0..<week.count, id: \.self) { i in
                    DayBar(
                        day: week[i],
                        max: maxBar,
                        goal: goal,
                        isToday: i == todayIdx,
                        label: NutritionData.dayLabels[i]
                    )
                }
            }
            .frame(height: 120)

            Divider().background(T.ruleSoft).padding(.top, 10)

            HStack {
                HStack(spacing: 6) {
                    legendChip(color: T.ink, label: "protein")
                    legendChip(color: Color(hex: 0xa8a89c), label: "carbs")
                    legendChip(color: Color(hex: 0xd4d4cc), label: "fat")
                }
                Spacer()
                Text("goal \(goal.kcal)")
                    .font(AppFont.mono(11))
                    .foregroundStyle(T.ink3)
            }
            .padding(.top, 10)
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

    private func legendChip(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(AppFont.text(11))
                .foregroundStyle(T.ink3)
        }
    }
}

struct DayBar: View {
    let day: DayNutrition?
    let max: Double
    let goal: NutritionGoal
    let isToday: Bool
    let label: String

    private var goalLineFraction: CGFloat { CGFloat(Double(goal.kcal) / max) }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    // Goal line
                    Path { p in
                        let y = geo.size.height * (1 - goalLineFraction)
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(T.rule, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))

                    if let d = day {
                        bar(in: geo.size, day: d)
                    } else {
                        // No data — flat marker at the bottom.
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isToday ? T.accent : T.ruleSoft)
                            .frame(height: 6)
                    }
                }
            }
            Text(label)
                .font(AppFont.mono(10, weight: .semibold))
                .kerning(0.4)
                .foregroundStyle(isToday ? T.ink : (day == nil ? T.ink3 : T.ink2))
        }
    }

    private func bar(in size: CGSize, day: DayNutrition) -> some View {
        let pKcal = Double(day.protein * 4)
        let cKcal = Double(day.carbs * 4)
        let fKcal = Double(day.fat * 9)
        let totalMacroKcal = pKcal + cKcal + fKcal
        let totalH = (Double(day.kcal) / max) * size.height
        let pH = totalMacroKcal > 0 ? totalH * (pKcal / totalMacroKcal) : 0
        let cH = totalMacroKcal > 0 ? totalH * (cKcal / totalMacroKcal) : 0
        let fH = totalMacroKcal > 0 ? totalH * (fKcal / totalMacroKcal) : 0

        return VStack(spacing: 0) {
            Rectangle().fill(Color(hex: 0xd4d4cc)).frame(height: CGFloat(fH))
            Rectangle().fill(Color(hex: 0xa8a89c)).frame(height: CGFloat(cH))
            Rectangle().fill(T.ink).frame(height: CGFloat(pH))
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .frame(maxWidth: .infinity)
    }
}
