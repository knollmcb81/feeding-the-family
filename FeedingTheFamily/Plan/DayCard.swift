import SwiftUI

struct DayCard: View {
    @Environment(AppState.self) private var state
    let day: DayPlan
    let idx: Int
    let isToday: Bool
    let isPast: Bool
    let warning: PlanWarning?
    let quickNight: Bool
    let confidence: Double
    let trend: Trend
    let unrated: Bool
    let inGroceryList: Bool
    let onToggleLock: () -> Void
    let onSwap: () -> Void
    let onToggleGroceryList: () -> Void
    let onRate: (Int, String?) -> Void
    let onOpenRecipe: () -> Void

    private var needsRating: Bool { isPast && unrated }

    /// Triggers a one-shot sparkle when day.mealId changes. Each new id gives
    /// SparkleBurst a fresh identity, which restarts its onAppear animation.
    @State private var sparkleId: UUID? = nil
    @State private var lastMealId: String = ""

    var body: some View {
        let m = Planner.activeMeal(id: day.mealId, overrides: state.mealOverrides)
        let p = Planner.protein(for: m)

        HStack(alignment: .top, spacing: 14) {
            spine
            mealBody(meal: m, protein: p)
                .layoutPriority(1)
                .contentShape(Rectangle())
                .onTapGesture { onOpenRecipe() }
            actions
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 11)
        .padding(.horizontal, 12)
        .background(rowBackground)
        .overlay(alignment: .top) {
            if idx > 0 {
                Rectangle().fill(T.rule).frame(height: 1)
            }
        }
        .overlay(alignment: .leading) {
            if isToday {
                Rectangle()
                    .fill(T.accent)
                    .frame(width: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .padding(.vertical, 12)
            }
        }
        .opacity(isPast && !needsRating ? 0.55 : 1)
        .overlay {
            if let sid = sparkleId {
                SparkleBurst()
                    .id(sid)
            }
        }
        .onChange(of: day.mealId) { oldValue, newValue in
            // Skip the first render — we don't want to fire on initial appearance.
            // Only trigger when the meal genuinely changes after the card has shown.
            if !lastMealId.isEmpty && oldValue != newValue {
                sparkleId = UUID()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
                    if sparkleId != nil { sparkleId = nil }
                }
            }
            lastMealId = newValue
        }
        .onAppear { lastMealId = day.mealId }
    }

    private var rowBackground: some View {
        Group {
            if let _ = warning {
                Color(red: 1, green: 107/255, blue: 61/255).opacity(0.05)
            } else if isToday {
                Color(red: 184/255, green: 84/255, blue: 58/255).opacity(0.05)
            } else {
                Color.clear
            }
        }
    }

    private var spine: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(day.day)
                .font(AppFont.text(20, weight: .bold))
                .kerning(-0.6)
                .foregroundStyle(T.ink)
            Text(day.date)
                .font(AppFont.mono(9, weight: .medium))
                .foregroundStyle(T.ink3)
        }
        .frame(width: 50, alignment: .leading)
        .padding(.top, 1)
    }

    private func mealBody(meal m: Meal, protein p: Protein) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            tagRow
            Text(m.title)
                .font(AppFont.text(16, weight: .semibold))
                .kerning(-0.3)
                .foregroundStyle(T.ink)
                .fixedSize(horizontal: false, vertical: true)
            metaRow(protein: p, time: m.time, kid: m.kid)
            if let w = warning {
                Text(w.msg)
                    .font(AppFont.text(11.5, weight: .medium))
                    .foregroundStyle(T.warn)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(T.warn.opacity(0.1))
                    )
            }
            if needsRating {
                RatingPrompt(onRate: onRate)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var tagRow: some View {
        HStack(spacing: 6) {
            if isToday {
                pill(text: "TONIGHT", fg: T.paper, bg: T.ink)
            }
            if quickNight {
                HStack(spacing: 3) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9))
                    Text("QUICK")
                }
                .font(AppFont.text(9.5, weight: .bold))
                .kerning(0.4)
                .foregroundStyle(T.ink)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4).fill(T.accent))
            }
            if day.locked && !quickNight && !isToday {
                Text("LOCKED")
                    .font(AppFont.text(9.5, weight: .bold))
                    .kerning(0.6)
                    .foregroundStyle(T.ink3)
            }
            if !isPast && !isToday && confidence > 0 {
                ConfidenceBadge(confidence: confidence, trend: trend)
            }
        }
    }

    private func pill(text: String, fg: Color, bg: Color) -> some View {
        Text(text)
            .font(AppFont.text(9.5, weight: .bold))
            .kerning(0.6)
            .foregroundStyle(fg)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 4).fill(bg))
    }

    private func metaRow(protein p: Protein, time: Int, kid: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(proteinDotColor(p))
                .frame(width: 8, height: 8)
            (
                Text(p.name).foregroundStyle(T.ink2)
                + Text(" · ").foregroundStyle(T.rule)
                + Text(Image(systemName: "clock")).foregroundStyle(T.ink2)
                + Text(" \(time)m").foregroundStyle(T.ink2).font(AppFont.mono(11))
                + (kid
                    ? Text(" · ").foregroundStyle(T.rule)
                        + Text("kid-approved").foregroundStyle(T.accent2).font(AppFont.text(11, weight: .semibold))
                    : Text(""))
            )
            .font(AppFont.text(12))
            .lineLimit(1)
        }
    }

    private func proteinDotColor(_ p: Protein) -> Color {
        switch p.perish {
        case .fresh:  return T.proteinFresh
        case .frozen: return T.proteinFrozen
        case .pantry: return T.proteinPantry
        }
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 6) {
            if isPast {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(T.ink3)
                    .frame(width: 34, height: 34)
            } else {
                Button(action: onToggleLock) {
                    Image(systemName: day.locked ? "lock.fill" : "lock.open")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(day.locked ? T.accent : T.ink2)
                        .frame(width: 34, height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.mini)
                                .fill(day.locked ? T.ink : T.paperDeep)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.locked ? "Unlock \(day.day)'s meal" : "Lock \(day.day)'s meal")

                Button(action: onSwap) {
                    VStack(spacing: 1) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 15))
                            .foregroundStyle(T.ink)
                        Text("SWAP")
                            .font(AppFont.text(8, weight: .bold))
                            .kerning(0.4)
                            .foregroundStyle(T.ink2)
                    }
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(T.paperDeep)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(T.rule, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Swap \(day.day)'s meal")

                Button(action: onToggleGroceryList) {
                    Image(systemName: inGroceryList ? "cart.fill" : "cart")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(inGroceryList ? T.accent2 : T.ink3)
                        .frame(width: 34, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.mini)
                                .fill(inGroceryList ? T.accent2.opacity(0.12) : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Radius.mini)
                                        .stroke(inGroceryList ? Color.clear : T.rule, lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(inGroceryList ? "Remove \(day.day) from grocery list" : "Add \(day.day) to grocery list")
            }
        }
    }
}
