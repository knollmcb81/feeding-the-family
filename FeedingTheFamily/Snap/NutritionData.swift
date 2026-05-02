import Foundation

struct DayNutrition: Hashable {
    let kcal: Int
    let protein: Int
    let carbs: Int
    let fat: Int
}

struct NutritionGoal: Codable, Hashable {
    var kcal: Int
    var protein: Int
    var carbs: Int
    var fat: Int

    static let `default` = NutritionGoal(kcal: 2000, protein: 110, carbs: 240, fat: 70)
}

struct WeekSummary {
    let kcal: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let days: Int           // logged days
    let avgKcal: Int
    let avgProtein: Int
}

enum NutritionData {
    /// 4 weeks of mocked daily totals. nil = not logged.
    /// Index 0 = oldest, 3 = current week.
    static let weeks: [[DayNutrition?]] = [
        // 4 weeks ago — sparse logging
        [
            DayNutrition(kcal: 1840, protein: 95,  carbs: 215, fat: 68),
            nil,
            DayNutrition(kcal: 2210, protein: 130, carbs: 245, fat: 78),
            nil,
            nil,
            DayNutrition(kcal: 2050, protein: 105, carbs: 230, fat: 72),
            DayNutrition(kcal: 1920, protein: 88,  carbs: 240, fat: 65),
        ],
        // 3 weeks ago — picking up
        [
            DayNutrition(kcal: 1980, protein: 108, carbs: 225, fat: 70),
            DayNutrition(kcal: 1750, protein: 92,  carbs: 200, fat: 60),
            DayNutrition(kcal: 2080, protein: 115, carbs: 235, fat: 72),
            nil,
            DayNutrition(kcal: 2240, protein: 128, carbs: 255, fat: 80),
            DayNutrition(kcal: 2150, protein: 118, carbs: 245, fat: 75),
            DayNutrition(kcal: 1880, protein: 100, carbs: 210, fat: 66),
        ],
        // 2 weeks ago — consistent, hitting goal
        [
            DayNutrition(kcal: 2020, protein: 112, carbs: 230, fat: 71),
            DayNutrition(kcal: 2100, protein: 120, carbs: 235, fat: 73),
            DayNutrition(kcal: 1960, protein: 108, carbs: 220, fat: 68),
            DayNutrition(kcal: 2180, protein: 125, carbs: 240, fat: 76),
            DayNutrition(kcal: 2050, protein: 115, carbs: 232, fat: 72),
            nil,
            DayNutrition(kcal: 2310, protein: 130, carbs: 260, fat: 82),
        ],
        // This week — Mon-Thu logged, Fri (today) not yet, Sat/Sun future.
        [
            DayNutrition(kcal: 2090, protein: 118, carbs: 235, fat: 72),
            DayNutrition(kcal: 1820, protein: 102, carbs: 200, fat: 64),
            DayNutrition(kcal: 1980, protein: 110, carbs: 220, fat: 70),
            DayNutrition(kcal: 2150, protein: 122, carbs: 240, fat: 75),
            nil, nil, nil,
        ],
    ]

    static let dayLabels = ["M","T","W","T","F","S","S"]
    static let todayWeekIdx = 3
    /// Day index within `weeks[todayWeekIdx]`. Defaults to today's actual weekday.
    static var todayDayIdx: Int { Today.todayIdx }

    /// Sum + average over the LOGGED days only.
    static func summary(of week: [DayNutrition?]) -> WeekSummary {
        let logged = week.compactMap { $0 }
        guard !logged.isEmpty else {
            return WeekSummary(kcal: 0, protein: 0, carbs: 0, fat: 0, days: 0, avgKcal: 0, avgProtein: 0)
        }
        let sumK = logged.reduce(0) { $0 + $1.kcal }
        let sumP = logged.reduce(0) { $0 + $1.protein }
        let sumC = logged.reduce(0) { $0 + $1.carbs }
        let sumF = logged.reduce(0) { $0 + $1.fat }
        return WeekSummary(
            kcal: sumK, protein: sumP, carbs: sumC, fat: sumF,
            days: logged.count,
            avgKcal: sumK / logged.count,
            avgProtein: sumP / logged.count
        )
    }
}
