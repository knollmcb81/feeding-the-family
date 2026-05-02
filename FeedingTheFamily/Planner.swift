import Foundation

struct PlanWarning: Identifiable, Hashable {
    enum Kind { case meatLate, slowOnQuick, repeatProtein }
    let id = UUID()
    let kind: Kind
    let dayIdx: Int
    let msg: String
}

struct GroceryItem: Identifiable, Hashable, Codable {
    let name: String
    let aisle: Aisle
    let qty: [String]
    let meals: [String]
    let source: Source
    enum Source: String, Hashable, Codable { case meal, staple, custom }
    var id: String { "\(aisle.rawValue)|\(name)" }
}

enum Planner {
    /// All meals available across the app — seed library + user-generated,
    /// minus anything the user has dismissed/hidden.
    static func allMeals(custom: [Meal] = [], dismissed: Set<String> = []) -> [Meal] {
        (SeedData.meals + custom).filter { !dismissed.contains($0.id) }
    }

    /// Returns the active version of a meal — override wins, custom meals next, else seed.
    static func activeMeal(id: String, overrides: [String: Meal] = [:], custom: [Meal] = []) -> Meal {
        if let override = overrides[id] { return override }
        if let custom = custom.first(where: { $0.id == id }) { return custom }
        return meal(byId: id)
    }

    /// Aggregate ingredients across the week, grouped by aisle.
    static func groceryFor(
        week: [DayPlan],
        pantryHave: Set<String> = [],
        overrides: [String: Meal] = [:]
    ) -> [Aisle: [GroceryItem]] {
        var bucket: [String: GroceryItem] = [:]   // key: "name|aisle"
        func add(ing: Ingredient, label: String) {
            if pantryHave.contains(ing.name) { return }
            let key = "\(ing.name)|\(ing.aisle.rawValue)"
            if let cur = bucket[key] {
                bucket[key] = GroceryItem(
                    name: cur.name, aisle: cur.aisle,
                    qty: cur.qty + [ing.qty],
                    meals: cur.meals + [label],
                    source: .meal
                )
            } else {
                bucket[key] = GroceryItem(
                    name: ing.name, aisle: ing.aisle,
                    qty: [ing.qty], meals: [label], source: .meal
                )
            }
        }
        for day in week {
            let m = activeMeal(id: day.mealId, overrides: overrides)
            for ing in m.ings {
                add(ing: ing, label: m.title)
            }
            for side in day.sides {
                for ing in side.ings {
                    add(ing: ing, label: side.name)
                }
            }
        }
        var grouped: [Aisle: [GroceryItem]] = [:]
        for item in bucket.values {
            grouped[item.aisle, default: []].append(item)
        }
        for aisle in grouped.keys {
            grouped[aisle]?.sort { $0.name < $1.name }
        }
        return grouped
    }

    static func meal(byId id: String) -> Meal {
        SeedData.meals.first(where: { $0.id == id })
            ?? SeedData.meals[0]
    }

    static func protein(for meal: Meal) -> Protein {
        SeedData.proteins[meal.proteinId]
            ?? Protein(id: meal.proteinId, name: meal.proteinId, perish: .pantry, aisle: .pantry)
    }

    static func freshDayIndices(in week: [DayPlan]) -> [Int] {
        week.enumerated().compactMap { idx, day in
            protein(for: meal(byId: day.mealId)).perish == .fresh ? idx : nil
        }
    }

    /// Days since the most recent shop (primary `shopDay` or optional `topUpDay`)
    /// for the given Mon-relative day index. The "shop" is assumed to happen
    /// at the start of the named weekday — buying meat on Wed makes Wed itself age 0.
    /// If both shop days fall after the queried day in the same week, we look
    /// back to last week's shop.
    static func freshAge(dayIdx: Int, rules: Rules) -> Int {
        let weekdays = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]
        var shopIdxs: [Int] = []
        if let s = weekdays.firstIndex(of: rules.shopDay) { shopIdxs.append(s) }
        if let t = rules.topUpDay, let i = weekdays.firstIndex(of: t) { shopIdxs.append(i) }
        guard !shopIdxs.isEmpty else { return 99 }

