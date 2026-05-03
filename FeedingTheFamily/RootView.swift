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
    init() {
        // Pick up the API key from Keychain on first construction so the value
        // survives across launches even before Persistence.apply() runs.
        self.anthropicApiKey = Keychain.getApiKey()
    }

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
    /// Parallel to `ratings` — for each rating the user gave, an optional note
    /// of what worked or didn't. Empty string means "no context provided."
    /// Populated from the expanded RatingPrompt on ≤2★ ratings.
    var ratingFeedback: [String: [String]] = [:]

    // Past day labels (Mon, Tue, ...) the user hasn't rated yet — drives the rating prompt.
    /// Defaults to every past day this week. As the user rates, days are removed.
    var unratedDays: Set<String> = Set(Today.labels.prefix(Today.todayIdx))

    // Grocery list state.
    var checkedItems: Set<String> = []         // keyed by GroceryItem.id ("aisle|name")
    /// Items the user explicitly skipped via the per-row menu — keyed the same
    /// way as checkedItems. Cleared on Monday rollover so each fresh week starts
    /// without stale skips. Distinct from "I have this": skipping is per-trip,
    /// pantryHave is permanent.
    var skippedListItems: Set<String> = []
    var customItems: [GroceryItem] = []
    var staples: [GroceryItem] = SeedData.defaultStaples
    var staplesOn: Bool = true
    /// Which day-week pairs feed the grocery list. Keys: "0-Mon" (current week)
    /// or "1-Tue" (next week). Default selects every day of the current week.
    var selectedListDays: Set<String> = Set(Today.labels.map { "0-\($0)" })

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
    /// Stored in the iOS Keychain (not the JSON snapshot). Mirrored here so
    /// SwiftUI views can observe changes — write through `setApiKey(_:)`.
    var anthropicApiKey: String = ""

    /// Single write path for the API key — updates both in-memory state and
    /// Keychain so the value survives app reinstalls of the same bundle id.
    func setApiKey(_ key: String) {
        let cleaned = key
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        anthropicApiKey = cleaned
        Keychain.setApiKey(cleaned)
    }

    /// True once the user has completed the first-launch setup.
    /// Persisted, so onboarding only shows once.
    var hasCompletedOnboarding: Bool = false

    /// Daily macro goals — drives the ring, bars, and trend percentages on Snap.
    var nutritionGoal: NutritionGoal = .default

    /// Forward-planned next week. nil until the user taps the forward arrow on Plan.
    /// On Monday rollover this gets promoted to `week` (see Persistence.apply).
    var forwardPlannedWeek: [DayPlan]? = nil

    /// Meal IDs the user hid from their library. Filtered out everywhere meals
    /// are listed (Recipes, Auto-draft, Swap). Reversible by clearing the set.
    var dismissedMealIds: Set<String> = []

    /// Opt-in daily 8 PM "rate dinner" reminder. Set from Settings toggle.
    var nightlyReminderEnabled: Bool = false

    /// Optional backend proxy. When set, all Claude calls route through this
    /// URL instead of api.anthropic.com directly — auth via Bearer token. The
    /// backend is responsible for holding the actual Anthropic key. See
    /// `backend/` in the repo for a Vercel-ready reference implementation.
    var backendBaseURL: String = ""
    var backendAuthToken: String = ""
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
            // Re-schedule the nightly reminder if the user opted in. (A reinstall
            // or fresh device wipe drops scheduled notifications, so we re-add
            // them on every launch — UNUserNotificationCenter dedups by id.)
            if state.nightlyReminderEnabled {
                Notifications.scheduleNightlyRating()
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
