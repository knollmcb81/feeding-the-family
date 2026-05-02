import Foundation

/// Snapshot of all user-mutable state. Persisted to JSON in Application Support.
/// Versioned so we can change shape later and still load old saves.
struct AppSnapshot: Codable {
    var version: Int = 1
    var week: [DayPlan]
    var rules: Rules
    var ratings: [String: [Int]]
    var unratedDays: Set<String>
    var checkedItems: Set<String>
    var customItems: [GroceryItem]
    var staples: [GroceryItem]
    var staplesOn: Bool
    var mealOverrides: [String: Meal]
    var snapLog: [SnapEntry]
    var lastSnapFixtureIdx: Int
    var customMeals: [Meal]
    var customItemHistory: [DatedCustomItem] = []
    var dismissedSuggestions: Set<String> = []
    var archivedWeeks: [ArchivedWeek] = []
    var currentWeekStartDate: Date? = nil
    var anthropicApiKey: String = ""
    var hasCompletedOnboarding: Bool = false
    var nutritionGoal: NutritionGoal = .default
    var forwardPlannedWeek: [DayPlan]? = nil
}

enum Persistence {
    private static let filename = "FeedingTheFamily.json"

    private static var url: URL {
        let dir = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask, appropriateFor: nil, create: true
        )) ?? FileManager.default.temporaryDirectory
        return dir.appendingPathComponent(filename)
    }

    static func save(_ snapshot: AppSnapshot) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(snapshot)
            try data.write(to: url, options: .atomic)
        } catch {
            // Persistence failures are non-fatal — user's session continues.
            print("Persistence.save failed:", error)
        }
    }

    static func load() -> AppSnapshot? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(AppSnapshot.self, from: data)
        } catch {
            print("Persistence.load failed:", error)
            return nil
        }
    }
}

extension AppState {
    /// Capture the current state into a Codable snapshot.
    func snapshot() -> AppSnapshot {
        AppSnapshot(
            week: week,
            rules: rules,
            ratings: ratings,
            unratedDays: unratedDays,
            checkedItems: checkedItems,
            customItems: customItems,
            staples: staples,
            staplesOn: staplesOn,
            mealOverrides: mealOverrides,
            snapLog: snapLog,
            lastSnapFixtureIdx: lastSnapFixtureIdx,
            customMeals: customMeals,
            customItemHistory: customItemHistory,
            dismissedSuggestions: dismissedSuggestions,
            archivedWeeks: archivedWeeks,
            currentWeekStartDate: currentWeekStartDate,
            anthropicApiKey: anthropicApiKey,
            hasCompletedOnboarding: hasCompletedOnboarding,
            nutritionGoal: nutritionGoal,
            forwardPlannedWeek: forwardPlannedWeek
        )
    }

    /// Apply a previously-saved snapshot. Doesn't touch derived state.
    func apply(_ snapshot: AppSnapshot) {
        // Detect a Monday rollover. If the snapshot's week belongs to an earlier
        // Monday than today, archive it before adopting fresh dates.
        let cal = Calendar.current
        let today = Today.monday
        var archived = snapshot.archivedWeeks
        let savedWeekStart = snapshot.currentWeekStartDate
        let isRollover: Bool = {
            guard let saved = savedWeekStart else { return false }
            return !cal.isDate(saved, inSameDayAs: today)
        }()

        if isRollover, let saved = savedWeekStart {
            let isoFmt = ISO8601DateFormatter()
            isoFmt.formatOptions = [.withFullDate]
            let key = isoFmt.string(from: saved)
            // Avoid double-archiving on the same Monday.
            if !archived.contains(where: { $0.id == key }) {
                archived.append(
                    ArchivedWeek(id: key, mondayDate: saved, week: snapshot.week)
                )
            }
        }
        self.archivedWeeks = archived
        self.currentWeekStartDate = today

        // Keep day labels/dates fresh. On rollover the unlocked-day meals carry
        // over too; the user can Auto-draft to refresh.
        // PROMOTION: if the user planned next week and we just rolled over,
        // promote forwardPlannedWeek into the current slot before rebasing dates.
        let baseWeek: [DayPlan] = (isRollover && snapshot.forwardPlannedWeek != nil)
            ? snapshot.forwardPlannedWeek!
            : snapshot.week
        let fresh = SeedData.dynamicWeek
        self.week = zip(fresh, baseWeek).map { freshDay, savedDay in
            DayPlan(
                day: freshDay.day,
                date: freshDay.date,
                mealId: savedDay.mealId,
                locked: savedDay.locked,
                slot: freshDay.slot
            )
        }
        // After promotion, clear the forward slot — user can plan another week ahead.
        self.forwardPlannedWeek = isRollover ? nil : snapshot.forwardPlannedWeek
        self.rules = snapshot.rules
        self.ratings = snapshot.ratings
        self.unratedDays = snapshot.unratedDays
        self.checkedItems = snapshot.checkedItems
        self.customItems = snapshot.customItems
        self.staples = snapshot.staples
        self.staplesOn = snapshot.staplesOn
        self.mealOverrides = snapshot.mealOverrides
        self.snapLog = snapshot.snapLog
        self.lastSnapFixtureIdx = snapshot.lastSnapFixtureIdx
        self.customMeals = snapshot.customMeals
        self.customItemHistory = snapshot.customItemHistory
        self.dismissedSuggestions = snapshot.dismissedSuggestions
        self.anthropicApiKey = snapshot.anthropicApiKey
        self.hasCompletedOnboarding = snapshot.hasCompletedOnboarding
        self.nutritionGoal = snapshot.nutritionGoal
        // archivedWeeks + currentWeekStartDate + forwardPlannedWeek already set above.
    }
}