        return shopIdxs.map { shopIdx -> Int in
            shopIdx <= dayIdx ? (dayIdx - shopIdx) : (dayIdx + 7 - shopIdx)
        }.min() ?? 99
    }

    /// Convenience predicate matching the old `dayIdx < meatDays` shape.
    static func isFreshOK(dayIdx: Int, rules: Rules) -> Bool {
        freshAge(dayIdx: dayIdx, rules: rules) <= rules.meatDays
    }

    /// Re-pick meals for any unlocked day. Mirrors planner.jsx autoDraft.
    /// Respects: locked days, avoid list, fresh-meat day window, no repeat protein, slot bias.
    /// Within the candidate set, picks the meal with the highest confidence score.
    static func autoDraft(
        week: [DayPlan],
        rules: Rules,
        ratings: [String: [Int]],
        weekendDiscovery: Bool = true,
        customMeals: [Meal] = [],
        dismissed: Set<String> = []
    ) -> [DayPlan] {
        // Locked meals can't be reused. Unlocked-day meals are also blocked initially
        // so each unlocked day actually swaps; we relax this if no candidates remain.
        let lockedMeals = Set(week.filter { $0.locked }.map(\.mealId))
        let unlockedCurrentMeals = Set(week.filter { !$0.locked }.map(\.mealId))
        var used = lockedMeals
        var next = week

        for i in 0..<next.count {
            if next[i].locked { continue }
            let isQuick = rules.quickNights.contains(next[i].day)
            let dayNum = i + 1
            let prevProteinName: String? = i > 0
                ? protein(for: meal(byId: next[i - 1].mealId)).name
                : nil

            // 3 progressively-relaxed filter passes. Each falls back to the next
            // if no candidates remain.
            let candidatePool = allMeals(custom: customMeals, dismissed: dismissed)
            func filter(allowLateFresh: Bool, allowOriginal: Bool) -> [Meal] {
                candidatePool.filter { m in
                    if used.contains(m.id) { return false }
                    if !allowOriginal && unlockedCurrentMeals.contains(m.id) { return false }
                    if m.ings.contains(where: { rules.avoidIngredients.contains($0.name) }) { return false }
                    if isQuick && m.time > 30 { return false }
                    let p = protein(for: m)
                    if !allowLateFresh && p.perish == .fresh && !isFreshOK(dayIdx: i, rules: rules) { return false }
                    if let prevName = prevProteinName, prevName == p.name { return false }
                    return true
                }
            }
            var candidates = filter(allowLateFresh: false, allowOriginal: false)
            if candidates.isEmpty {
                candidates = filter(allowLateFresh: true,  allowOriginal: false)
            }
            if candidates.isEmpty {
                candidates = filter(allowLateFresh: true,  allowOriginal: true)
            }
            guard !candidates.isEmpty else { continue }

            let slot = next[i].slot
            let slotMatches = candidates.filter { c in
                switch slot {
                case .weekend:  return c.time >= 60
                case .quick:    return c.time <= 25
                case .leftover: return c.id == "leftovers"
                default:        return c.time >= 25 && c.time <= 50
                }
            }
            let pool = slotMatches.isEmpty ? candidates : slotMatches

            // Weekend discovery: try a never-rated meal one weekend night.
            let isWeekend = slot == .weekend
            let pick: Meal
            if weekendDiscovery && isWeekend, let unrated = pool.first(where: { ratings[$0.id] == nil }) {
                pick = unrated
            } else {
                // Sort by confidence, then pick randomly from the top 3 so successive
                // taps produce variation instead of always choosing the same winner.
                let sorted = pool.sorted { a, b in
                    Learning.confidence(for: a.id, ratings: ratings)
                        > Learning.confidence(for: b.id, ratings: ratings)
                }
                let topN = Array(sorted.prefix(3))
                pick = topN.randomElement() ?? sorted[0]
            }

            next[i].mealId = pick.id
            used.insert(pick.id)
        }
        return next
    }

    static func validate(week: [DayPlan], rules: Rules) -> [PlanWarning] {
        var warnings: [PlanWarning] = []

        // Per-day freshness check using the multi-shop age model.
        for (idx, day) in week.enumerated() {
            let p = protein(for: meal(byId: day.mealId))
            guard p.perish == .fresh else { continue }
            let age = freshAge(dayIdx: idx, rules: rules)
            if age > rules.meatDays {
                warnings.append(.init(
                    kind: .meatLate,
                    dayIdx: idx,
                    msg: "\(day.day)'s \(p.name) is \(age) days from your last shop — past your \(rules.meatDays)-day fresh limit."
                ))
            }
        }

        for qn in rules.quickNights {
            if let idx = week.firstIndex(where: { $0.day == qn }) {
                let m = meal(byId: week[idx].mealId)
                if m.time > 30 {
                    warnings.append(.init(
                        kind: .slowOnQuick,
                        dayIdx: idx,
                        msg: "\(qn) is a quick night but \(m.title) takes \(m.time)m."
                    ))
                }
            }
        }

        for i in 1..<week.count {
            let a = protein(for: meal(byId: week[i - 1].mealId))
            let b = protein(for: meal(byId: week[i].mealId))
            if a.name == b.name {
                warnings.append(.init(
                    kind: .repeatProtein,
                    dayIdx: i,
                    msg: "\(a.name) two nights in a row (\(week[i - 1].day) → \(week[i].day))."
                ))
            }
        }

        return warnings
    }
}
