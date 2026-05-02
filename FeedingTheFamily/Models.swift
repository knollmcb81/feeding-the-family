import Foundation

enum Perish: String, Codable { case fresh, frozen, pantry }
enum Aisle: String, CaseIterable, Codable {
    case produce, meat, dairy, bakery, pantry, frozen
    var label: String {
        switch self {
        case .produce: return "Produce"
        case .meat:    return "Meat"
        case .dairy:   return "Dairy & Eggs"
        case .bakery:  return "Bakery"
        case .pantry:  return "Pantry"
        case .frozen:  return "Frozen"
        }
    }
}

struct Protein: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let perish: Perish
    let aisle: Aisle
}

struct Ingredient: Hashable, Identifiable, Codable {
    var id: String { "\(name)|\(aisle.rawValue)|\(qty)" }
    let name: String
    let qty: String
    let aisle: Aisle
}

struct Meal: Identifiable, Hashable, Codable {
    let id: String
    var title: String
    var time: Int
    var kid: Bool
    var tags: [String]
    var proteinId: String
    var ings: [Ingredient]
    var steps: [String]
}

enum DaySlot: String, Codable { case cook, quick, leftover, crockpot, weekend }

struct DayPlan: Identifiable, Hashable, Codable {
    var id: String { day }
    let day: String
    let date: String
    var mealId: String
    var locked: Bool
    var slot: DaySlot
}

struct Rules: Codable {
    var meatDays: Int
    var shopDay: String
    /// Optional mid-week top-up day. Items bought here reset the freshness
    /// window for late-week meals (e.g. shop Sun + top-up Wed = no fresh-meat
    /// violations all week long with meatDays=4).
    var topUpDay: String? = nil
    var quickNights: [String]
    var avoidIngredients: [String]
    var proteinTarget: Int
    var carbStyle: String
    var weeknightMax: Int
    var householdAdults: Int
    var householdKids: Int
    var pantryHave: Set<String>
}
