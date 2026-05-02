import SwiftUI

struct SwapSheet: View {
    let dayIdx: Int
    let week: [DayPlan]
    let rules: Rules
    let ratings: [String: [Int]]
    let customMeals: [Meal]
    let mealOverrides: [String: Meal]
    let dismissedMealIds: Set<String>
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private var day: DayPlan { week[dayIdx] }
    private var currentMeal: Meal {
        Planner.activeMeal(id: day.mealId, overrides: mealOverrides, custom: customMeals)
    }

    private struct Candidate: Identifiable {
        let meal: Meal
        let confidence: Double
        let trend: Trend
        var id: String { meal.id }
    }

    private var candidates: [Candidate] {
        let isQuick = rules.quickNights.contains(day.day)
        let prevProtein: String? = dayIdx > 0
            ? Planner.protein(for: Planner.activeMeal(id: week[dayIdx - 1].mealId,
                                                     overrides: mealOverrides,
                                                     custom: customMeals)).name
            : nil
        let weekMealsExceptThis = Set(week.enumerated()
            .filter { $0.offset != dayIdx }
            .map(\.element.mealId))

        // Swap is permissive about the fresh-meat day window — the freshness lane
        // already flags violations visually, and a swap is a deliberate manual
        // override anyway. This is what makes Sun (day 7) show real options
        // instead of just "leftovers".
        let pool = Planner.allMeals(custom: customMeals, dismissed: dismissedMealIds)
            .map { Planner.activeMeal(id: $0.id, overrides: mealOverrides, custom: customMeals) }

        func filter(strict: Bool) -> [Meal] {
            pool.filter { m in
                if m.id == day.mealId { return false }
                if weekMealsExceptThis.contains(m.id) { return false }
                if m.ings.contains(where: { rules.avoidIngredients.contains($0.name) }) { return false }
                if isQuick && m.time > 30 { return false }
                let p = Planner.protein(for: m)
                if strict, let prev = prevProtein, prev == p.name { return false }
                return true
            }
        }

        var meals = filter(strict: true)
        if meals.isEmpty {
            // Last-ditch: also drop the no-repeat-protein rule.
            meals = filter(strict: false)
        }

        return meals
            .map {
                Candidate(
                    meal: $0,
                    confidence: Learning.confidence(for: $0.id, ratings: ratings),
                    trend: Learning.trend(for: $0.id, ratings: ratings)
                )
            }
            .sorted { $0.confidence > $1.confidence }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(T.rule)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    currentMealRow
                    sectionLabel("SUGGESTED SWAPS")
                    if candidates.isEmpty {
                        emptyMessage
                    } else {
                        ForEach(candidates) { c in
                            row(c)
                        }
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .background(T.paper)
    }

    // ── Header ──────────────────────────────────────

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Swap meal")
                    .font(AppFont.text(11, weight: .medium))
                    .kerning(1.2)
                    .foregroundStyle(T.ink3)
                Text("\(day.day) · \(day.date)")
                    .font(AppFont.text(24, weight: .bold))
                    .kerning(-0.7)
                    .foregroundStyle(T.ink)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(T.ink2)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(T.paperDeep))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 14)
    }

    // ── Currently planned ──────────────────────────

    private var currentMealRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("CURRENTLY PLANNED")
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(proteinDotColor(Planner.protein(for: currentMeal)))
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentMeal.title)
                        .font(AppFont.text(15, weight: .semibold))
                        .foregroundStyle(T.ink)
                    Text("\(Planner.protein(for: currentMeal).name) · \(currentMeal.time)m\(currentMeal.kid ? " · kid-approved" : "")")
                        .font(AppFont.text(11))
                        .foregroundStyle(T.ink3)
                }
                Spacer(minLength: 0)
                Button { dismiss() } label: {
                    Text("Keep")
                        .font(AppFont.text(11, weight: .semibold))
                        .foregroundStyle(T.ink2)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().strokeBorder(T.rule, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(T.paperDeep)
            )
        }
        .padding(.horizontal, 22)
    }

    // ── Candidate rows ─────────────────────────────

    private func row(_ c: Candidate) -> some View {
        Button {
            onSelect(c.meal.id)
            dismiss()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(proteinDotColor(Planner.protein(for: c.meal)))
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
                VStack(alignment: .leading, spacing: 4) {
                    Text(c.meal.title)
                        .font(AppFont.text(15, weight: .semibold))
                        .foregroundStyle(T.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 8) {
                        Text(Planner.protein(for: c.meal).name)
                            .font(AppFont.text(11))
                            .foregroundStyle(T.ink2)
                        Text("·").foregroundStyle(T.rule)
                        Text("\(c.meal.time)m")
                            .font(AppFont.mono(11))
                            .foregroundStyle(T.ink2)
                        if c.meal.kid {
                            Text("·").foregroundStyle(T.rule)
                            Text("kid-approved")
                                .font(AppFont.text(11, weight: .semibold))
                                .foregroundStyle(T.accent2)
                        }
                    }
                }
                Spacer(minLength: 0)
                if c.confidence > 0 {
                    ConfidenceBadge(confidence: c.confidence, trend: c.trend)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
            .overlay(alignment: .bottom) {
                Rectangle().fill(T.ruleSoft).frame(height: 1).padding(.horizontal, 22)
            }
        }
        .buttonStyle(.plain)
    }

    private var emptyMessage: some View {
        Text("No swaps fit your rules right now. Try Auto-draft to see why.")
            .font(AppFont.text(12))
            .foregroundStyle(T.ink3)
            .padding(.horizontal, 22)
            .padding(.top, 8)
    }

    // ── Helpers ────────────────────────────────────

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(AppFont.text(10.5, weight: .bold))
            .kerning(1.2)
            .foregroundStyle(T.ink3)
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 8)
    }

    private func proteinDotColor(_ p: Protein) -> Color {
        switch p.perish {
        case .fresh:  return T.proteinFresh
        case .frozen: return T.proteinFrozen
        case .pantry: return T.proteinPantry
        }
    }
}
