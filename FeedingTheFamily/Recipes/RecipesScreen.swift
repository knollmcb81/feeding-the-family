import SwiftUI

struct RecipesScreen: View {
    @Environment(AppState.self) private var state
    @State private var filter: RecipeFilter = .all
    @State private var openMealId: String? = nil
    @State private var showHistory: Bool = false
    @State private var showImport: Bool = false
    @State private var pendingDeleteId: String? = nil

    private struct Annotated: Identifiable {
        let meal: Meal
        let confidence: Double
        let trend: Trend
        var id: String { meal.id }
    }

    /// In-rotation meals (excludes anything the user has set aside).
    private var annotated: [Annotated] {
        Planner.allMeals(custom: state.customMeals, dismissed: state.dismissedMealIds).map { base in
            let resolved = Planner.activeMeal(id: base.id, overrides: state.mealOverrides, custom: state.customMeals)
            return Annotated(
                meal: resolved,
                confidence: Learning.confidence(for: resolved.id, ratings: state.ratings),
                trend: Learning.trend(for: resolved.id, ratings: state.ratings)
            )
        }
    }

    /// Meals the user has manually set aside via the per-row menu.
    private var setAside: [Annotated] {
        (SeedData.meals + state.customMeals)
            .filter { state.dismissedMealIds.contains($0.id) }
            .map { base in
                let resolved = Planner.activeMeal(id: base.id, overrides: state.mealOverrides, custom: state.customMeals)
                return Annotated(
                    meal: resolved,
                    confidence: Learning.confidence(for: resolved.id, ratings: state.ratings),
                    trend: Learning.trend(for: resolved.id, ratings: state.ratings)
                )
            }
    }

    private var mostLoved: [Annotated] {
        annotated.filter { $0.confidence >= 4.2 }
            .sorted { $0.confidence > $1.confidence }
            .prefix(4).map { $0 }
    }

    private var filtered: [Annotated] {
        switch filter {
        case .all:    return annotated
        case .quick:  return annotated.filter { $0.meal.time <= 25 }
        case .kid:    return annotated.filter { $0.meal.kid }
        case .weekend:return annotated.filter { $0.meal.time >= 45 }
        case .slop:
            // Set-aside (manual) first, then any low-rated leftovers.
            let lowRated = annotated.filter { $0.confidence > 0 && $0.confidence < 3 }
            return setAside + lowRated
        }
    }

