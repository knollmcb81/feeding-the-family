import SwiftUI

enum AutoDraftRuleId: String, CaseIterable, Identifiable {
    case freshness, quickNights, avoidances, scoreWeighting, weekendDiscovery
    var id: String { rawValue }
}

struct AutoDraftConfig {
    var disabled: Set<AutoDraftRuleId>
    var meatDays: Int
    var quickNights: [String]
    var avoidances: [String]
}

struct AutoDraftSheet: View {
    let initialRules: Rules
    let onConfirm: (AutoDraftConfig) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var visibleSteps: Int = 0
    @State private var disabled: Set<AutoDraftRuleId> = []
    @State private var meatDays: Int
    @State private var quickNights: Set<String>
    @State private var avoidances: [String]
    @State private var newAvoidance: String = ""
    @FocusState private var addAvoidanceFocused: Bool

    private let weekdays = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]

    init(rules: Rules, onConfirm: @escaping (AutoDraftConfig) -> Void) {
        self.initialRules = rules
        self.onConfirm = onConfirm
        _meatDays = State(initialValue: rules.meatDays)
        _quickNights = State(initialValue: Set(rules.quickNights))
        _avoidances = State(initialValue: rules.avoidIngredients)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(T.rule)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ruleRow(idx: 0, id: .freshness, label: "Freshness window",
                            detail: "Fresh meat lasts \(meatDays) day\(meatDays == 1 ? "" : "s")") {
                        meatDaysPicker
                    }
                    ruleRow(idx: 1, id: .quickNights, label: "Quick nights",
                            detail: quickNightsDetail) {
                        weekdayChips
                    }
                    ruleRow(idx: 2, id: .avoidances, label: "Avoidances",
                            detail: avoidancesDetail) {
                        avoidancesEditor
                    }
                    ruleRow(idx: 3, id: .scoreWeighting, label: "Score weighting",
                            detail: "Favor meals the family rates highest", editor: { EmptyView() })
                    ruleRow(idx: 4, id: .weekendDiscovery, label: "Weekend discovery",
                            detail: "Try one new meal on Sat or Sun", editor: { EmptyView() })
                }
                .padding(.top, 6)
            }
            confirmButton
        }
        .background(T.paper)
        .onAppear { runReveal() }
    }

    private var quickNightsDetail: String {
        if quickNights.isEmpty { return "No quick nights" }
        let ordered = weekdays.filter { quickNights.contains($0) }
        return "\(ordered.joined(separator: ", ")) under 30 min"
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Drafting your week")
                    .font(AppFont.text(11, weight: .medium))
                    .kerning(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(T.ink3)
                Text("Auto-draft")
                    .font(AppFont.text(28, weight: .bold))
                    .kerning(-1)
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
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private func ruleRow<Editor: View>(
        idx: Int, id: AutoDraftRuleId, label: String, detail: String,
        @ViewBuilder editor: () -> Editor
    ) -> some View {
        if idx < visibleSteps {
            let isOff = disabled.contains(id)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Button {
                        if isOff { disabled.remove(id) } else { disabled.insert(id) }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(isOff ? T.paperDeep : T.ink)
                                .frame(width: 22, height: 22)
                            if !isOff {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(T.accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(label)
                            .font(AppFont.text(13, weight: .semibold))
                            .foregroundStyle(isOff ? T.ink3 : T.ink)
                            .strikethrough(isOff, color: T.ink3)
                        Text(detail)
                            .font(AppFont.text(11))
                            .foregroundStyle(T.ink3)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    Text("RULE \(idx + 1)")
                        .font(AppFont.mono(9, weight: .bold))
                        .kerning(0.6)
                        .foregroundStyle(T.ink3)
                }

                if !isOff {
                    editor()
                        .padding(.leading, 34)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
            .overlay(alignment: .top) {
                if idx > 0 {
                    Rectangle().fill(T.ruleSoft).frame(height: 1).padding(.horizontal, 22)
                }
            }
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .offset(y: 8)),
                removal: .opacity
            ))
        }
    }

    // ── Editors ──────────────────────────────────────

    private var meatDaysPicker: some View {
        HStack(spacing: 6) {
            ForEach([3, 4, 5, 6, 7], id: \.self) { n in
                Button { meatDays = n } label: {
                    Text("\(n)")
                        .font(AppFont.mono(12, weight: .bold))
                        .foregroundStyle(meatDays == n ? T.accent : T.ink2)
                        .frame(width: 30, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(meatDays == n ? T.ink : T.paperDeep)
                        )
                }
                .buttonStyle(.plain)
            }
            Text("days")
                .font(AppFont.text(11))
                .foregroundStyle(T.ink3)
                .padding(.leading, 2)
        }
    }

    private var weekdayChips: some View {
        HStack(spacing: 4) {
            ForEach(weekdays, id: \.self) { d in
                let on = quickNights.contains(d)
                Button {
                    if on { quickNights.remove(d) } else { quickNights.insert(d) }
                } label: {
                    Text(String(d.prefix(1)))
                        .font(AppFont.mono(11, weight: .bold))
                        .foregroundStyle(on ? T.ink : T.ink3)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(on ? T.accent : T.paperDeep)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var avoidancesDetail: String {
        avoidances.isEmpty ? "Nothing avoided" : "Skip meals with these ingredients"
    }

    private var avoidancesEditor: some View {
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
                    .onSubmit { commitNewAvoidance() }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(T.card)
                    .overlay(
                        Capsule().strokeBorder(T.rule, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                    )
            )
            .onTapGesture { addAvoidanceFocused = true }
        }
    }

    private func commitNewAvoidance() {
        let trimmed = newAvoidance.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !avoidances.contains(trimmed) else {
            newAvoidance = ""
            return
        }
        avoidances.append(trimmed)
        newAvoidance = ""
    }

    private var confirmButton: some View {
        let allRevealed = visibleSteps >= AutoDraftRuleId.allCases.count
        return Button {
            commitNewAvoidance()
            onConfirm(AutoDraftConfig(
                disabled: disabled,
                meatDays: meatDays,
                quickNights: weekdays.filter { quickNights.contains($0) },
                avoidances: avoidances
            ))
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                Text("Confirm draft")
                    .font(AppFont.text(15, weight: .semibold))
                    .kerning(-0.2)
            }
            .foregroundStyle(T.accentInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Capsule().fill(T.accent))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 22)
        .padding(.bottom, 22)
        .padding(.top, 6)
        .opacity(allRevealed ? 1 : 0.4)
        .disabled(!allRevealed)
    }

    private func runReveal() {
        visibleSteps = 0
        for i in 1...AutoDraftRuleId.allCases.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                withAnimation(.easeOut(duration: 0.18)) {
                    visibleSteps = i
                }
            }
        }
    }
}
