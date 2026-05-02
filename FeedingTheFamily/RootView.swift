import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case plan, list, snap, ideas, recipes
    var id: String { rawValue }
    var label: String {
        switch self {
        case .plan: return "Plan"
        case .list: return "List"
        case .snap: return "Snap"
        case .ideas: return "Ideas"
        case .recipes: return "Recipes"
        }
    }
    var icon: String {
        switch self {
        case .plan: return "calendar"
        case .list: return "cart"
        case .snap: return "camera"
        case .ideas: return "lightbulb"
        case .recipes: return "sparkles"
        }
    }
}

@Observable
final class AppState {
    var week: [DayPlan] = SeedData.dynamicWeek
    var rules: Rules = SeedData.rules
    var todayIdx: Int = Today.todayIdx

    // Per-meal rating history. Used by Learning.confidence + Learning.trend.
    var ratings: [String: [Int]] = [
        "daddy-dinner": [5, 5, 5, 5],
        "french-dip":   [5, 4, 5],
        "taco-bowls":   [4, 4, 5, 4],
        "turkey-ginger":[3, 4, 4],
        "leftovers":    [3, 3, 4],
        "mama-pizza":   [5, 5, 5, 4, 5],
        "pork-loin":    [4, 4, 5],
    ]

    // Past day labels (Mon, Tue, ...) the user hasn't rated yet — drives the rating prompt.
    /// Defaults to every past day this week. As the user rates, days are removed.
    var unratedDays: Set<String> = Set(Today.labels.prefix(Today.todayIdx))

    // Grocery list state.
    var checkedItems: Set<String> = []         // keyed by GroceryItem.id ("aisle|name")
    var customItems: [GroceryItem] = []
    var staples: [GroceryItem] = SeedData.defaultStaples
    var staplesOn: Bool = true

    // Per-meal recipe overrides. Stores the whole customized Meal — title, time,
    // kid flag, ingredients, steps. Wins over the seed in `SeedData.meals`.
    // Clearing the entry reverts to the seeded meal.
    var mealOverrides: [String: Meal] = [:]

    // Snap log — entries logged by the snap → result flow.
    var snapLog: [SnapEntry] = []
    /// Last fixture index used for the mocked detection cycle.
    var lastSnapFixtureIdx: Int = -1

    // Recipes the user generated from inspirations. These layer on top of
    // SeedData.meals everywhere meals are listed (Recipes index, Auto-draft, Swap).
    var customMeals: [Meal] = []

    // Rolling log of custom items ever added — feeds Suggestions.learned().
    var customItemHistory: [DatedCustomItem] = []
    /// IDs of suggestions the user dismissed (id format "name|aisle").
    var dismissedSuggestions: Set<String> = []

    // Archive of past weeks — populated automatically on Monday rollover, plus
    // a couple of seeded demo weeks so the History view has content on day one.
    var archivedWeeks: [ArchivedWeek] = SeedData.demoArchivedWeeks
    /// Tracks the Monday this `week` belongs to, so Persistence can detect rollover.
    var currentWeekStartDate: Date = Today.monday

    /// Anthropic API key for real Claude-Vision-based food detection.
    /// When empty, the Snap result falls back to the cycling demo fixtures.
    var anthropicApiKey: String = ""

    /// True once the user has completed the first-launch setup.
    /// Persisted, so onboarding only shows once.
    var hasCompletedOnboarding: Bool = false

    /// Daily macro goals — drives the ring, bars, and trend percentages on Snap.
    var nutritionGoal: NutritionGoal = .default

    /// Forward-planned next week. nil until the user taps the forward arrow on Plan.
    /// On Monday rollover this gets promoted to `week` (see Persistence.apply).
    var forwardPlannedWeek: [DayPlan]? = nil
}

struct RootView: View {
    @State private var state = AppState()
    @State private var tab: AppTab = .plan
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            T.paper
                .ignoresSafeArea()

            if state.hasCompletedOnboarding {
                VStack(spacing: 0) {
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    AppTabBar(tab: $tab)
                }
                .transition(.opacity)
            } else {
                OnboardingFlow()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: state.hasCompletedOnboarding)
        .environment(state)
        // The design is light-theme-only — locking color scheme so system dark
        // mode doesn't invert TextField/SecureField text colors against the
        // paper background.
        .preferredColorScheme(.light)
        .task {
            // Hydrate from disk once on launch.
            if let saved = Persistence.load() {
                state.apply(saved)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive {
                Persistence.save(state.snapshot())
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .plan:    PlanScreen()
        case .list:    ListScreen()
        case .snap:    SnapScreen()
        case .ideas:   IdeasScreen()
        case .recipes: RecipesScreen()
        }
    }
}

struct PlaceholderScreen: View {
    let title: String
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Text(title)
                .font(AppFont.text(34, weight: .bold))
                .kerning(-1.2)
                .foregroundStyle(T.ink)
            Text("Coming next")
                .font(AppFont.mono(11))
                .foregroundStyle(T.ink3)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(T.paper)
    }
}
