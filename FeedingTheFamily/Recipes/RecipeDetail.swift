import SwiftUI

struct RecipeDetail: View {
    let mealId: String
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    @State private var servings: Int = 4
    @State private var editing: Bool = false
    @State private var addingIngredient: Bool = false
    @State private var newIngName: String = ""
    @State private var newIngQty: String = ""
    @State private var newIngAisle: Aisle = .produce
    @State private var addingStep: Bool = false
    @State private var newStepText: String = ""
    @State private var editingStepIdx: Int? = nil
    @State private var stepDraft: String = ""

    private let baseServings = 4

    private var meal: Meal { Planner.activeMeal(id: mealId, overrides: state.mealOverrides, custom: state.customMeals) }
    private var protein: Protein { Planner.protein(for: meal) }
    private var scale: Double { Double(servings) / Double(baseServings) }
    private var hasOverride: Bool { state.mealOverrides[mealId] != nil }
    private var isCustomMeal: Bool { state.customMeals.contains(where: { $0.id == mealId }) }
    private var isUsedThisWeek: Bool { state.week.contains(where: { $0.mealId == mealId }) }

    var body: some View {
        VStack(spacing: 0) {
            header
            servingsRow
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if editing {
                        metaEditor
                    }
                    ingredientsSection
                    Spacer().frame(height: 22)
                    stepsSection
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 100)
            }
            actionBar
        }
        .background(T.paper)
    }

    // ── Footer actions ──────────────────────────────

    private var currentConfidence: Double {
        Learning.confidence(for: mealId, ratings: state.ratings)
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            addToWeekMenu
            rateMenu
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

    private var addToWeekMenu: some View {
        Menu {
            // Future days first (still upcoming this week), then any past day.
            let upcoming = state.week.enumerated().filter { $0.offset >= state.todayIdx }
            let past = state.week.enumerated().filter { $0.offset < state.todayIdx }
            ForEach(Array(upcoming), id: \.offset) { idx, day in
                Button(menuLabel(for: day)) { addToDay(idx) }
                    .disabled(day.mealId == mealId)
            }
            if !past.isEmpty {
                Divider()
                ForEach(Array(past), id: \.offset) { idx, day in
                    Button("\(day.day) (past)") { addToDay(idx) }
                        .disabled(day.mealId == mealId)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 13, weight: .semibold))
                Text("Add to this week")
                    .font(AppFont.text(13, weight: .semibold))
            }
            .foregroundStyle(T.accentInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Capsule().fill(T.accent))
        }
    }

    private func menuLabel(for day: DayPlan) -> String {
        let current = Planner.activeMeal(id: day.mealId, overrides: state.mealOverrides, custom: state.customMeals)
        if day.mealId == mealId { return "\(day.day) — already planned" }
        return "\(day.day) (replace \(current.title))"
    }

    private var rateMenu: some View {
        Menu {
            ForEach((1...5).reversed(), id: \.self) { stars in
                Button(String(repeating: "★", count: stars) + " · \(starsLabel(stars))") {
                    rateMeal(stars)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 11, weight: .semibold))
                if currentConfidence > 0 {
                    Text(String(format: "%.1f", currentConfidence))
                        .font(AppFont.mono(12, weight: .bold))
                }
            }
            .foregroundStyle(currentConfidence > 0 ? T.accent2 : T.ink)
            .frame(minWidth: 44, minHeight: 44)
            .padding(.horizontal, 12)
            .background(Circle().strokeBorder(T.rule, lineWidth: 1))
        }
    }

    private func starsLabel(_ n: Int) -> String {
        switch n {
        case 5: return "loved it"
        case 4: return "great"
        case 3: return "fine"
        case 2: return "meh"
        default: return "skip"
        }
    }

    private func addToDay(_ idx: Int) {
        var next = state.week
        next[idx].mealId = mealId
        next[idx].locked = true   // user explicitly set this, lock so auto-draft respects
        withAnimation(.easeInOut(duration: 0.25)) {
            state.week = next
        }
        dismiss()
    }

    private func rateMeal(_ stars: Int) {
        state.ratings[mealId, default: []].append(stars)
        // If this rating belongs to a past planned day for this meal, clear that prompt.
        for past in state.week.prefix(state.todayIdx) where past.mealId == mealId {
            state.unratedDays.remove(past.day)
        }
    }

    // ── Header ──────────────────────────────────────

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(proteinDotColor(protein))
                        .frame(width: 8, height: 8)
                    Text(protein.name.uppercased())
                        .font(AppFont.text(11, weight: .semibold))
                        .kerning(1.2)
                        .foregroundStyle(T.ink3)
                    Text("·").foregroundStyle(T.rule)
                    Text("\(meal.time)m")
                        .font(AppFont.mono(11, weight: .semibold))
                        .foregroundStyle(T.ink3)
                    if meal.kid {
                        Text("·").foregroundStyle(T.rule)
                        Text("kid-approved")
                            .font(AppFont.text(11, weight: .semibold))
                            .foregroundStyle(T.accent2)
                    }
                }
                if editing {
                    titleEditor
                } else {
                    Text(meal.title)
                        .font(AppFont.text(24, weight: .bold))
                        .kerning(-0.8)
                        .foregroundStyle(T.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            VStack(spacing: 6) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(T.ink2)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(T.paperDeep))
                }
                .buttonStyle(.plain)
                editToggle
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    private var titleEditor: some View {
        TextField("Title", text: Binding(
            get: { meal.title },
            set: { newTitle in
                var m = ensureOverride()
                m.title = newTitle
                state.mealOverrides[mealId] = m
            }
        ))
        .font(AppFont.text(24, weight: .bold))
        .kerning(-0.8)
        .foregroundStyle(T.ink)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(T.rule, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
        )
    }

    private var editToggle: some View {
        Button {
            if editing {
                if addingIngredient { commitNewIngredient() }
                if addingStep { commitNewStep() }
                if let idx = editingStepIdx { commitEditingStep(idx) }
            }
            editing.toggle()
            addingIngredient = false
            addingStep = false
            editingStepIdx = nil
        } label: {
            Text(editing ? "Done" : "Edit")
                .font(AppFont.text(11, weight: .semibold))
                .foregroundStyle(editing ? T.accent : T.ink2)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(editing ? T.ink : Color.clear)
                        .overlay(
                            Capsule().strokeBorder(editing ? Color.clear : T.rule, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    // ── Meta editor (time + kid + reset) ────────────

    private var metaEditor: some View {
        VStack(spacing: 10) {
            HStack {
                Text("COOK TIME")
                    .font(AppFont.text(10, weight: .bold))
                    .kerning(0.5)
                    .foregroundStyle(T.ink3)
                Spacer()
                Text("\(meal.time) min")
                    .font(AppFont.mono(13, weight: .semibold))
                    .foregroundStyle(T.ink)
            }
            Slider(
                value: Binding(
                    get: { Double(meal.time) },
                    set: { newVal in
                        var m = ensureOverride()
                        m.time = Int(newVal)
                        state.mealOverrides[mealId] = m
                    }
                ),
                in: 5...120,
                step: 5
            )
            .tint(T.ink)

            Toggle(isOn: Binding(
                get: { meal.kid },
                set: { newVal in
                    var m = ensureOverride()
                    m.kid = newVal
                    state.mealOverrides[mealId] = m
                }
            )) {
                Text("Kid-approved")
                    .font(AppFont.text(13, weight: .semibold))
                    .foregroundStyle(T.ink)
            }
            .tint(T.accent2)

            HStack(spacing: 8) {
                if isCustomMeal {
                    Button {
                        deleteCustomMeal()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 10, weight: .bold))
                            Text(isUsedThisWeek ? "Delete (in use)" : "Delete recipe")
                                .font(AppFont.text(11, weight: .semibold))
                        }
                        .foregroundStyle(isUsedThisWeek ? T.ink3 : T.warn)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().strokeBorder(isUsedThisWeek ? T.rule : T.warn.opacity(0.6), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(isUsedThisWeek)
                }
                Spacer()
                if hasOverride {
                    Button {
                        state.mealOverrides[mealId] = nil
                        addingIngredient = false
                        addingStep = false
                        editingStepIdx = nil
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 10, weight: .bold))
                            Text("Reset to original")
                                .font(AppFont.text(11, weight: .semibold))
                        }
                        .foregroundStyle(T.ink3)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().strokeBorder(T.rule, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(T.card)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(T.ruleSoft, lineWidth: 1))
        )
        .padding(.bottom, 18)
    }

    // ── Ingredients section ─────────────────────────

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Ingredients")
            ForEach(Array(meal.ings.enumerated()), id: \.offset) { idx, ing in
                ingredientRow(ing, idx: idx)
            }
            if editing {
                if addingIngredient {
                    addIngredientForm
                } else {
                    addRowButton(label: "Add ingredient") { addingIngredient = true }
                }
            }
        }
    }

    private func ingredientRow(_ ing: Ingredient, idx: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if editing {
                Button { removeIngredient(at: idx) } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(T.warn)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 2)
            }
            Text(ing.name)
                .font(AppFont.text(14))
                .foregroundStyle(T.ink)
            Spacer(minLength: 12)
            Text(scaleQty(ing.qty, scale: scale))
                .font(AppFont.mono(12))
                .foregroundStyle(T.ink2)
            if editing {
                Text(ing.aisle.label.lowercased())
                    .font(AppFont.text(10))
                    .foregroundStyle(T.ink3)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(T.paperDeep))
            }
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(T.ruleSoft).frame(height: 1)
        }
    }

    private var addIngredientForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            inputField(placeholder: "e.g. avocado", text: $newIngName)
            inputField(placeholder: "qty (e.g. 2 ct, 1 lb)", text: $newIngQty)
                .onSubmit { commitNewIngredient() }
            HStack(spacing: 6) {
                ForEach(Aisle.allCases, id: \.self) { a in
                    aisleChip(a, selected: newIngAisle == a) { newIngAisle = a }
                }
            }
            HStack {
                cancelBtn { addingIngredient = false; newIngName = ""; newIngQty = "" }
                Spacer()
                primaryBtn(label: "Add", enabled: !newIngName.trimmingCharacters(in: .whitespaces).isEmpty) {
                    commitNewIngredient()
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(T.card)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(T.ruleSoft, lineWidth: 1))
        )
        .padding(.top, 8)
    }

    // ── Steps section ───────────────────────────────

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Method")
            ForEach(Array(meal.steps.enumerated()), id: \.offset) { idx, step in
                stepRow(idx: idx, step: step, isLast: idx == meal.steps.count - 1)
            }
            if editing {
                if addingStep {
                    addStepForm
                } else {
                    addRowButton(label: "Add step") { addingStep = true }
                }
            }
        }
    }

    private func stepRow(idx: Int, step: String, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(idx + 1)")
                .font(AppFont.mono(11, weight: .bold))
                .foregroundStyle(T.paper)
                .frame(width: 22, height: 22)
                .background(Circle().fill(T.ink))
                .padding(.top, 1)

            if editing && editingStepIdx == idx {
                TextField("Step", text: $stepDraft, axis: .vertical)
                    .font(AppFont.text(14.5))
                    .lineLimit(1...8)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(T.rule, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                    )
                Button {
                    commitEditingStep(idx)
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(T.accent2)
                }
                .buttonStyle(.plain)
            } else {
                Text(step)
                    .font(AppFont.text(14.5))
                    .foregroundStyle(T.ink)
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard editing else { return }
                        editingStepIdx = idx
                        stepDraft = step
                    }
                if editing {
                    Button { removeStep(at: idx) } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(T.warn)
                    }
                    .buttonStyle(.plain)
                }
            }
            if !editing { Spacer(minLength: 0) }
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(T.ruleSoft).frame(height: 1)
            }
        }
    }

    private var addStepForm: some View {
        VStack(spacing: 10) {
            TextField("e.g. Brown the beef and drain.", text: $newStepText, axis: .vertical)
                .font(AppFont.text(14))
                .lineLimit(1...8)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(T.paper)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(T.rule, lineWidth: 1))
                )
            HStack {
                cancelBtn { addingStep = false; newStepText = "" }
                Spacer()
                primaryBtn(label: "Add step", enabled: !newStepText.trimmingCharacters(in: .whitespaces).isEmpty) {
                    commitNewStep()
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(T.card)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(T.ruleSoft, lineWidth: 1))
        )
        .padding(.top, 8)
    }

    // ── Servings ───────────────────────────────────

    private var servingsRow: some View {
        HStack {
            Text("Servings")
                .font(AppFont.text(12, weight: .semibold))
                .foregroundStyle(T.ink2)
            Spacer()
            HStack(spacing: 6) {
                Button { if servings > 1 { servings -= 1 } } label: { miniBtnLabel("−") }
                    .buttonStyle(.plain)
                Text("\(servings)")
                    .font(AppFont.mono(14, weight: .semibold))
                    .frame(minWidth: 22)
                Button { servings += 1 } label: { miniBtnLabel("+") }
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(T.paperDeep))
        .padding(.horizontal, 22)
    }

    // ── Small reusable bits ────────────────────────

    private func miniBtnLabel(_ glyph: String) -> some View {
        Text(glyph)
            .font(AppFont.text(15, weight: .semibold))
            .foregroundStyle(T.ink)
            .frame(width: 28, height: 28)
            .background(RoundedRectangle(cornerRadius: 6).fill(T.card))
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(AppFont.text(11, weight: .bold))
            .kerning(0.5)
            .textCase(.uppercase)
            .foregroundStyle(T.ink3)
            .padding(.bottom, 8)
    }

    private func addRowButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                Text(label)
                    .font(AppFont.text(13, weight: .semibold))
            }
            .foregroundStyle(T.ink2)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(T.rule, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    private func inputField(placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(AppFont.text(14))
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(T.paper)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(T.rule, lineWidth: 1))
            )
            .submitLabel(.next)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
    }

    private func aisleChip(_ a: Aisle, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(a.label)
                .font(AppFont.text(11, weight: .semibold))
                .foregroundStyle(selected ? T.paper : T.ink2)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(selected ? T.ink : Color.clear)
                        .overlay(
                            Capsule().strokeBorder(selected ? Color.clear : T.rule, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func cancelBtn(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Cancel")
                .font(AppFont.text(12, weight: .semibold))
                .foregroundStyle(T.ink3)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
    }

    private func primaryBtn(label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(AppFont.text(12, weight: .semibold))
                .foregroundStyle(enabled ? T.paper : T.ink3)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(enabled ? T.ink : T.rule))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func proteinDotColor(_ p: Protein) -> Color {
        switch p.perish {
        case .fresh:  return T.proteinFresh
        case .frozen: return T.proteinFrozen
        case .pantry: return T.proteinPantry
        }
    }

    // ── Mutations ──────────────────────────────────

    /// Returns the current customized meal, copying from the active meal
    /// (override → custom → seed) on first edit. Bug fix: custom meals were
    /// previously falling back to the first seed meal because we only checked seed.
    private func ensureOverride() -> Meal {
        state.mealOverrides[mealId]
            ?? Planner.activeMeal(id: mealId, overrides: [:], custom: state.customMeals)
    }

    private func commitNewIngredient() {
        let name = newIngName.trimmingCharacters(in: .whitespaces).lowercased()
        guard !name.isEmpty else { addingIngredient = false; return }
        var m = ensureOverride()
        m.ings.append(Ingredient(name: name, qty: newIngQty.trimmingCharacters(in: .whitespaces), aisle: newIngAisle))
        state.mealOverrides[mealId] = m
        newIngName = ""; newIngQty = ""
        addingIngredient = false
    }

    private func removeIngredient(at idx: Int) {
        var m = ensureOverride()
        guard idx < m.ings.count else { return }
        m.ings.remove(at: idx)
        state.mealOverrides[mealId] = m
    }

    private func commitNewStep() {
        let text = newStepText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { addingStep = false; return }
        var m = ensureOverride()
        m.steps.append(text)
        state.mealOverrides[mealId] = m
        newStepText = ""
        addingStep = false
    }

    private func removeStep(at idx: Int) {
        var m = ensureOverride()
        guard idx < m.steps.count else { return }
        m.steps.remove(at: idx)
        state.mealOverrides[mealId] = m
    }

    private func deleteCustomMeal() {
        guard !isUsedThisWeek else { return }
        state.customMeals.removeAll { $0.id == mealId }
        state.mealOverrides[mealId] = nil
        dismiss()
    }

    private func commitEditingStep(_ idx: Int) {
        let text = stepDraft.trimmingCharacters(in: .whitespaces)
        var m = ensureOverride()
        guard idx < m.steps.count else { editingStepIdx = nil; return }
        if text.isEmpty {
            m.steps.remove(at: idx)
        } else {
            m.steps[idx] = text
        }
        state.mealOverrides[mealId] = m
        editingStepIdx = nil
    }
}

/// Scales a quantity string like "1.5 lb", "1/2 cup", "12 ct" by a factor.
/// Keeps non-numeric quantities ("to taste") unchanged.
func scaleQty(_ qty: String, scale: Double) -> String {
    if scale == 1 { return qty }
    let trimmed = qty.trimmingCharacters(in: .whitespaces)
    let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
    guard let numStr = parts.first.map(String.init) else { return qty }
    let rest = parts.count > 1 ? String(parts[1]) : ""

    let num: Double
    if numStr.contains("/") {
        let frac = numStr.split(separator: "/").compactMap { Double($0) }
        guard frac.count == 2, frac[1] != 0 else { return qty }
        num = frac[0] / frac[1]
    } else if let n = Double(numStr) {
        num = n
    } else {
        return qty
    }

    let scaled = num * scale
    let rounded = (scaled * 4).rounded() / 4
    let formatted: String
    if rounded == rounded.rounded() {
        formatted = String(Int(rounded))
    } else {
        formatted = String(format: "%g", rounded)
    }
    return rest.isEmpty ? formatted : "\(formatted) \(rest)"
}
