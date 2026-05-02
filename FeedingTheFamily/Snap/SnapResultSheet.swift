import SwiftUI

struct SnapResultSheet: View {
    let fixture: SnapFixture
    let week: [DayPlan]
    let onLog: (SnapEntry) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var portions: [UUID: PortionStep] = [:]
    @State private var skipped: Set<UUID> = []
    @State private var expandedItem: UUID? = nil
    @State private var mode: ResultMode = .home
    @State private var matchedItem: RestaurantMenuItem? = nil
    @State private var ateScale: AteScale = .all
    @State private var quickAddsOpen: Bool = false
    @State private var addedQuickAdds: Set<UUID> = []

    enum ResultMode: String, CaseIterable, Identifiable {
        case home, restaurant
        var id: String { rawValue }
        var label: String { self == .home ? "Home" : "Restaurant" }
    }

    enum AteScale: Double, CaseIterable, Identifiable {
        case half = 0.5, threeQ = 0.75, all = 1.0
        var id: String { label }
        var label: String {
            switch self {
            case .half:   return "Half"
            case .threeQ: return "¾"
            case .all:    return "All"
            }
        }
    }

    private var chains: [RestaurantChain] {
        RestaurantData.guesses[fixture.title] ?? []
    }

    /// Pre-scale totals (before ateScale) — sum of detected items respecting portions/skips,
    /// plus any quick-adds the user marked, or the matched restaurant item if Restaurant
    /// mode is active.
    private var rawTotals: (kcal: Int, protein: Double, carbs: Double, fat: Double) {
        if mode == .restaurant, let m = matchedItem {
            return (m.kcal, m.protein, m.carbs, m.fat)
        }
        var kcal = 0; var p = 0.0; var c = 0.0; var f = 0.0
        for item in fixture.items where !skipped.contains(item.id) {
            let mult = portions[item.id, default: .one].rawValue
            kcal += Int(Double(item.kcal) * mult)
            p += item.protein * mult
            c += item.carbs * mult
            f += item.fat * mult
        }
        for q in QuickAdds.items where addedQuickAdds.contains(q.id) {
            kcal += q.kcal
            p += q.protein
            c += q.carbs
            f += q.fat
        }
        return (kcal, p, c, f)
    }

    private var activeQuickAdds: [QuickAddItem] {
        QuickAdds.items.filter { addedQuickAdds.contains($0.id) }
    }

