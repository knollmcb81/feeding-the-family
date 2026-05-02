import SwiftUI

struct SettingsSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    @State private var testing: Bool = false
    @State private var testResult: TestResult? = nil

    enum TestResult: Equatable {
        case success
        case failure(String)
    }

    var body: some View {
        @Bindable var bound = state
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    section("FAMILY") {
                        stepperRow(
                            label: "Adults",
                            value: $bound.rules.householdAdults,
                            range: 1...6
                        )
                        stepperRow(
                            label: "Kids",
                            value: $bound.rules.householdKids,
                            range: 0...8
                        )
                    }

                    section("WEEKNIGHT COOKING") {
                        sliderRow(
                            label: "Max minutes",
                            value: $bound.rules.weeknightMax,
                            range: 15...90,
                            step: 5,
                            unit: "min"
                        )
                        infoRow(
                            label: "Quick-night cap",
                            value: "30 min on \(state.rules.quickNights.joined(separator: ", "))"
                        )
                    }

                    section("FRESHNESS") {
                        sliderRow(
                            label: "Fresh meat lasts",
                            value: $bound.rules.meatDays,
                            range: 2...7,
                            step: 1,
                            unit: " days"
                        )
                        bigShopDayRow
                        topUpDayRow
                    }

                    section("REMINDERS") {
                        nightlyReminderRow
                    }

                    section("DAILY NUTRITION GOALS") {
                        sliderRow(
                            label: "Calories",
                            value: $bound.nutritionGoal.kcal,
                            range: 1200...3500,
                            step: 50,
                            unit: " kcal"
                        )
                        sliderRow(
                            label: "Protein",
                            value: $bound.nutritionGoal.protein,
                            range: 60...250,
                            step: 5,
                            unit: "g"
                        )
                        sliderRow(
                            label: "Carbs",
                            value: $bound.nutritionGoal.carbs,
                            range: 100...400,
                            step: 10,
                            unit: "g"
                        )
                        sliderRow(
                            label: "Fat",
                            value: $bound.nutritionGoal.fat,
                            range: 30...150,
                            step: 5,
                            unit: "g"
                        )
                    }

                    section("AI VISION") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Anthropic API key")
                                .font(AppFont.text(13, weight: .semibold))
                                .foregroundStyle(T.ink)
                            SecureField("sk-ant-…", text: Binding(
                                get: { state.anthropicApiKey },
                                set: { state.setApiKey($0) }
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
                            // Always-visible status so the user can see what the field has.
                            keyStatusLine
                            // Optional backend proxy.
                            backendFields
                            // Connection test button.
                            HStack(spacing: 8) {
                                Button {
                                    runTest()
                                } label: {
                                    HStack(spacing: 6) {
                                        if testing {
                                            ProgressView().controlSize(.small).tint(T.ink)
                                        } else {
                                            Image(systemName: "bolt.fill")
                                                .font(.system(size: 11, weight: .semibold))
                                        }
                                        Text(testing ? "Testing…" : "Test connection")
                                            .font(AppFont.text(12, weight: .semibold))
                                    }
                                    .foregroundStyle(T.ink)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(Capsule().strokeBorder(T.ink, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .disabled(testing || state.anthropicApiKey.isEmpty)
                                if let result = testResult {
                                    testResultLabel(result)
                                }
                            }
                            .padding(.top, 6)
                            Text("With a key set, Snap photos go to Claude Vision for real food detection. Empty falls back to demo fixtures.")
                                .font(AppFont.text(11))
                                .foregroundStyle(T.ink3)
                                .lineSpacing(2)
                            if state.anthropicApiKey.isEmpty,
                               let url = URL(string: "https://console.anthropic.com/settings/keys") {
                                Link(destination: url) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.up.right.square")
                                            .font(.system(size: 10, weight: .semibold))
                                        Text("Get one at console.anthropic.com")
                                            .font(AppFont.text(11, weight: .semibold))
                                    }
                                    .foregroundStyle(T.ink)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Capsule().strokeBorder(T.ink, lineWidth: 1))
                                }
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(T.ruleSoft).frame(height: 1).padding(.horizontal, 22)
                        }
                    }

                    section("AVOIDANCES") {
                        FlowLayout(spacing: 6) {
                            ForEach(state.rules.avoidIngredients, id: \.self) { word in
                                Button {
                                    state.rules.avoidIngredients.removeAll { $0 == word }
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
                        }
                        .padding(.horizontal, 22)
                        .padding(.bottom, 12)
                        Text("Edit individual ingredients here, or quickly toggle the rule from Auto-draft.")
                            .font(AppFont.text(11))
                            .foregroundStyle(T.ink3)
                            .padding(.horizontal, 22)
                            .padding(.bottom, 18)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            .background(T.paper)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(AppFont.text(14, weight: .semibold))
                        .foregroundStyle(T.ink)
                }
            }
        }
    }

    @ViewBuilder
    private var backendFields: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("OR USE A BACKEND")
                .font(AppFont.text(10, weight: .bold))
                .kerning(1.2)
                .foregroundStyle(T.ink3)
                .padding(.top, 6)
            TextField("https://your-proxy.example.com", text: Binding(
                get: { state.backendBaseURL },
                set: { state.backendBaseURL = $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            ))
            .font(AppFont.mono(11))
            .foregroundStyle(T.ink)
            .tint(T.ink)
            .keyboardType(.URL)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(T.paperDeep)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(T.rule, lineWidth: 1))
            )
            SecureField("Bearer token", text: Binding(
                get: { state.backendAuthToken },
                set: { state.backendAuthToken = $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            ))
            .font(AppFont.mono(11))
            .foregroundStyle(T.ink)
            .tint(T.ink)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(T.paperDeep)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(T.rule, lineWidth: 1))
            )
            Text("When set, all Claude calls route through your proxy with the bearer token. The proxy holds the real Anthropic key. See backend/ in the repo for a Vercel-ready reference.")
                .font(AppFont.text(10.5))
                .foregroundStyle(T.ink3)
                .lineSpacing(2)
        }
    }

    private var nightlyReminderRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: Binding(
                get: { state.nightlyReminderEnabled },
                set: { newValue in
                    if newValue {
                        Task {
                            let granted = await Notifications.requestPermission()
                            await MainActor.run {
                                if granted {
                                    state.nightlyReminderEnabled = true
                                    Notifications.scheduleNightlyRating()
                                } else {
                                    // User denied — keep toggle off, send them to Settings.
                                    state.nightlyReminderEnabled = false
                                }
                            }
                        }
                    } else {
                        state.nightlyReminderEnabled = false
                        Notifications.cancelNightlyRating()
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nightly rating reminder")
                        .font(AppFont.text(14))
                        .foregroundStyle(T.ink)
                    Text("8 PM daily — \"How was dinner?\"")
                        .font(AppFont.text(11))
                        .foregroundStyle(T.ink3)
                }
            }
            .tint(T.accent2)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(T.ruleSoft).frame(height: 1).padding(.horizontal, 22)
        }
    }

    private var bigShopDayRow: some View {
        let weekdays = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Big shop day")
                    .font(AppFont.text(14))
                    .foregroundStyle(T.ink)
                Spacer()
                Text(state.rules.shopDay)
                    .font(AppFont.mono(13, weight: .semibold))
                    .foregroundStyle(T.ink)
            }
            HStack(spacing: 4) {
                ForEach(weekdays, id: \.self) { d in
                    Button {
                        state.rules.shopDay = d
                    } label: {
                        Text(String(d.prefix(1)))
                            .font(AppFont.mono(11, weight: .bold))
                            .foregroundStyle(state.rules.shopDay == d ? T.ink : T.ink3)
                            .frame(maxWidth: .infinity, minHeight: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(state.rules.shopDay == d ? T.accent : T.paperDeep)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("When the freshness clock starts. Set this to whatever day you actually did the big shop — your week-to-week rhythm can shift.")
                .font(AppFont.text(11))
                .foregroundStyle(T.ink3)
                .lineSpacing(2)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(T.ruleSoft).frame(height: 1).padding(.horizontal, 22)
        }
    }

    private var topUpDayRow: some View {
        let weekdays = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Mid-week top-up")
                    .font(AppFont.text(14))
                    .foregroundStyle(T.ink)
                Spacer()
                Text(state.rules.topUpDay ?? "None")
                    .font(AppFont.mono(13, weight: .semibold))
                    .foregroundStyle(T.ink)
            }
            HStack(spacing: 4) {
                Button {
                    state.rules.topUpDay = nil
                } label: {
                    Text("None")
                        .font(AppFont.mono(11, weight: .bold))
                        .foregroundStyle(state.rules.topUpDay == nil ? T.ink : T.ink3)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(state.rules.topUpDay == nil ? T.accent : T.paperDeep)
                        )
                }
                .buttonStyle(.plain)
                ForEach(weekdays, id: \.self) { d in
                    Button {
                        state.rules.topUpDay = (state.rules.topUpDay == d) ? nil : d
                    } label: {
                        Text(String(d.prefix(1)))
                            .font(AppFont.mono(11, weight: .bold))
                            .foregroundStyle(state.rules.topUpDay == d ? T.ink : T.ink3)
                            .frame(maxWidth: .infinity, minHeight: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(state.rules.topUpDay == d ? T.accent : T.paperDeep)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("Mark a mid-week shop day so the freshness rule knows you'll restock fruit, milk, and meat. Late-week meals stop flagging once it's set.")
                .font(AppFont.text(11))
                .foregroundStyle(T.ink3)
                .lineSpacing(2)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(T.ruleSoft).frame(height: 1).padding(.horizontal, 22)
        }
    }

    @ViewBuilder
    private var keyStatusLine: some View {
        if state.anthropicApiKey.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: "circle")
                    .font(.system(size: 10))
                    .foregroundStyle(T.ink3)
                Text("No key entered")
                    .font(AppFont.text(10.5))
                    .foregroundStyle(T.ink3)
            }
        } else {
            let goodPrefix = state.anthropicApiKey.hasPrefix("sk-ant-")
            HStack(spacing: 4) {
                Image(systemName: goodPrefix ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(goodPrefix ? T.accent2 : T.warn)
                Text(goodPrefix
                     ? "Key format looks right · \(state.anthropicApiKey.count) chars"
                     : "Key should start with sk-ant-")
                    .font(AppFont.text(10.5))
                    .foregroundStyle(goodPrefix ? T.accent2 : T.warn)
            }
        }
    }

    @ViewBuilder
    private func testResultLabel(_ result: TestResult) -> some View {
        switch result {
        case .success:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(T.accent2)
                Text("Connected")
                    .font(AppFont.text(11, weight: .semibold))
                    .foregroundStyle(T.accent2)
            }
        case .failure(let msg):
            Text(msg)
                .font(AppFont.text(10.5))
                .foregroundStyle(T.warn)
                .lineLimit(3)
        }
    }

    private func runTest() {
        testing = true
        testResult = nil
        Task {
            let result = await AnthropicVision.testKey(
                state.anthropicApiKey,
                backendBaseURL: state.backendBaseURL,
                backendAuthToken: state.backendAuthToken
            )
            await MainActor.run {
                testing = false
                switch result {
                case .success:
                    testResult = .success
                case .failure(let err):
                    testResult = .failure(err.errorDescription ?? "Unknown error")
                }
            }
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(AppFont.text(10.5, weight: .bold))
                .kerning(1.2)
                .foregroundStyle(T.ink3)
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 8)
            content()
        }
    }

    private func stepperRow(label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(label)
                .font(AppFont.text(14))
                .foregroundStyle(T.ink)
            Spacer()
            HStack(spacing: 6) {
                Button {
                    if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 }
                } label: {
                    miniBtnLabel("−")
                }
                .buttonStyle(.plain)
                Text("\(value.wrappedValue)")
                    .font(AppFont.mono(14, weight: .semibold))
                    .frame(minWidth: 22)
                Button {
                    if value.wrappedValue < range.upperBound { value.wrappedValue += 1 }
                } label: {
                    miniBtnLabel("+")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(T.ruleSoft).frame(height: 1).padding(.horizontal, 22)
        }
    }

    private func sliderRow(label: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(AppFont.text(14))
                    .foregroundStyle(T.ink)
                Spacer()
                Text("\(value.wrappedValue)\(unit)")
                    .font(AppFont.mono(13, weight: .semibold))
                    .foregroundStyle(T.ink)
            }
            Slider(
                value: Binding(
                    get: { Double(value.wrappedValue) },
                    set: { value.wrappedValue = Int($0) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: Double(step)
            )
            .tint(T.ink)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(T.ruleSoft).frame(height: 1).padding(.horizontal, 22)
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(AppFont.text(14))
                .foregroundStyle(T.ink2)
            Spacer()
            Text(value)
                .font(AppFont.mono(11))
                .foregroundStyle(T.ink3)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(T.ruleSoft).frame(height: 1).padding(.horizontal, 22)
        }
    }

    private func miniBtnLabel(_ glyph: String) -> some View {
        Text(glyph)
            .font(AppFont.text(15, weight: .semibold))
            .foregroundStyle(T.ink)
            .frame(width: 28, height: 28)
            .background(RoundedRectangle(cornerRadius: 6).fill(T.paperDeep))
    }
}
