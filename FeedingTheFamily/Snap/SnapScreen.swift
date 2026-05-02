import SwiftUI

struct SnapScreen: View {
    @Environment(AppState.self) private var state
    @State private var phase: Phase = .log
    @State private var pendingFixture: SnapFixture? = nil
    @State private var capturedPhoto: Data? = nil
    @State private var visionError: String? = nil

    private enum Phase { case log, viewfinder, analyzing }

    private var goal: NutritionGoal { state.nutritionGoal }

    /// Seeded historical week, with today's slot overwritten by the live snap-log totals.
    private var thisWeek: [DayNutrition?] {
        var week = NutritionData.weeks[NutritionData.todayWeekIdx]
        let idx = Today.todayIdx
        if idx < week.count {
            let t = todayTotals
            if t.kcal > 0 {
                week[idx] = t
            }
        }
        return week
    }

    /// Snaps logged today (Date matches Today.date).
    private var todaySnaps: [SnapEntry] {
        let cal = Calendar.current
        return state.snapLog.filter { cal.isDate($0.timestamp, inSameDayAs: Date()) }
    }

    /// Sum of today's snaps for the macro card.
    private var todayTotals: DayNutrition {
        todaySnaps.reduce(DayNutrition(kcal: 0, protein: 0, carbs: 0, fat: 0)) {
            DayNutrition(
                kcal: $0.kcal + $1.kcal,
                protein: $0.protein + $1.protein,
                carbs: $0.carbs + $1.carbs,
                fat: $0.fat + $1.fat
            )
        }
    }

