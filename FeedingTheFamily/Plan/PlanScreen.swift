import SwiftUI

struct PlanScreen: View {
    @Environment(AppState.self) private var state
    @State private var showAutoDraftSheet = false
    @State private var openRecipeMealId: String? = nil
    @State private var swapDayIdx: Int? = nil
    @State private var showSettings = false
    /// 0 = current week, 1 = next week. Transient — not persisted.
    @State private var viewedOffset: Int = 0

    private var isViewingCurrent: Bool { viewedOffset == 0 }
    private var viewedWeek: [DayPlan] {
        if isViewingCurrent { return state.week }
        return state.forwardPlannedWeek ?? []
    }
    private var warnings: [PlanWarning] { Planner.validate(week: viewedWeek, rules: state.rules) }
    private var totalTime: Int { viewedWeek.reduce(0) { $0 + Planner.meal(byId: $1.mealId).time } }

    var body: some View {
        VStack(spacing: 0) {
            header
            FreshnessLane(week: viewedWeek, rules: state.rules)
                .padding(.horizontal, 22)
                .padding(.bottom, 6)
            if isViewingCurrent {
                WeeklyRecapCard(
                    week: state.week,
                    ratings: state.ratings,
                    ratingFeedback: state.ratingFeedback,
                    unratedDays: state.unratedDays,
                    todayIdx: state.todayIdx
                )
                .padding(.horizontal, 22)
                .padding(.bottom, 8)
            }
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        if !isViewingCurrent && nextWeekIsUntouched {
                            nextWeekEmpty
                                .padding(.horizontal, 12)
                                .padding(.top, 8)
                        }
                        ForEach(Array(viewedWeek.enumerated()), id: \.element.id) { idx, day in
                            DayCard(
                                day: day,
                                idx: idx,
                                isToday: isViewingCurrent && idx == state.todayIdx,
                                isPast: isViewingCurrent && idx < state.todayIdx,
                                warning: warnings.first(where: { $0.dayIdx == idx }),
                                quickNight: state.rules.quickNights.contains(day.day),
                                confidence: Learning.confidence(for: day.mealId, ratings: state.ratings),
                                trend: Learning.trend(for: day.mealId, ratings: state.ratings),
                                unrated: isViewingCurrent && state.unratedDays.contains(day.day),
                                onToggleLock: { toggleLock(idx: idx) },
                                onSwap: { swapDayIdx = idx },
                                onRate: { stars, note in rate(day: day, stars: stars, note: note) },
                                onOpenRecipe: { openRecipeMealId = day.mealId }
                            )
                            .id(day.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 80) // leave room for floating Auto-draft button
                }
                .onAppear {
                    // Land near today's card so the user doesn't have to scroll past
                    // past meals on launch. Skip on next-week view.
                    if isViewingCurrent, state.todayIdx < viewedWeek.count {
                        let target = viewedWeek[max(0, state.todayIdx - 1)].id
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(target, anchor: .top)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottomTrailing) {
                AutoDraftButton {
                    showAutoDraftSheet = true
                }
                .padding(.trailing, 14)
                .padding(.bottom, 14)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(T.paper)
        .sheet(isPresented: $showAutoDraftSheet) {
            AutoDraftSheet(rules: state.rules) { config in
                autoDraft(config: config)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: Binding(
            get: { openRecipeMealId.map { PlanMealIdWrap(id: $0) } },
            set: { openRecipeMealId = $0?.id })
        ) { wrap in
            RecipeDetail(mealId: wrap.id)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: Binding(
            get: { swapDayIdx.map { SwapIdxWrap(idx: $0) } },
            set: { swapDayIdx = $0?.idx })
        ) { wrap in
            SwapSheet(
                dayIdx: wrap.idx,
                week: viewedWeek,
                rules: state.rules,
                ratings: state.ratings,
                customMeals: state.customMeals,
                mealOverrides: state.mealOverrides,
                dismissedMealIds: state.dismissedMealIds,
                onSelect: { mealId in
                    var next = viewedWeek
                    next[wrap.idx].mealId = mealId
                    withAnimation(.easeInOut(duration: 0.25)) {
                        setViewedWeek(next)
                    }
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(weekDateLabel) · 7 dinners")
                    .font(AppFont.text(11, weight: .medium))
                    .foregroundStyle(T.ink3)
                HStack(spacing: 8) {
                    Text(isViewingCurrent ? "This week" : "Next week")
                        .font(AppFont.text(28, weight: .bold))
                        .kerning(-1)
                        .foregroundStyle(T.ink)
                    weekNavArrows
                }
            }
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(T.paper)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(T.ink))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 22)
        .padding(.top, 4)
        .padding(.bottom, 10)
    }

    private var weekDateLabel: String {
        if isViewingCurrent { return Today.weekHeaderLabel }
        return "Week of \(Today.dateLabel(weeksAhead: 1, dayIdx: 0))"
    }

    private var weekNavArrows: some View {
        HStack(spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { viewedOffset = 0 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isViewingCurrent ? T.ink3 : T.ink)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(isViewingCurrent ? T.paperDeep : T.paperDeep))
            }
            .buttonStyle(.plain)
            .disabled(isViewingCurrent)

            Button {
                if state.forwardPlannedWeek == nil {
                    state.forwardPlannedWeek = freshNextWeek()
                }
                withAnimation(.easeInOut(duration: 0.2)) { viewedOffset = 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isViewingCurrent ? T.ink : T.ink3)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(T.paperDeep))
            }
            .buttonStyle(.plain)
            .disabled(!isViewingCurrent)
        }
    }

    /// True when next-week is still the bare seed pattern with no locks — the
    /// signal that the user hasn't planned it yet, so we show a "tap Auto-draft"
    /// callout instead of pretending those meals are intentional.
    private var nextWeekIsUntouched: Bool {
        guard let fp = state.forwardPlannedWeek, fp.count == 7 else { return true }
        for (idx, day) in fp.enumerated() {
            if day.locked { return false }
            if day.mealId != SeedData.week[idx].mealId { return false }
        }
        return true
    }

    private var nextWeekEmpty: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(T.ink2)
                Text("NEXT WEEK IS A BLANK SLATE")
                    .font(AppFont.text(10.5, weight: .bold))
                    .kerning(1.2)
                    .foregroundStyle(T.ink2)
            }
            Text("These are placeholder meals. Tap **Auto-draft** to generate a real plan based on your rules + family ratings, or **Swap** any day to pick something specific.")
                .font(AppFont.text(12.5))
                .foregroundStyle(T.ink2)
                .lineSpacing(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(T.accent.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(T.accent2.opacity(0.3), lineWidth: 1)
                )
        )
    }

    /// Build a default empty week for "next week" with proper dates. Uses the
    /// seed slot pattern (cook/quick/leftover/weekend) so Auto-draft on it works.
    private func freshNextWeek() -> [DayPlan] {
        Today.labels.enumerated().map { idx, label in
            DayPlan(
                day: label,
                date: Today.dateLabel(weeksAhead: 1, dayIdx: idx),
                mealId: SeedData.week[idx].mealId,
                locked: false,
                slot: SeedData.week[idx].slot
            )
        }
    }

    private func setViewedWeek(_ next: [DayPlan]) {
        if isViewingCurrent {
            state.week = next
        } else {
            state.forwardPlannedWeek = next
        }
    }

    private func toggleLock(idx: Int) {
        var next = viewedWeek
        next[idx].locked.toggle()
        setViewedWeek(next)
    }

    private func rate(day: DayPlan, stars: Int, note: String? = nil) {
        state.ratings[day.mealId, default: []].append(stars)
        state.ratingFeedback[day.mealId, default: []].append(note ?? "")
        state.unratedDays.remove(day.day)
    }

    private struct PlanMealIdWrap: Identifiable { let id: String }
    private struct SwapIdxWrap: Identifiable { let idx: Int; var id: Int { idx } }

    private func autoDraft(config: AutoDraftConfig) {
        var rules = state.rules
        rules.meatDays = config.disabled.contains(.freshness) ? 999 : config.meatDays
        rules.quickNights = config.disabled.contains(.quickNights) ? [] : config.quickNights
        rules.avoidIngredients = config.disabled.contains(.avoidances) ? [] : config.avoidances
        let useScoring = !config.disabled.contains(.scoreWeighting)
        let useDiscovery = !config.disabled.contains(.weekendDiscovery)

        // Persist edits made in the sheet so the rules stay updated outside it too.
        if !config.disabled.contains(.freshness)   { state.rules.meatDays = config.meatDays }
        if !config.disabled.contains(.quickNights) { state.rules.quickNights = config.quickNights }
        if !config.disabled.contains(.avoidances)  { state.rules.avoidIngredients = config.avoidances }

        withAnimation(.easeInOut(duration: 0.3)) {
            let drafted = Planner.autoDraft(
                week: viewedWeek,
                rules: rules,
                ratings: useScoring ? state.ratings : [:],
                weekendDiscovery: useDiscovery,
                customMeals: state.customMeals,
                dismissed: state.dismissedMealIds
            )
            setViewedWeek(drafted)
        }
    }
}

#Preview {
    RootView()
}
