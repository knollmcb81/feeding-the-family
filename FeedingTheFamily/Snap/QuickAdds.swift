import Foundation

/// Common cooking additions the AI typically misses. Used in the result sheet
/// "+ Add what I cooked with" chip row so the user can fold them into totals.
struct QuickAddItem: Identifiable, Hashable {
    let id: UUID = UUID()
    let name: String
    let qty: String
    let kcal: Int
    let protein: Double
    let carbs: Double
    let fat: Double
}

enum QuickAdds {
    static let items: [QuickAddItem] = [
        QuickAddItem(name: "butter",       qty: "1 tbsp",  kcal: 100, protein: 0, carbs: 0,  fat: 11),
        QuickAddItem(name: "heavy cream",  qty: "2 tbsp",  kcal: 100, protein: 1, carbs: 1,  fat: 11),
        QuickAddItem(name: "olive oil",    qty: "1 tbsp",  kcal: 120, protein: 0, carbs: 0,  fat: 14),
        QuickAddItem(name: "cheese",       qty: "1 oz",    kcal: 110, protein: 7, carbs: 0,  fat: 9),
        QuickAddItem(name: "sour cream",   qty: "2 tbsp",  kcal: 60,  protein: 1, carbs: 1,  fat: 6),
        QuickAddItem(name: "mayo",         qty: "1 tbsp",  kcal: 90,  protein: 0, carbs: 0,  fat: 10),
        QuickAddItem(name: "rice (extra)", qty: "½ cup",   kcal: 110, protein: 2, carbs: 24, fat: 0),
        QuickAddItem(name: "bread",        qty: "1 slice", kcal: 80,  protein: 3, carbs: 15, fat: 1),
    ]
}