    var body: some View {
        ZStack {
            mainContent
                .opacity(phase == .log ? 1 : 0)

            if phase == .viewfinder {
                CameraViewfinder(
                    snapsToday: todaySnaps.count,
                    onCancel: { phase = .log },
                    onShutter: { photoData in
                        capturedPhoto = photoData
                        phase = .analyzing
                    }
                )
                .transition(.opacity)
            }

            if phase == .analyzing {
                AnalyzingView {
                    Task { await runDetection() }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: phase)
        .sheet(item: $pendingFixture) { fixture in
            SnapResultSheet(
                fixture: fixture,
                week: state.week,
                onLog: { entry in
                    state.snapLog.append(entry)
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .alert("Vision didn't work",
               isPresented: Binding(get: { visionError != nil }, set: { if !$0 { visionError = nil } })) {
            Button("Copy error") {
                UIPasteboard.general.string = visionError
                visionError = nil
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(visionError ?? "")
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    macroRow
                    snapsTodaySection
                    ThisWeekCard(week: thisWeek, goal: goal, todayIdx: NutritionData.todayDayIdx)
                    FourWeekTrendCard(weeks: NutritionData.weeks, goal: goal)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottomTrailing) {
                snapButton
                    .padding(.trailing, 14)
                    .padding(.bottom, 14)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(T.paper)
    }

    /// After the analyzing animation lands, do the actual detection.
    /// - Real photo + API key set → call Claude Vision.
    /// - Real photo, no key → alert the user explicitly (don't silently use mock).
    /// - No photo (simulator or capture failed) → fall back to demo fixtures.
    private func runDetection() async {
        let key = state.anthropicApiKey.trimmingCharacters(in: .whitespaces)

        if let photo = capturedPhoto {
            guard !key.isEmpty else {
                await MainActor.run {
                    visionError = "Real food detection needs an Anthropic API key. "
                        + "Open the Plan tab → gear icon → AI Vision and paste a key (sk-ant-…). "
                        + "Without a key, taps cycle through built-in demo fixtures."
                    phase = .log
                    capturedPhoto = nil
                }
                return
            }
            do {
                let fixture = try await AnthropicVision.classify(imageData: photo, apiKey: key)
                await MainActor.run {
                    pendingFixture = fixture
                    phase = .log
                    capturedPhoto = nil
                }
            } catch {
                await MainActor.run {
                    visionError = (error as? LocalizedError)?.errorDescription ?? "\(error)"
                    phase = .log
                    capturedPhoto = nil
                }
            }
            return
        }

        // No photo (simulator / capture failed) — demo fallback.
        let next = SnapFixtures.next(after: state.lastSnapFixtureIdx)
        state.lastSnapFixtureIdx = next.idx
        pendingFixture = next.fixture
        phase = .log
        capturedPhoto = nil
    }

    // ── Header ──────────────────────────────

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Today.todayHeaderLabel)
                    .font(AppFont.text(11, weight: .medium))
                    .foregroundStyle(T.ink3)
                Text("Today's nutrition")
                    .font(AppFont.text(28, weight: .bold))
                    .kerning(-1)
                    .foregroundStyle(T.ink)
            }
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 4)
        .padding(.bottom, 10)
    }

    // ── Macros vs goal (today) ──────────────

    private var macroRow: some View {
        HStack(alignment: .top, spacing: 16) {
            MacroRing(
                protein: Double(todayTotals.protein),
                carbs:   Double(todayTotals.carbs),
                fat:     Double(todayTotals.fat),
                goalKcal: goal.kcal
            )
            .frame(width: 110, height: 110)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(todayTotals.kcal)")
                        .font(AppFont.text(22, weight: .bold))
                        .kerning(-0.5)
                        .foregroundStyle(T.ink)
                    Text("/ \(goal.kcal) kcal")
                        .font(AppFont.text(11))
                        .foregroundStyle(T.ink3)
                }
                macroBar(label: "PROTEIN", current: todayTotals.protein, goal: goal.protein, color: T.ink)
                macroBar(label: "CARBS",   current: todayTotals.carbs,   goal: goal.carbs,   color: Color(hex: 0xa8a89c))
                macroBar(label: "FAT",     current: todayTotals.fat,     goal: goal.fat,     color: Color(hex: 0xd4d4cc))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.card)
                .fill(T.card)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.card)
                        .strokeBorder(T.ruleSoft, lineWidth: 1)
                )
        )
    }

    private func macroBar(label: String, current: Int, goal: Int, color: Color = T.ink) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(AppFont.text(9, weight: .bold))
                    .kerning(0.5)
                    .foregroundStyle(T.ink3)
                Spacer()
                Text("\(current)/\(goal)g")
                    .font(AppFont.mono(9.5))
                    .foregroundStyle(T.ink2)
            }
            GeometryReader { geo in
                let pct = goal > 0 ? min(1, Double(current) / Double(goal)) : 0
                ZStack(alignment: .leading) {
                    Capsule().fill(T.paperDeep)
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * pct)
                        .animation(.easeOut(duration: 0.4), value: pct)
                }
            }
            .frame(height: 4)
        }
    }

    // ── Snaps today ─────────────────────────

    private var snapsTodaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SNAPS TODAY")
                    .font(AppFont.text(10.5, weight: .bold))
                    .kerning(1.2)
                    .foregroundStyle(T.ink3)
                Text("· \(todaySnaps.count)")
                    .font(AppFont.mono(10.5))
                    .foregroundStyle(T.ink3)
                Spacer()
            }
            if todaySnaps.isEmpty {
                Text("Tap Snap to log your first meal of the day")
                    .font(AppFont.text(12))
                    .foregroundStyle(T.ink3)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(T.rule, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    )
            } else {
                VStack(spacing: 0) {
                    ForEach(todaySnaps) { entry in
                        snapEntryRow(entry)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(T.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(T.ruleSoft, lineWidth: 1)
                        )
                )
            }
        }
    }

    private func snapEntryRow(_ entry: SnapEntry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.title)
                        .font(AppFont.text(13, weight: .semibold))
                        .foregroundStyle(T.ink)
                    if entry.savedAsInspiration {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(T.accent2)
                    }
                }
                if let mealId = entry.assignedToMealId {
                    Text("logged to \(Planner.meal(byId: mealId).title)")
                        .font(AppFont.mono(10))
                        .foregroundStyle(T.ink3)
                } else {
                    Text(timeOfDay(entry.timestamp))
                        .font(AppFont.mono(10))
                        .foregroundStyle(T.ink3)
                }
            }
            Spacer(minLength: 8)
            Text("\(entry.kcal) kcal")
                .font(AppFont.mono(11, weight: .semibold))
                .foregroundStyle(T.ink2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(T.ruleSoft).frame(height: 1).padding(.horizontal, 12)
        }
    }

    private func timeOfDay(_ d: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: d)
    }

    // ── Snap button ─────────────────────────

    private var snapButton: some View {
        Button {
            phase = .viewfinder
        } label: {
            Image(systemName: "camera.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(T.ink)
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(T.accent)
                        .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 8)
                        .shadow(color: Color.black.opacity(0.20), radius: 3, x: 0, y: 2)
                )
        }
        .buttonStyle(.plain)
    }
}
