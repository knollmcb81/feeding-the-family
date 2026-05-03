import SwiftUI

struct ListScreen: View {
    @Environment(AppState.self) private var state
    @State private var adding: Bool = false
    @State private var newName: String = ""
    @State private var newQty: String = ""
    @State private var newAisle: Aisle = .produce
    @State private var editingStaples: Bool = false
    @FocusState private var nameFocused: Bool

    /// Plain-text representation of the list, grouped by aisle. Fed to ShareLink.
    private var shareText: String {
        var lines: [String] = []
        lines.append("Grocery list — \(shopDayHeader.replacingOccurrences(of: " · Shop day", with: ""))")
        lines.append("")
        for aisle in Aisle.allCases {
            guard let items = grouped[aisle], !items.isEmpty else { continue }
            lines.append("\(aisle.label.uppercased())")
            for item in items {
                let checkmark = state.checkedItems.contains(item.id) ? "✓" : "•"
                let qty = item.qty.joined(separator: " + ")
                let parts = qty.isEmpty ? item.name : "\(item.name) — \(qty)"
                lines.append("  \(checkmark) \(parts)")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    /// Days actually feeding the grocery list — based on selectedListDays.
    /// Pulls from current week, plus next week if a forward plan exists.
    /// Past days in the current week are excluded automatically: once a day
    /// has come and gone, you've already shopped (or skipped) for it, so its
    /// ingredients shouldn't keep cluttering the list.
    private var selectedDayPlans: [DayPlan] {
        var out: [DayPlan] = []
        for (idx, day) in state.week.enumerated() {
            if idx < state.todayIdx { continue }
            if state.selectedListDays.contains("0-\(day.day)") {
                out.append(day)
            }
        }
        if let fp = state.forwardPlannedWeek {
            for day in fp where state.selectedListDays.contains("1-\(day.day)") {
                out.append(day)
            }
        }
        return out
    }

    /// Total day chips that are still selectable (not past) — drives the
    /// "X of N" counter so it stays honest as the week ages.
    private var selectableDaysTotal: Int {
        let upcoming = max(0, 7 - state.todayIdx)
        return upcoming + (state.forwardPlannedWeek == nil ? 0 : 7)
    }

    /// Number of *currently selectable* days that are in the list.
    private var selectedDaysCount: Int {
        selectedDayPlans.count
    }

    private var grouped: [Aisle: [GroceryItem]] {
        var base = Planner.groceryFor(
            week: selectedDayPlans,
            pantryHave: state.rules.pantryHave,
            overrides: state.mealOverrides,
            custom: state.customMeals
        )
        if state.staplesOn {
            for s in state.staples {
                if base[s.aisle]?.contains(where: { $0.name == s.name }) == true { continue }
                base[s.aisle, default: []].append(s)
            }
        }
        for c in state.customItems {
            base[c.aisle, default: []].append(c)
        }
        // Drop anything the user explicitly skipped this trip.
        for a in base.keys {
            base[a]?.removeAll { state.skippedListItems.contains($0.id) }
            base[a]?.sort { $0.name < $1.name }
        }
        return base
    }

    private var totalItems: Int { grouped.values.reduce(0) { $0 + $1.count } }
    private var checkedCount: Int { state.checkedItems.count }

    /// Active suggestions = seeded + learned, minus dismissed and current staples.
    private var activeSuggestions: [LearnedSuggestion] {
        let stapleIds = Set(state.staples.map { "\($0.name)|\($0.aisle.rawValue)" })
        let combined = Suggestions.seeded
            + Suggestions.learned(from: state.customItemHistory, staples: state.staples)
        return combined.filter {
            !state.dismissedSuggestions.contains($0.id) && !stapleIds.contains($0.id)
        }
    }

    private var shopDayHeader: String {
        let shopIdx = Today.nextOccurrence(of: state.rules.shopDay)
        let label = shopIdx == Today.todayIdx ? "Today" : Today.labels[shopIdx]
        return "\(label) · \(Today.dateLabel(for: shopIdx)) · Shop day"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            dayPicker
                .padding(.horizontal, 22)
                .padding(.top, 10)
            controls
                .padding(.horizontal, 22)
                .padding(.top, 10)
                .sheet(isPresented: $editingStaples) {
                    EditStaplesSheet()
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                }
            if adding {
                addForm
                    .padding(.horizontal, 22)
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .offset(y: -6)))
            }
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    if totalItems == 0 {
                        emptyListState
                            .padding(.top, 24)
                    }
                    ForEach(Aisle.allCases, id: \.self) { aisle in
                        if let items = grouped[aisle], !items.isEmpty {
                            aisleSection(aisle, items: items)
                        }
                    }
                    if state.staplesOn && !activeSuggestions.isEmpty {
                        suggestionsSection
                            .padding(.top, 22)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(T.paper)
    }

    // ── Header ───────────────────────────────────────

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(shopDayHeader)
                        .font(AppFont.text(11, weight: .medium))
                        .foregroundStyle(T.ink3)
                    Text("Grocery list")
                        .font(AppFont.text(28, weight: .bold))
                        .kerning(-1)
                        .foregroundStyle(T.ink)
                }
                Spacer()
                ShareLink(item: shareText, subject: Text("Grocery list")) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(T.paper)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(T.ink))
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 4)

            // Progress card
            HStack {
                HStack(spacing: 0) {
                    Text("\(checkedCount)")
                        .font(AppFont.mono(12, weight: .bold))
                        .foregroundStyle(T.ink)
                    Text(" / \(totalItems) picked up")
                        .font(AppFont.text(12))
                        .foregroundStyle(T.ink3)
                }
                Spacer()
                ProgressBar(progress: totalItems > 0 ? Double(checkedCount) / Double(totalItems) : 0)
                    .frame(width: 120, height: 4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(T.paperDeep))
            .padding(.horizontal, 22)
            .padding(.top, 14)
        }
    }

    // ── Day picker (current + next week) ─────────────

    private var dayPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("DAYS INCLUDED")
                    .font(AppFont.text(10.5, weight: .bold))
                    .kerning(1.2)
                    .foregroundStyle(T.ink3)
                Spacer()
                Text("\(selectedDaysCount) of \(selectableDaysTotal)")
                    .font(AppFont.mono(10))
                    .foregroundStyle(T.ink3)
            }
            dayRow(weekOffset: 0, label: "this week")
            if state.forwardPlannedWeek != nil {
                dayRow(weekOffset: 1, label: "next week")
            }
        }
    }

    private func dayRow(weekOffset: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                ForEach(Array(Today.labels.enumerated()), id: \.element) { idx, d in
                    let key = "\(weekOffset)-\(d)"
                    let on = state.selectedListDays.contains(key)
                    let isPast = weekOffset == 0 && idx < state.todayIdx
                    Button {
                        if on { state.selectedListDays.remove(key) }
                        else { state.selectedListDays.insert(key) }
                    } label: {
                        Text(String(d.prefix(1)))
                            .font(AppFont.mono(11, weight: .bold))
                            .foregroundStyle(isPast ? T.ink3.opacity(0.5) : (on ? T.ink : T.ink3))
                            .frame(maxWidth: .infinity, minHeight: 30)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isPast ? T.paperDeep.opacity(0.5) : (on ? T.accent : T.paperDeep))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isPast)
                    .accessibilityLabel(isPast ? "\(d) (past)" : d)
                }
            }
            Text(label)
                .font(AppFont.text(10))
                .foregroundStyle(T.ink3)
                .padding(.leading, 2)
        }
    }

    // ── Controls (staples toggle + add) ──────────────

    private var controls: some View {
        HStack(spacing: 8) {
            Button {
                state.staplesOn.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: state.staplesOn ? "checkmark" : "circle")
                        .font(.system(size: 11, weight: .bold))
                    Text("Weekly staples")
                        .font(AppFont.text(12, weight: .semibold))
                    Text("\(state.staples.count)")
                        .font(AppFont.mono(10))
                        .opacity(0.7)
                }
                .foregroundStyle(state.staplesOn ? T.paper : T.ink2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(state.staplesOn ? T.ink : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(state.staplesOn ? T.ink : T.rule, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            if state.staplesOn {
                Button {
                    editingStaples = true
                } label: {
                    Text("Edit")
                        .font(AppFont.text(12, weight: .semibold))
                        .foregroundStyle(T.ink)
                        .padding(.vertical, 9)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(T.rule, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    adding.toggle()
                }
                if adding { nameFocused = true }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: adding ? "xmark" : "plus")
                        .font(.system(size: 11, weight: .bold))
                    Text(adding ? "Close" : "Add")
                        .font(AppFont.text(12, weight: .semibold))
                }
                .foregroundStyle(adding ? T.paper : T.ink)
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(adding ? T.ink : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(adding ? Color.clear : T.rule, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }

    // ── Add-item inline form ─────────────────────────

    private var addForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                TextField("e.g. avocados, coffee, ice cream…", text: $newName)
                    .font(AppFont.text(14))
                    .focused($nameFocused)
                    .submitLabel(.next)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(T.paper)
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(T.rule, lineWidth: 1))
                    )
                TextField("qty", text: $newQty)
                    .font(AppFont.text(14))
                    .submitLabel(.done)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .frame(width: 80)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(T.paper)
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(T.rule, lineWidth: 1))
                    )
                    .onSubmit { commitNew() }
            }

            FlowLayout(spacing: 6) {
                ForEach(Aisle.allCases, id: \.self) { a in
                    Button { newAisle = a } label: {
                        Text(a.label)
                            .font(AppFont.text(11, weight: .semibold))
                            .foregroundStyle(newAisle == a ? T.paper : T.ink2)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(newAisle == a ? T.ink : Color.clear)
                                    .overlay(
                                        Capsule().strokeBorder(newAisle == a ? Color.clear : T.rule, lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Spacer()
                Button {
                    cancelAdd()
                } label: {
                    Text("Cancel")
                        .font(AppFont.text(12, weight: .semibold))
                        .foregroundStyle(T.ink3)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.plain)
                Button {
                    commitNew()
                } label: {
                    Text("Add to list")
                        .font(AppFont.text(12, weight: .semibold))
                        .foregroundStyle(canCommit ? T.paper : T.ink3)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(canCommit ? T.ink : T.rule))
                }
                .buttonStyle(.plain)
                .disabled(!canCommit)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(T.card)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(T.ruleSoft, lineWidth: 1))
        )
    }

    private var canCommit: Bool {
        !newName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func commitNew() {
        let name = newName.trimmingCharacters(in: .whitespaces).lowercased()
        guard !name.isEmpty else { return }
        let qty = newQty.trimmingCharacters(in: .whitespaces)
        let item = GroceryItem(
            name: name,
            aisle: newAisle,
            qty: qty.isEmpty ? [] : [qty],
            meals: [],
            source: .custom
        )
        state.customItems.append(item)
        // Stamp the add into history so the suggestion engine can count weeks.
        state.customItemHistory.append(
            DatedCustomItem(name: name, qty: qty, aisle: newAisle, addedAt: Date())
        )
        newName = ""
        newQty = ""
        nameFocused = true   // stay open for fast multi-add
    }

    private func cancelAdd() {
        newName = ""
        newQty = ""
        withAnimation(.easeInOut(duration: 0.2)) { adding = false }
    }

    // ── Aisle section ────────────────────────────────

    private func aisleSection(_ aisle: Aisle, items: [GroceryItem]) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(aisle.label.uppercased())
                    .font(AppFont.text(12, weight: .bold))
                    .kerning(0.4)
                    .foregroundStyle(T.ink)
                Rectangle().fill(T.rule).frame(height: 1)
                Text("\(items.count)")
                    .font(AppFont.mono(10))
                    .foregroundStyle(T.ink3)
            }
            .padding(.leading, 4)
            .padding(.bottom, 6)
            .padding(.top, 18)

            ForEach(items) { item in
                ListRow(
                    item: item,
                    isChecked: state.checkedItems.contains(item.id),
                    onToggle: { toggle(item.id) },
                    onSkip: { state.skippedListItems.insert(item.id) },
                    onAlwaysHave: { state.rules.pantryHave.insert(item.name) },
                    onDeleteCustom: { state.customItems.removeAll { $0.id == item.id } },
                    onRemoveStaple: { state.staples.removeAll { $0.id == item.id } }
                )
            }
        }
    }

    private func toggle(_ id: String) {
        if state.checkedItems.contains(id) { state.checkedItems.remove(id) }
        else { state.checkedItems.insert(id) }
    }

    private var emptyListState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "cart")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(T.ink3)
            Text("Nothing in your list yet")
                .font(AppFont.text(15, weight: .semibold))
                .foregroundStyle(T.ink)
            Text("Plan some meals on the Plan tab and ingredients will roll up here. Or tap **+ Add** to add one-off items, and turn on **Weekly staples** for the things you always buy.")
                .font(AppFont.text(12))
                .foregroundStyle(T.ink2)
                .lineSpacing(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(T.rule, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
    }

    // ── Suggestions ─────────────────────────

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(T.warn)
                Text("WE NOTICED")
                    .font(AppFont.text(11, weight: .bold))
                    .kerning(1.2)
                    .foregroundStyle(T.warn)
            }
            .padding(.horizontal, 4)
            VStack(spacing: 8) {
                ForEach(activeSuggestions) { s in
                    suggestionCard(s)
                }
            }
        }
    }

    private func suggestionCard(_ s: LearnedSuggestion) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(s.name)
                        .font(AppFont.text(14, weight: .semibold))
                        .foregroundStyle(T.ink)
                    Text("· \(s.aisle.label.lowercased())")
                        .font(AppFont.text(11))
                        .foregroundStyle(T.ink3)
                }
                Text(s.reason)
                    .font(AppFont.text(11.5))
                    .foregroundStyle(T.ink2)
                Text(metaLine(for: s))
                    .font(AppFont.mono(10.5))
                    .foregroundStyle(T.ink3)
            }
            Spacer(minLength: 8)
            VStack(spacing: 8) {
                Button {
                    acceptSuggestion(s)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: actionIcon(for: s))
                            .font(.system(size: 10, weight: .bold))
                        Text(actionLabel(for: s))
                            .font(AppFont.text(11, weight: .semibold))
                    }
                    .foregroundStyle(T.accentInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(T.accent))
                }
                .buttonStyle(.plain)
                Button {
                    state.dismissedSuggestions.insert(s.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(T.ink3)
                        .padding(6)
                        .background(Circle().strokeBorder(T.rule, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(T.warn.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(T.warn.opacity(0.4), lineWidth: 1)
                )
        )
    }

    private func metaLine(for s: LearnedSuggestion) -> String {
        switch s.kind {
        case .promote:
            return "\(s.qty) · suggest as weekly staple"
        case .qtyBump(let current):
            return "\(current) → \(s.qty)"
        }
    }

    private func actionIcon(for s: LearnedSuggestion) -> String {
        switch s.kind {
        case .promote: return "plus"
        case .qtyBump: return "arrow.up"
        }
    }

    private func actionLabel(for s: LearnedSuggestion) -> String {
        switch s.kind {
        case .promote: return "Add"
        case .qtyBump: return "Bump"
        }
    }

    private func acceptSuggestion(_ s: LearnedSuggestion) {
        switch s.kind {
        case .promote:
            let item = GroceryItem(
                name: s.name,
                aisle: s.aisle,
                qty: [s.qty],
                meals: [],
                source: .staple
            )
            state.staples.append(item)
        case .qtyBump:
            // Find the matching staple and update its qty in place.
            guard let idx = state.staples.firstIndex(where: { $0.name == s.name && $0.aisle == s.aisle })
            else { return }
            let existing = state.staples[idx]
            state.staples[idx] = GroceryItem(
                name: existing.name,
                aisle: existing.aisle,
                qty: [s.qty],
                meals: existing.meals,
                source: existing.source
            )
            // Suppress this suggestion from coming back next render — id matches
            // the new staple's qty no longer differs.
        }
    }
}

private struct ProgressBar: View {
    let progress: Double  // 0...1
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(T.rule)
                Capsule()
                    .fill(T.accent)
                    .frame(width: geo.size.width * max(0, min(1, progress)))
                    .animation(.easeOut(duration: 0.3), value: progress)
            }
        }
    }
}

