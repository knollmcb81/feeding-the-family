import SwiftUI

struct InspirationDetail: View {
    let entry: SnapEntry
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    @State private var generating: Bool = false
    @State private var generatedMealId: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    InspirationGradient(seed: entry.paletteIdx)
                        .frame(height: 200)
                        .overlay(alignment: .topTrailing) {
                            Button { dismiss() } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(T.ink2)
                                    .frame(width: 34, height: 34)
                                    .background(Circle().fill(T.paper))
                            }
                            .buttonStyle(.plain)
                            .padding(14)
                        }

                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Saved \(timeAgo(entry.timestamp))")
                                .font(AppFont.text(11, weight: .medium))
                                .foregroundStyle(T.ink3)
                            Text(entry.title)
                                .font(AppFont.text(26, weight: .bold))
                                .kerning(-0.8)
                                .foregroundStyle(T.ink)
                        }

                        macroCard

                        if !entry.items.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("DETECTED ITEMS")
                                    .font(AppFont.text(10.5, weight: .bold))
                                    .kerning(1.2)
                                    .foregroundStyle(T.ink3)
                                    .padding(.bottom, 8)
                                ForEach(entry.items) { item in
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(item.name)
                                            .font(AppFont.text(14))
                                            .foregroundStyle(T.ink)
                                        Spacer(minLength: 12)
                                        Text(item.qty)
                                            .font(AppFont.mono(11))
                                            .foregroundStyle(T.ink2)
                                    }
                                    .padding(.vertical, 8)
                                    .overlay(alignment: .bottom) {
                                        Rectangle().fill(T.ruleSoft).frame(height: 1)
                                    }
                                }
                            }
                        }

                        if let mealId = generatedMealId {
                            generatedRecipeCard(mealId: mealId)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                    .padding(.bottom, 100)
                }
            }
            actionBar
        }
        .background(T.paper)
        .ignoresSafeArea(edges: .top)
    }

    private var macroCard: some View {
        HStack(spacing: 6) {
            macroChip(label: "kcal", value: "\(entry.kcal)")
            macroChip(label: "P", value: "\(entry.protein)g")
            macroChip(label: "C", value: "\(entry.carbs)g")
            macroChip(label: "F", value: "\(entry.fat)g")
        }
    }

    private func macroChip(label: String, value: String) -> some View {
        VStack(alignment: .center, spacing: 2) {
            Text(value)
                .font(AppFont.mono(13, weight: .bold))
                .foregroundStyle(T.ink)
            Text(label)
                .font(AppFont.text(9, weight: .bold))
                .kerning(0.5)
                .foregroundStyle(T.ink3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(T.paperDeep)
        )
    }

    private func generatedRecipeCard(mealId: String) -> some View {
        let meal = Planner.activeMeal(id: mealId, overrides: state.mealOverrides, custom: state.customMeals)
        let usedClaude = !state.anthropicApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(T.accent2)
                Text(usedClaude ? "RECIPE WRITTEN BY CLAUDE" : "RECIPE GENERATED")
                    .font(AppFont.text(10.5, weight: .bold))
                    .kerning(1.2)
                    .foregroundStyle(T.accent2)
            }
            Text(meal.title)
                .font(AppFont.text(15, weight: .semibold))
                .foregroundStyle(T.ink)
            Text("\(meal.time)m · \(meal.ings.count) ingredients · \(meal.steps.count) steps")
                .font(AppFont.mono(11))
                .foregroundStyle(T.ink3)
            Text("Now in your Recipes tab — tap there to view, edit, or add to a week.")
                .font(AppFont.text(12))
                .foregroundStyle(T.ink2)
                .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(T.accent.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(T.accent2.opacity(0.4), lineWidth: 1)
                )
        )
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button {
                generateRecipe()
            } label: {
                HStack(spacing: 8) {
                    if generating {
                        ProgressView()
                            .controlSize(.small)
                            .tint(T.accentInk)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    Text(generating ? "Generating…"
                         : (generatedMealId != nil ? "Regenerate" : "Generate recipe"))
                        .font(AppFont.text(13, weight: .semibold))
                }
                .foregroundStyle(T.accentInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Capsule().fill(T.accent))
            }
            .buttonStyle(.plain)
            .disabled(generating)

            if let mealId = generatedMealId {
                addToWeekMenu(mealId: mealId)
            }
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

    private func addToWeekMenu(mealId: String) -> some View {
        Menu {
            let upcoming = state.week.enumerated().filter { $0.offset >= state.todayIdx }
            ForEach(Array(upcoming), id: \.offset) { idx, day in
                let current = Planner.activeMeal(id: day.mealId, overrides: state.mealOverrides, custom: state.customMeals)
                Button("\(day.day) (replace \(current.title))") {
                    addToDay(idx, mealId: mealId)
                }
                .disabled(day.mealId == mealId)
            }
        } label: {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(T.ink)
                .frame(width: 44, height: 44)
                .background(Circle().strokeBorder(T.rule, lineWidth: 1))
        }
    }

    private func addToDay(_ idx: Int, mealId: String) {
        var next = state.week
        next[idx].mealId = mealId
        next[idx].locked = true
        withAnimation(.easeInOut(duration: 0.25)) {
            state.week = next
        }
        dismiss()
    }

    /// Build a real recipe from the inspiration. Calls Claude when an API key
    /// is set; otherwise falls back to local deterministic synthesis so the
    /// flow always produces something.
    private func generateRecipe() {
        generating = true
        let key = state.anthropicApiKey
        let backendURL = state.backendBaseURL
        let backendToken = state.backendAuthToken
        let usingBackend = ClaudeRouter.usingBackend(backendURL)
        Task {
            let meal: Meal
            if usingBackend || !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                do {
                    meal = try await AnthropicRecipe.generate(
                        from: entry, rules: state.rules,
                        apiKey: key,
                        backendBaseURL: backendURL,
                        backendAuthToken: backendToken
                    )
                } catch {
                    // Real call failed — fall back so the user always gets something.
                    print("AnthropicRecipe failed:", error)
                    meal = synthesizeMeal()
                }
            } else {
                meal = synthesizeMeal()
            }
            await MainActor.run {
                state.customMeals.removeAll { $0.id == meal.id }
                state.customMeals.append(meal)
                generatedMealId = meal.id
                generating = false
            }
        }
    }

    private func synthesizeMeal() -> Meal {
        let mealId = "insp-\(entry.id.uuidString.prefix(8))"
        let avoid = Set(state.rules.avoidIngredients.map { $0.lowercased() })

        let ingredients: [Ingredient] = entry.items
            .filter { !avoid.contains($0.name.lowercased()) }
            .map { item in
                Ingredient(
                    name: item.name,
                    qty: item.qty.replacingOccurrences(of: "~", with: ""),
                    aisle: guessAisle(for: item.name)
                )
            }
        let steps = synthesizeSteps(from: entry.items)
        let proteinId = bestProteinId(for: entry.items)

        return Meal(
            id: mealId,
            title: entry.title,
            time: 35,
            kid: false,
            tags: ["inspiration"],
            proteinId: proteinId,
            ings: ingredients,
            steps: steps
        )
    }

    private func synthesizeSteps(from items: [SnapItem]) -> [String] {
        var steps: [String] = []
        if items.contains(where: { $0.name.localizedCaseInsensitiveContains("rice") }) {
            steps.append("Start the rice (or your base) so it's done by plating time.")
        }
        if let protein = items.first(where: { $0.protein > 10 }) {
            steps.append("Season the \(protein.name) with salt and pepper. Sear or roast until cooked through, about 15 minutes.")
        }
        let veg = items.filter { $0.protein < 5 && $0.fat < 5 }
        if !veg.isEmpty {
            let names = veg.map(\.name).joined(separator: ", ")
            steps.append("Prep \(names): trim, slice, and cook however you'd like — sheet pan at 425°F for 18 min works well.")
        }
        steps.append("Plate everything together and serve.")
        return steps
    }

    private func bestProteinId(for items: [SnapItem]) -> String {
        guard let top = items.max(by: { $0.protein < $1.protein }) else { return "pantry_eggs" }
        let n = top.name.lowercased()
        if n.contains("chicken thigh") { return "fresh_chicken" }
        if n.contains("chicken")       { return "fresh_chick_b" }
        if n.contains("beef") || n.contains("burger") { return "fresh_beef" }
        if n.contains("steak")         { return "fresh_steak" }
        if n.contains("pork")          { return "fresh_pork" }
        if n.contains("turkey")        { return "fresh_turkey" }
        if n.contains("bacon")         { return "fresh_bacon" }
        return "pantry_eggs"
    }

    private func guessAisle(for ingredientName: String) -> Aisle {
        let n = ingredientName.lowercased()
        if n.contains("chicken") || n.contains("beef") || n.contains("pork") || n.contains("turkey")
            || n.contains("bacon") || n.contains("fish") || n.contains("steak") || n.contains("taco") { return .meat }
        if n.contains("cheese") || n.contains("milk") || n.contains("egg") || n.contains("butter")
            || n.contains("yogurt") || n.contains("cream") { return .dairy }
        if n.contains("bread") || n.contains("bun") || n.contains("dough") || n.contains("tortilla") { return .bakery }
        if n.contains("pasta") || n.contains("rice") || n.contains("oil") || n.contains("salsa")
            || n.contains("sauce") || n.contains("ketchup") || n.contains("seasoning")
            || n.contains("flake") || n.contains("can ") { return .pantry }
        if n.contains("frozen") { return .frozen }
        return .produce
    }

    private func timeAgo(_ d: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: d, relativeTo: Date())
    }
}