    /// Final totals after the user's "how much did you eat" scale.
    private var totals: (kcal: Int, protein: Int, carbs: Int, fat: Int) {
        let raw = rawTotals
        let s = ateScale.rawValue
        return (
            Int(Double(raw.kcal) * s),
            Int((raw.protein * s).rounded()),
            Int((raw.carbs * s).rounded()),
            Int((raw.fat * s).rounded())
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    macroCard
                    if !chains.isEmpty {
                        modeToggle
                    }
                    if mode == .home {
                        sectionLabel("DETECTED ITEMS")
                        VStack(spacing: 0) {
                            ForEach(fixture.items) { item in
                                itemRow(item)
                            }
                            ForEach(activeQuickAdds) { q in
                                addedQuickAddRow(q)
                            }
                        }
                        quickAddsSection
                    } else {
                        restaurantSection
                    }
                    ateScaleRow
                }
                .padding(.horizontal, 22)
                .padding(.top, 6)
                .padding(.bottom, 100)
            }
            actionBar
        }
        .background(T.paper)
    }

    // ── Header ──────────────────────────────

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    sourceTag
                    Text("\(fixture.confidence)% confident")
                        .font(AppFont.text(11, weight: .semibold))
                        .kerning(1.0)
                        .foregroundStyle(T.ink3)
                }
                Text(fixture.title)
                    .font(AppFont.text(26, weight: .bold))
                    .kerning(-0.8)
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
        .padding(.top, 14)
        .padding(.bottom, 14)
    }

    // ── Macro card ─────────────────────────

    private var macroCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(totals.kcal)")
                    .font(AppFont.text(28, weight: .bold))
                    .kerning(-0.7)
                    .foregroundStyle(T.ink)
                Text("kcal")
                    .font(AppFont.text(13))
                    .foregroundStyle(T.ink3)
                Spacer()
                macroChip(label: "P", value: totals.protein)
                macroChip(label: "C", value: totals.carbs)
                macroChip(label: "F", value: totals.fat)
            }
        }
        .padding(14)
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

    private func macroChip(label: String, value: Int) -> some View {
        VStack(alignment: .center, spacing: 1) {
            Text("\(value)g")
                .font(AppFont.mono(12, weight: .bold))
                .foregroundStyle(T.ink)
            Text(label)
                .font(AppFont.text(9, weight: .bold))
                .kerning(0.5)
                .foregroundStyle(T.ink3)
        }
        .frame(width: 36, height: 36)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(T.paperDeep)
        )
    }

    // ── Item row with portion picker ───────

    private func itemRow(_ item: SnapItem) -> some View {
        let isSkipped = skipped.contains(item.id)
        let isExpanded = expandedItem == item.id
        let portion = portions[item.id, default: .one]
        let mult = portion.rawValue
        let scaledKcal = Int(Double(item.kcal) * mult)

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                if expandedItem == item.id {
                    expandedItem = nil
                } else {
                    expandedItem = item.id
                }
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(AppFont.text(14, weight: .semibold))
                            .foregroundStyle(isSkipped ? T.ink3 : T.ink)
                            .strikethrough(isSkipped, color: T.ink3)
                            .multilineTextAlignment(.leading)
                        Text("\(item.qty) · \(scaledKcal) kcal\(portion != .one ? " · \(portion.label)" : "")")
                            .font(AppFont.mono(11))
                            .foregroundStyle(T.ink3)
                            .strikethrough(isSkipped, color: T.ink3)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(T.ink3)
                }
                .padding(.vertical, 11)
                .opacity(isSkipped ? 0.55 : 1)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 4) {
                        ForEach(PortionStep.allCases) { step in
                            Button { portions[item.id] = step } label: {
                                Text(step.label)
                                    .font(AppFont.mono(12, weight: .bold))
                                    .foregroundStyle(portion == step ? T.accent : T.ink2)
                                    .frame(maxWidth: .infinity, minHeight: 30)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(portion == step ? T.ink : T.paperDeep)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Button {
                        if isSkipped { skipped.remove(item.id) } else { skipped.insert(item.id) }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isSkipped ? "checkmark.circle.fill" : "minus.circle")
                                .font(.system(size: 13))
                            Text(isSkipped ? "Include" : "Skip this item")
                                .font(AppFont.text(12, weight: .semibold))
                        }
                        .foregroundStyle(isSkipped ? T.accent2 : T.ink3)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 11)
                .transition(.opacity.combined(with: .offset(y: -4)))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isExpanded)
        .overlay(alignment: .bottom) {
            Rectangle().fill(T.ruleSoft).frame(height: 1)
        }
    }

    // ── Action bar ─────────────────────────

    private var actionBar: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(week, id: \.id) { day in
                    Button("\(day.day) — \(Planner.meal(byId: day.mealId).title)") {
                        commit(assignedTo: day.mealId, asInspiration: false)
                    }
                }
                Divider()
                Button("Just log it (no meal)") { commit(assignedTo: nil, asInspiration: false) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Log to meal")
                        .font(AppFont.text(13, weight: .semibold))
                }
                .foregroundStyle(T.accentInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Capsule().fill(T.accent))
            }

            Button {
                commit(assignedTo: nil, asInspiration: true)
            } label: {
                Image(systemName: "bookmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(T.ink)
                    .frame(width: 44, height: 44)
                    .background(Circle().strokeBorder(T.rule, lineWidth: 1))
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

    private func commit(assignedTo: String?, asInspiration: Bool) {
        // Keep only items the user didn't skip, scaled by their portion choice.
        var activeItems: [SnapItem] = fixture.items.compactMap { item in
            if skipped.contains(item.id) { return nil }
            let mult = portions[item.id, default: .one].rawValue
            if mult == 1 { return item }
            return SnapItem(
                name: item.name,
                qty: "\(portions[item.id, default: .one].label) \(item.qty)",
                kcal: Int(Double(item.kcal) * mult),
                protein: item.protein * mult,
                carbs: item.carbs * mult,
                fat: item.fat * mult
            )
        }
        // Append any quick-adds the user folded in.
        for q in activeQuickAdds {
            activeItems.append(SnapItem(
                name: "+ \(q.name)",
                qty: q.qty,
                kcal: q.kcal,
                protein: q.protein,
                carbs: q.carbs,
                fat: q.fat
            ))
        }
        let entry = SnapEntry(
            timestamp: Date(),
            title: fixture.title,
            kcal: totals.kcal,
            protein: totals.protein,
            carbs: totals.carbs,
            fat: totals.fat,
            assignedToMealId: assignedTo,
            savedAsInspiration: asInspiration,
            items: activeItems,
            paletteIdx: Int.random(in: 0..<6)
        )
        onLog(entry)
        dismiss()
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(AppFont.text(10.5, weight: .bold))
            .kerning(1.2)
            .foregroundStyle(T.ink3)
    }

    @ViewBuilder
    private var sourceTag: some View {
        switch fixture.source {
        case .ai:
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .semibold))
                Text("CLAUDE VISION")
                    .font(AppFont.text(10, weight: .bold))
                    .kerning(1.2)
            }
            .foregroundStyle(T.accentInk)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(T.accent))
        case .demo:
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text("DEMO")
                    .font(AppFont.text(10, weight: .bold))
                    .kerning(1.2)
            }
            .foregroundStyle(T.warn)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(T.warn.opacity(0.15)))
        }
    }

    // ── Mode toggle (Home / Restaurant) ─────────────

    private var modeToggle: some View {
        HStack(spacing: 0) {
            ForEach(ResultMode.allCases) { m in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { mode = m }
                } label: {
                    Text(m.label)
                        .font(AppFont.text(13, weight: .semibold))
                        .foregroundStyle(mode == m ? T.paper : T.ink2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(mode == m ? T.ink : Color.clear)
                        )
                        .padding(2)
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(T.paperDeep)
        )
    }

    // ── Restaurant section ─────────────────────────

    private var restaurantSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("MATCH A MENU")
            if let matched = matchedItem {
                matchedCard(matched)
            }
            ForEach(chains) { chain in
                chainBlock(chain)
            }
        }
    }

    private func matchedCard(_ matched: RestaurantMenuItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 16))
                .foregroundStyle(T.accent2)
            VStack(alignment: .leading, spacing: 2) {
                Text("matched · macros locked in")
                    .font(AppFont.text(10.5, weight: .bold))
                    .kerning(0.5)
                    .foregroundStyle(T.accent2)
                Text(matched.name)
                    .font(AppFont.text(13, weight: .semibold))
                    .foregroundStyle(T.ink)
                Text("\(matched.qty) · \(matched.kcal) kcal · \(Int(matched.protein))g P")
                    .font(AppFont.mono(10.5))
                    .foregroundStyle(T.ink3)
            }
            Spacer(minLength: 8)
            Button { matchedItem = nil } label: {
                Text("Change")
                    .font(AppFont.text(11, weight: .semibold))
                    .foregroundStyle(T.ink2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().strokeBorder(T.rule, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(T.accent.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(T.accent2.opacity(0.4), lineWidth: 1)
                )
        )
    }

    private func chainBlock(_ chain: RestaurantChain) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(chain.name)
                .font(AppFont.text(13, weight: .bold))
                .foregroundStyle(T.ink)
            VStack(spacing: 0) {
                ForEach(chain.items) { item in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            matchedItem = item
                        }
                    } label: {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(AppFont.text(13, weight: .semibold))
                                    .foregroundStyle(matchedItem?.id == item.id ? T.accent2 : T.ink)
                                    .multilineTextAlignment(.leading)
                                Text("\(item.qty) · \(item.kcal) kcal · \(Int(item.protein))g P")
                                    .font(AppFont.mono(10.5))
                                    .foregroundStyle(T.ink3)
                            }
                            Spacer(minLength: 6)
                            if matchedItem?.id == item.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(T.accent2)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(T.ink3)
                            }
                        }
                        .padding(.vertical, 9)
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .bottom) {
                        if item.id != chain.items.last?.id {
                            Rectangle().fill(T.ruleSoft).frame(height: 1)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
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

    // ── Quick-adds ─────────────────────────────────

    private var quickAddsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { quickAddsOpen.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: quickAddsOpen ? "minus" : "plus")
                        .font(.system(size: 11, weight: .bold))
                    Text("Add what I cooked with")
                        .font(AppFont.text(13, weight: .semibold))
                    Spacer()
                    if !addedQuickAdds.isEmpty && !quickAddsOpen {
                        Text("\(addedQuickAdds.count)")
                            .font(AppFont.mono(11, weight: .bold))
                            .foregroundStyle(T.accentInk)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(T.accent))
                    }
                    Image(systemName: quickAddsOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(T.ink3)
                }
                .foregroundStyle(T.ink2)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(T.rule, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                )
            }
            .buttonStyle(.plain)

            if quickAddsOpen {
                FlowLayout(spacing: 8, rowSpacing: 8) {
                    ForEach(QuickAdds.items) { q in
                        quickAddChip(q)
                    }
                }
                .transition(.opacity.combined(with: .offset(y: -4)))
            }
        }
    }

    private func quickAddChip(_ q: QuickAddItem) -> some View {
        let on = addedQuickAdds.contains(q.id)
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if on { addedQuickAdds.remove(q.id) } else { addedQuickAdds.insert(q.id) }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: on ? "checkmark" : "plus")
                    .font(.system(size: 9, weight: .bold))
                Text(q.name)
                    .font(AppFont.text(12, weight: .semibold))
                Text("· \(q.kcal)")
                    .font(AppFont.mono(10))
                    .opacity(0.7)
            }
            .foregroundStyle(on ? T.accentInk : T.ink2)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(on ? T.accent : Color.clear)
                    .overlay(
                        Capsule().strokeBorder(on ? Color.clear : T.rule, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func addedQuickAddRow(_ q: QuickAddItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(T.accent2)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(q.name)
                    .font(AppFont.text(14, weight: .semibold))
                    .foregroundStyle(T.ink)
                Text("\(q.qty) · \(q.kcal) kcal · added")
                    .font(AppFont.mono(11))
                    .foregroundStyle(T.ink3)
            }
            Spacer(minLength: 0)
            Button {
                addedQuickAdds.remove(q.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(T.ink3)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) {
            Rectangle().fill(T.ruleSoft).frame(height: 1)
        }
    }

    // ── How much did you eat ───────────────────────

    private var ateScaleRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("HOW MUCH DID YOU EAT?")
            HStack(spacing: 0) {
                ForEach(AteScale.allCases) { s in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { ateScale = s }
                    } label: {
                        Text(s.label)
                            .font(AppFont.text(13, weight: .semibold))
                            .foregroundStyle(ateScale == s ? T.accent : T.ink2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(ateScale == s ? T.ink : Color.clear)
                            )
                            .padding(2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(T.paperDeep)
            )
        }
    }
}