private struct ListRow: View {
    let item: GroceryItem
    let isChecked: Bool
    let onToggle: () -> Void
    let onSkip: () -> Void
    let onAlwaysHave: () -> Void
    let onDeleteCustom: () -> Void
    let onRemoveStaple: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button(action: onToggle) {
                HStack(alignment: .top, spacing: 12) {
                    checkbox
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(AppFont.text(15, weight: .medium))
                            .foregroundStyle(isChecked ? T.ink3 : T.ink)
                            .strikethrough(isChecked, color: T.ink3)
                        Text(metaLine)
                            .font(AppFont.mono(10.5))
                            .foregroundStyle(T.ink3)
                            .strikethrough(isChecked, color: T.ink3)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            rowMenu
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 6)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(T.ruleSoft)
                .frame(height: 1)
                .padding(.horizontal, 6)
        }
    }

    /// Per-row "•••" menu. Items vary by source — staples and custom items
    /// get a manage-this-list option, meal-derived items get the "this trip"
    /// vs "always" pair.
    private var rowMenu: some View {
        Menu {
            switch item.source {
            case .meal:
                Button {
                    onSkip()
                } label: {
                    Label("Skip for this trip", systemImage: "minus.circle")
                }
                Button {
                    onAlwaysHave()
                } label: {
                    Label("I always have this", systemImage: "checkmark.seal")
                }
            case .staple:
                Button {
                    onSkip()
                } label: {
                    Label("Skip for this trip", systemImage: "minus.circle")
                }
                Button(role: .destructive) {
                    onRemoveStaple()
                } label: {
                    Label("Remove from staples", systemImage: "trash")
                }
            case .custom:
                Button(role: .destructive) {
                    onDeleteCustom()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(T.ink3)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("More actions for \(item.name)")
    }

    private var checkbox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .stroke(isChecked ? T.accent : T.ink3, lineWidth: 1.5)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isChecked ? T.accent : Color.clear)
                )
                .frame(width: 18, height: 18)
            if isChecked {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.top, 1)
    }

    private var metaLine: String {
        switch item.source {
        case .staple: return "weekly staple · \(item.qty.joined(separator: " + "))"
        case .custom: return "added by you"
        case .meal:
            let mealsPart: String
            if item.meals.count == 1 { mealsPart = "for \(item.meals[0])" }
            else { mealsPart = "for \(item.meals.count) meals" }
            return "\(item.qty.joined(separator: " + ")) · \(mealsPart)"
        }
    }
}
