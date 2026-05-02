import Foundation

struct RestaurantMenuItem: Identifiable, Hashable {
    let id: UUID = UUID()
    let name: String
    let qty: String
    let kcal: Int
    let protein: Double
    let carbs: Double
    let fat: Double
}

struct RestaurantChain: Identifiable, Hashable {
    let id: UUID = UUID()
    let name: String
    let items: [RestaurantMenuItem]
}

enum RestaurantData {
    /// Keyed by SnapFixture.title. Returns chain + menu candidates for that dish.
    static let guesses: [String: [RestaurantChain]] = [
        "Dinner plate": [
            RestaurantChain(name: "Cava", items: [
                .init(name: "Grilled chicken bowl, greens base", qty: "regular", kcal: 540, protein: 42, carbs: 38, fat: 22),
                .init(name: "Harissa chicken bowl, rice base",   qty: "regular", kcal: 680, protein: 44, carbs: 62, fat: 26),
                .init(name: "Lamb meatball bowl",                qty: "regular", kcal: 740, protein: 38, carbs: 54, fat: 38),
            ]),
            RestaurantChain(name: "Sweetgreen", items: [
                .init(name: "Harvest bowl",       qty: "regular", kcal: 705, protein: 30, carbs: 64, fat: 38),
                .init(name: "Hummus crunch bowl", qty: "regular", kcal: 695, protein: 25, carbs: 72, fat: 32),
            ]),
        ],
        "Pasta bowl": [
            RestaurantChain(name: "Olive Garden", items: [
                .init(name: "Cheese ravioli, marinara",   qty: "lunch",  kcal: 480, protein: 22, carbs: 58,  fat: 16),
                .init(name: "Fettuccine alfredo",         qty: "lunch",  kcal: 660, protein: 22, carbs: 58,  fat: 38),
                .init(name: "Chicken alfredo",            qty: "dinner", kcal: 1480, protein: 65, carbs: 92, fat: 88),
            ]),
            RestaurantChain(name: "Cheesecake Factory", items: [
                .init(name: "Pasta da Vinci",             qty: "lunch", kcal: 1410, protein: 50, carbs: 110, fat: 72),
                .init(name: "Pasta carbonara w/ chicken", qty: "lunch", kcal: 1840, protein: 78, carbs: 92,  fat: 110),
            ]),
        ],
        "Taco plate": [
            RestaurantChain(name: "Chipotle", items: [
                .init(name: "Steak tacos, soft (3)",        qty: "regular", kcal: 620, protein: 36, carbs: 58, fat: 26),
                .init(name: "Carnitas tacos (3)",           qty: "regular", kcal: 690, protein: 32, carbs: 56, fat: 32),
                .init(name: "Chicken bowl, brown rice",     qty: "regular", kcal: 705, protein: 45, carbs: 70, fat: 22),
            ]),
            RestaurantChain(name: "Taco Bell", items: [
                .init(name: "Crunchy taco supreme (2)", qty: "regular", kcal: 380, protein: 16, carbs: 30, fat: 22),
                .init(name: "Beef burrito supreme",     qty: "regular", kcal: 430, protein: 17, carbs: 51, fat: 17),
            ]),
        ],
    ]
}