    private var isInSlop: Bool { filter == .slop }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if !mostLoved.isEmpty {
                        mostLovedRow
                            .padding(.top, 8)
                    }
                    filterPills
                        .padding(.top, 14)
                    if filtered.isEmpty {
                        emptyFilterState
                    } else {
                        ForEach(filtered) { a in
                            recipeRow(a)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(T.paper)
        .sheet(item: Binding(
            get: { openMealId.map { MealIdWrap(id: $0) } },
            set: { openMealId = $0?.id })
        ) { wrap in
            RecipeDetail(mealId: wrap.id)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showHistory) {
            HistorySheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showImport) {
            ImportRecipeSheet(importedMealId: Binding(
                get: { openMealId },
                set: { openMealId = $0 }
            ))
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .background(deleteAlert)
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your kitchen")
                    .font(AppFont.text(11, weight: .semibold))
                    .kerning(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(T.ink3)
                Text("Recipes")
                    .font(AppFont.text(28, weight: .bold))
                    .kerning(-1)
                    .foregroundStyle(T.ink)
            }
            Spacer()
            HStack(spacing: 6) {
                Button { showImport = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("Import")
                            .font(AppFont.text(11.5, weight: .semibold))
                    }
                    .foregroundStyle(T.accentInk)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(T.accent))
                }
                .buttonStyle(.plain)

                Button { showHistory = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 11, weight: .semibold))
                        Text("History")
                            .font(AppFont.text(11.5, weight: .semibold))
                    }
                    .foregroundStyle(T.ink2)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Capsule().strokeBorder(T.rule, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 4)
        }
        .padding(.horizontal, 22)
        .padding(.top, 4)
        .padding(.bottom, 6)
    }

    private var mostLovedRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("MOST LOVED")
                    .font(AppFont.text(11, weight: .bold))
                    .kerning(1.2)
                    .foregroundStyle(T.ink2)
                Spacer()
                Text("★ 4.2+")
                    .font(AppFont.text(10.5))
                    .foregroundStyle(T.ink3)
            }
            .padding(.horizontal, 6)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(mostLoved) { a in
                        mostLovedCard(a)
                    }
                }
                .padding(.horizontal, 6)
            }
        }
    }

    private func mostLovedCard(_ a: Annotated) -> some View {
        Button { openMealId = a.meal.id } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(stripePattern)
                        .frame(width: 156, height: 88)
                    Text(String(format: "%.1f★", a.confidence))
                        .font(AppFont.mono(10, weight: .bold))
                        .foregroundStyle(T.paper)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(T.ink))
                        .padding(6)
                }
                Text(a.meal.title)
                    .font(AppFont.text(13, weight: .semibold))
                    .foregroundStyle(T.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 10)
                HStack(spacing: 6) {
                    Circle()
                        .fill(proteinDotColor(Planner.protein(for: a.meal)))
                        .frame(width: 7, height: 7)
                    Text("\(a.meal.time)m")
                        .font(AppFont.mono(10.5))
                        .foregroundStyle(T.ink2)
                    Spacer()
                    Sparkline(history: state.ratings[a.meal.id] ?? [], width: 50, height: 14)
                }
                .padding(.top, 4)
            }
            .padding(12)
            .frame(width: 180, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(T.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(T.ruleSoft, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var stripePattern: LinearGradient {
        // Diagonal repeating stripe — placeholder for dish photography.
        LinearGradient(
            stops: [
                .init(color: T.paperDeep, location: 0.0),
                .init(color: T.paperDeep, location: 0.5),
                .init(color: T.ruleSoft, location: 0.5),
                .init(color: T.ruleSoft, location: 1.0),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RecipeFilter.allCases) { f in
                    Button { filter = f } label: {
                        Text(f.label)
                            .font(AppFont.text(12, weight: .semibold))
                            .foregroundStyle(filter == f ? T.paper : T.ink2)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(filter == f ? T.ink : T.card)
                                    .overlay(
                                        Capsule().strokeBorder(filter == f ? Color.clear : T.rule, lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 12)
        }
    }

    private var emptyFilterState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "tray")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(T.ink3)
            Text(emptyTitle)
                .font(AppFont.text(14, weight: .semibold))
                .foregroundStyle(T.ink)
            Text(emptyHint)
                .font(AppFont.text(12))
                .foregroundStyle(T.ink3)
                .lineSpacing(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(T.rule, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
        .padding(.top, 14)
    }

    private var emptyTitle: String {
        switch filter {
        case .all:     return "No recipes yet"
        case .quick:   return "No quick recipes"
        case .kid:     return "No kid-approved recipes"
        case .weekend: return "No weekend recipes"
        case .slop:    return "Nothing set aside"
        }
    }

    private var emptyHint: String {
        switch filter {
        case .all:     return "Tap + Import to bring in a recipe from a URL or photo, or generate one from a saved snap in Ideas."
        case .quick:   return "Quick recipes are 25 minutes or less. Edit a recipe's cook time to surface it here."
        case .kid:     return "Recipes flagged kid-approved show up here. Toggle Kid-approved on a recipe in edit mode."
        case .weekend: return "Recipes 45+ minutes show up here — the weekend project meals."
        case .slop:    return "Tap the ••• menu on any recipe to set it aside. It'll land here, out of rotation, and you can bring it back anytime."
        }
    }

    private func recipeRow(_ a: Annotated) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Button { openMealId = a.meal.id } label: {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(a.meal.title)
                            .font(AppFont.text(15, weight: .semibold))
                            .kerning(-0.2)
                            .foregroundStyle(T.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(proteinDotColor(Planner.protein(for: a.meal)))
                                    .frame(width: 7, height: 7)
                                Text(Planner.protein(for: a.meal).name)
                                    .font(AppFont.text(11))
                                    .foregroundStyle(T.ink2)
                            }
                            Text("·").foregroundStyle(T.rule)
                            Text("\(a.meal.time)m")
                                .font(AppFont.mono(11))
                                .foregroundStyle(T.ink2)
                            if a.meal.kid {
                                Text("·").foregroundStyle(T.rule)
                                Text("kid-approved")
                                    .font(AppFont.text(11, weight: .semibold))
                                    .foregroundStyle(T.accent2)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 4) {
                        if a.confidence > 0 {
                            ConfidenceBadge(confidence: a.confidence, trend: a.trend)
                        }
                        Sparkline(history: state.ratings[a.meal.id] ?? [], width: 56, height: 14)
                    }
                }
            }
            .buttonStyle(.plain)
            rowMenu(a)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(T.ruleSoft).frame(height: 1).padding(.horizontal, 8)
        }
    }

    /// The "•••" menu shown at the right edge of every recipe row. Surfaces
    /// destructive + reversible actions inline so the user doesn't have to
    /// open the recipe, hit Edit, then find the trash button.
    private func rowMenu(_ a: Annotated) -> some View {
        Menu {
            if state.dismissedMealIds.contains(a.meal.id) {
                Button {
                    state.dismissedMealIds.remove(a.meal.id)
                } label: {
                    Label("Bring back into rotation", systemImage: "arrow.uturn.backward")
                }
            } else {
                Button {
                    state.dismissedMealIds.insert(a.meal.id)
                } label: {
                    Label("Set aside (move to Slop)", systemImage: "tray.and.arrow.down")
                }
            }
            Divider()
            Button(role: .destructive) {
                pendingDeleteId = a.meal.id
            } label: {
                Label("Delete recipe", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(T.ink3)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("More actions for \(a.meal.title)")
    }

    private var deleteAlert: some View {
        EmptyView()
            .confirmationDialog(
                pendingDeleteTitle,
                isPresented: Binding(
                    get: { pendingDeleteId != nil },
                    set: { if !$0 { pendingDeleteId = nil } }
                ),
                titleVisibility: .visible,
                presenting: pendingDeleteId
            ) { mealId in
                Button("Delete", role: .destructive) {
                    deleteMeal(id: mealId)
                }
                Button("Cancel", role: .cancel) { }
            } message: { _ in
                Text("This recipe will be removed. Custom recipes are deleted permanently. Built-in recipes get set aside (you can bring them back from Slop).")
            }
    }

    private var pendingDeleteTitle: String {
        guard let id = pendingDeleteId else { return "" }
        return "Delete \(Planner.activeMeal(id: id, overrides: state.mealOverrides, custom: state.customMeals).title)?"
    }

    /// Custom recipes get hard-removed; seed recipes get dismissed (we can't
    /// truly purge them from the binary). Either way the meal disappears from
    /// rotation, but seed meals remain restorable from Slop.
    private func deleteMeal(id: String) {
        if state.customMeals.contains(where: { $0.id == id }) {
            state.customMeals.removeAll { $0.id == id }
            state.mealOverrides[id] = nil
            state.dismissedMealIds.remove(id)
        } else {
            state.dismissedMealIds.insert(id)
        }
        pendingDeleteId = nil
    }

    private func proteinDotColor(_ p: Protein) -> Color {
        switch p.perish {
        case .fresh:  return T.proteinFresh
        case .frozen: return T.proteinFrozen
        case .pantry: return T.proteinPantry
        }
    }
}

enum RecipeFilter: String, CaseIterable, Identifiable {
    case all, quick, kid, weekend, slop
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: return "All"
        case .quick: return "Quick"
        case .kid: return "Kid-approved"
        case .weekend: return "Weekend"
        case .slop: return "Slop"
        }
    }
}

private struct MealIdWrap: Identifiable { let id: String }
