import SwiftUI

/// First-launch setup. Walks through 4 quick steps so the user's family + rules
/// aren't permanently inherited from Britt's seed values. Persists to AppState
/// and marks `hasCompletedOnboarding` so it doesn't show again.
struct OnboardingFlow: View {
    @Environment(AppState.self) private var state
    @State private var step: Int = 0

    @State private var adults: Int = 2
    @State private var kids: Int = 2
    @State private var weeknightCap: Int = 40
    @State private var quickNights: Set<String> = ["Tue", "Thu"]
    @State private var shopDay: String = "Sun"
    @State private var avoidances: [String] = ["onions", "onion", "mushrooms", "mushroom"]
    @State private var newAvoidance: String = ""
    @State private var apiKey: String = ""
    @State private var apiTesting: Bool = false
    @State private var apiResult: TestResult? = nil
    @FocusState private var addAvoidanceFocused: Bool

    private enum TestResult: Equatable {
        case ok
        case failure(String)
    }

    private let weekdays = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]
    private let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            progress
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    switch step {
                    case 0: welcomeStep
                    case 1: familyStep
                    case 2: rulesStep
                    case 3: visionStep
                    default: EmptyView()
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 100)
            }
            actionBar
        }
        .background(T.paper)
    }

    // ── Progress strip ──────────────────────

    private var progress: some View {
        HStack(spacing: 4) {
            ForEach(0..<totalSteps, id: \.self) { idx in
                Capsule()
                    .fill(idx <= step ? T.ink : T.rule)
                    .frame(height: 3)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    // ── Step 0 — Welcome ─────────────────────

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Welcome")
                .font(AppFont.text(11, weight: .bold))
                .kerning(1.2)
                .foregroundStyle(T.ink3)
            Text("Let's set up your kitchen.")
                .font(AppFont.text(28, weight: .bold))
                .kerning(-1)
                .foregroundStyle(T.ink)
            Text("Four quick questions so the meal plans, grocery lists, and nutrition targets fit your household — not someone else's. You can change any of this later in Settings.")
                .font(AppFont.text(14))
                .foregroundStyle(T.ink2)
                .lineSpacing(3)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 12) {
                bullet("Plan dinners that respect cook time, freshness, and what your family won't eat")
                bullet("Auto-generate a grocery list grouped by aisle")
                bullet("Snap a photo of any meal for AI macro estimates")
                bullet("See ratings + history grow as you cook")
            }
            .padding(.top, 8)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(T.accent)
                .frame(width: 6, height: 6)
                .padding(.top, 7)
            Text(text)
                .font(AppFont.text(13))
                .foregroundStyle(T.ink)
                .lineSpacing(2)
        }
    }

    // ── Step 1 — Family ──────────────────────

    private var familyStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            stepHeader(eyebrow: "Step 1 of 3", title: "Who are you cooking for?")

            stepperRow(label: "Adults", value: $adults, range: 1...6)
            stepperRow(label: "Kids",   value: $kids,   range: 0...8)

            Text("Used to scale recipe servings and tag kid-friendly meals.")
                .font(AppFont.text(12))
                .foregroundStyle(T.ink3)
                .padding(.top, 4)
        }
    }

    // ── Step 2 — Rules ───────────────────────

    private var rulesStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            stepHeader(eyebrow: "Step 2 of 3", title: "Your weekly rhythm")

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("SHOP DAY")
                weekdayChips(selection: Binding(
                    get: { Set([shopDay]) },
                    set: { newSet in
                        if let pick = newSet.first { shopDay = pick }
                    }
                ), single: true)
                Text("Used as the start of your week's freshness window.")
                    .font(AppFont.text(11))
                    .foregroundStyle(T.ink3)
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("QUICK NIGHTS")
                weekdayChips(selection: $quickNights, single: false)
                Text("Days dinner has to be 30 minutes or less.")
                    .font(AppFont.text(11))
                    .foregroundStyle(T.ink3)
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("WEEKNIGHT MAX TIME")
                HStack {
                    Slider(
                        value: Binding(
                            get: { Double(weeknightCap) },
                            set: { weeknightCap = Int($0) }
                        ),
                        in: 15...90, step: 5
                    )
                    .tint(T.ink)
                    Text("\(weeknightCap)m")
                        .font(AppFont.mono(13, weight: .semibold))
                        .foregroundStyle(T.ink)
                        .frame(width: 50, alignment: .trailing)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("AVOIDANCES")
                FlowLayout(spacing: 6) {
                    ForEach(avoidances, id: \.self) { word in
                        Button {
                            avoidances.removeAll { $0 == word }
                        } label: {
                            HStack(spacing: 4) {
                                Text(word)
                                    .font(AppFont.text(11, weight: .medium))
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .foregroundStyle(T.ink2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(T.paperDeep))
                        }
                        .buttonStyle(.plain)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(T.ink3)
                        TextField("add", text: $newAvoidance)
                            .font(AppFont.text(11, weight: .medium))
                            .foregroundStyle(T.ink)
                            .focused($addAvoidanceFocused)
                            .submitLabel(.done)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .frame(minWidth: 50)
                            .onSubmit { commitAvoidance() }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(T.card)
                            .overlay(Capsule().strokeBorder(T.rule, style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
                    )
                }
                Text("Meals containing these ingredients won't get planned. Add a few common dislikes (kids' picky list works well).")
                    .font(AppFont.text(11))
                    .foregroundStyle(T.ink3)
            }
        }
    }

    // ── Step 3 — Vision ──────────────────────

    private var visionStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepHeader(eyebrow: "Step 3 of 3 · Optional", title: "Connect AI Vision")

            Text("Snap a photo of any meal and Claude estimates the macros. Skip if you'd rather try the demo first — you can always add a key later in Settings.")
                .font(AppFont.text(13))
                .foregroundStyle(T.ink2)
                .lineSpacing(2)

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("ANTHROPIC API KEY")
                SecureField("sk-ant-…", text: Binding(
                    get: { apiKey },
                    set: { apiKey = $0
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    }
                ))
                .font(AppFont.mono(12))
                .foregroundStyle(T.ink)
                .tint(T.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(T.paperDeep)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(T.rule, lineWidth: 1))
                )
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

                if !apiKey.isEmpty {
                    HStack(spacing: 8) {
                        Button {
                            runTest()
                        } label: {
                            HStack(spacing: 6) {
                                if apiTesting {
                                    ProgressView().controlSize(.small).tint(T.ink)
                                } else {
                                    Image(systemName: "bolt.fill").font(.system(size: 11, weight: .semibold))
                                }
                                Text(apiTesting ? "Testing…" : "Test connection")
                                    .font(AppFont.text(12, weight: .semibold))
                            }
                            .foregroundStyle(T.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().strokeBorder(T.ink, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .disabled(apiTesting)

                        switch apiResult {
                        case .ok:
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Connected")
                                    .font(AppFont.text(11, weight: .semibold))
                            }
                            .foregroundStyle(T.accent2)
                        case .failure(let m):
                            Text(m)
                                .font(AppFont.text(10.5))
                                .foregroundStyle(T.warn)
                                .lineLimit(3)
                        case .none:
                            EmptyView()
                        }
                    }
                    .padding(.top, 4)
                }
            }

            Text("Get a key at console.anthropic.com → Settings → API Keys. Costs ~½¢ per snap. The key is stored on this device only.")
                .font(AppFont.text(11))
                .foregroundStyle(T.ink3)
                .lineSpacing(2)
                .padding(.top, 4)
        }
    }

    // ── Action bar ───────────────────────────

    private var actionBar: some View {
        HStack(spacing: 10) {
            if step > 0 {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { step -= 1 }
                } label: {
                    Text("Back")
                        .font(AppFont.text(13, weight: .semibold))
                        .foregroundStyle(T.ink2)
                        .frame(width: 80)
                        .padding(.vertical, 12)
                        .background(Capsule().strokeBorder(T.rule, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            Button {
                if step < totalSteps - 1 {
                    withAnimation(.easeInOut(duration: 0.18)) { step += 1 }
                } else {
                    finish()
                }
            } label: {
                HStack(spacing: 6) {
                    Text(step == totalSteps - 1 ? "Get cooking" : "Continue")
                        .font(AppFont.text(13, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(T.accentInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Capsule().fill(T.accent))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 22)
        .padding(.top, 12)
        .background(
            T.paper
                .overlay(alignment: .top) {
                    Rectangle().fill(T.ruleSoft).frame(height: 1)
                }
        )
    }

    // ── Helpers ──────────────────────────────

    private func stepHeader(eyebrow: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow.uppercased())
                .font(AppFont.text(11, weight: .bold))
                .kerning(1.2)
                .foregroundStyle(T.ink3)
            Text(title)
                .font(AppFont.text(24, weight: .bold))
                .kerning(-0.7)
                .foregroundStyle(T.ink)
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(AppFont.text(11, weight: .bold))
            .kerning(1.2)
            .foregroundStyle(T.ink3)
    }

    private func stepperRow(label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(label)
                .font(AppFont.text(15))
                .foregroundStyle(T.ink)
            Spacer()
            HStack(spacing: 8) {
                Button { if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 } } label: {
                    miniBtn("−")
                }.buttonStyle(.plain)
                Text("\(value.wrappedValue)")
                    .font(AppFont.mono(15, weight: .semibold))
                    .frame(minWidth: 24)
                Button { if value.wrappedValue < range.upperBound { value.wrappedValue += 1 } } label: {
                    miniBtn("+")
                }.buttonStyle(.plain)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 10).fill(T.paperDeep)
        )
    }

    private func miniBtn(_ glyph: String) -> some View {
        Text(glyph)
            .font(AppFont.text(16, weight: .semibold))
            .foregroundStyle(T.ink)
            .frame(width: 32, height: 32)
            .background(RoundedRectangle(cornerRadius: 6).fill(T.card))
    }

    private func weekdayChips(selection: Binding<Set<String>>, single: Bool) -> some View {
        HStack(spacing: 4) {
            ForEach(weekdays, id: \.self) { d in
                let on = selection.wrappedValue.contains(d)
                Button {
                    if single {
                        selection.wrappedValue = [d]
                    } else {
                        if on { selection.wrappedValue.remove(d) } else { selection.wrappedValue.insert(d) }
                    }
                } label: {
                    Text(String(d.prefix(1)))
                        .font(AppFont.mono(12, weight: .bold))
                        .foregroundStyle(on ? T.ink : T.ink3)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(on ? T.accent : T.paperDeep)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // ── Mutations ────────────────────────────

    private func commitAvoidance() {
        let trimmed = newAvoidance.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !avoidances.contains(trimmed) else {
            newAvoidance = ""
            return
        }
        avoidances.append(trimmed)
        newAvoidance = ""
    }

    private func runTest() {
        apiTesting = true
        apiResult = nil
        Task {
            let result = await AnthropicVision.testKey(apiKey)
            await MainActor.run {
                apiTesting = false
                switch result {
                case .success: apiResult = .ok
                case .failure(let err): apiResult = .failure(err.errorDescription ?? "Unknown error")
                }
            }
        }
    }

    private func finish() {
        // Commit any unsubmitted avoidance + persist all step values.
        commitAvoidance()
        let weekdayOrder = weekdays
        let orderedQuickNights = weekdayOrder.filter { quickNights.contains($0) }

        state.rules.householdAdults = adults
        state.rules.householdKids = kids
        state.rules.weeknightMax = weeknightCap
        state.rules.shopDay = shopDay
        state.rules.quickNights = orderedQuickNights
        state.rules.avoidIngredients = avoidances
        if !apiKey.isEmpty { state.anthropicApiKey = apiKey }

        // Generate a fresh week respecting the new rules so the user lands on
        // a plan that's actually theirs, not Britt's seed. Locks aren't carried
        // over from the seed week — autoDraft picks meals for every day.
        let fresh: [DayPlan] = Today.labels.enumerated().map { idx, label in
            DayPlan(
                day: label,
                date: Today.dateLabel(for: idx),
                mealId: SeedData.week[idx].mealId,
                locked: false,
                slot: SeedData.week[idx].slot
            )
        }
        state.week = Planner.autoDraft(
            week: fresh,
            rules: state.rules,
            ratings: state.ratings,
            weekendDiscovery: true
        )

        state.hasCompletedOnboarding = true
    }
}
