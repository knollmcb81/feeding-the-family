import Foundation

struct SnapItem: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let qty: String
    let kcal: Int
    let protein: Double
    let carbs: Double
    let fat: Double

    init(name: String, qty: String, kcal: Int, protein: Double, carbs: Double, fat: Double) {
        self.id = UUID()
        self.name = name
        self.qty = qty
        self.kcal = kcal
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }
}

struct SnapFixture: Identifiable {
    let id: UUID = UUID()
    let title: String
    let confidence: Int
    let items: [SnapItem]
    /// Where this came from — drives the "DEMO" vs "AI" tag on the result sheet.
    var source: Source = .demo
    enum Source { case demo, ai }
}

struct SnapEntry: Identifiable, Hashable, Codable {
    let id: UUID
    let timestamp: Date
    let title: String
    let kcal: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let assignedToMealId: String?
    let savedAsInspiration: Bool
    /// Detected items kept so Ideas detail / Generate-recipe has source data.
    let items: [SnapItem]
    /// Stable index used to pick a gradient palette for the inspiration card.
    let paletteIdx: Int

    init(timestamp: Date, title: String, kcal: Int, protein: Int, carbs: Int, fat: Int,
         assignedToMealId: String?, savedAsInspiration: Bool, items: [SnapItem], paletteIdx: Int) {
        self.id = UUID()
        self.timestamp = timestamp
        self.title = title
        self.kcal = kcal
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.assignedToMealId = assignedToMealId
        self.savedAsInspiration = savedAsInspiration
        self.items = items
        self.paletteIdx = paletteIdx
    }

    static func == (lhs: SnapEntry, rhs: SnapEntry) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum SnapFixtures {
    static let all: [SnapFixture] = [
        SnapFixture(
            title: "Dinner plate",
            confidence: 92,
            items: [
                SnapItem(name: "grilled chicken thigh", qty: "~5 oz",    kcal: 280, protein: 32, carbs: 0,  fat: 16),
                SnapItem(name: "roasted potatoes",      qty: "~1 cup",   kcal: 165, protein: 4,  carbs: 28, fat: 5),
                SnapItem(name: "green beans",           qty: "~3/4 cup", kcal: 35,  protein: 2,  carbs: 8,  fat: 0),
                SnapItem(name: "olive oil drizzle",     qty: "~1 tsp",   kcal: 40,  protein: 0,  carbs: 0,  fat: 4.5),
            ]
        ),
        SnapFixture(
            title: "Pasta bowl",
            confidence: 88,
            items: [
                SnapItem(name: "pesto pasta",  qty: "~1.5 cups", kcal: 420, protein: 12, carbs: 58, fat: 16),
                SnapItem(name: "parmesan",     qty: "~2 tbsp",   kcal: 45,  protein: 4,  carbs: 0,  fat: 3),
                SnapItem(name: "frozen peas",  qty: "~1/2 cup",  kcal: 60,  protein: 4,  carbs: 11, fat: 0),
            ]
        ),
        SnapFixture(
            title: "Taco plate",
            confidence: 85,
            items: [
                SnapItem(name: "beef tacos (2)",   qty: "2 medium", kcal: 380, protein: 22, carbs: 28, fat: 18),
                SnapItem(name: "shredded cheddar", qty: "~2 tbsp",  kcal: 55,  protein: 3,  carbs: 0,  fat: 4.5),
                SnapItem(name: "salsa",            qty: "~3 tbsp",  kcal: 15,  protein: 0,  carbs: 3,  fat: 0),
                SnapItem(name: "avocado",          qty: "~1/4",     kcal: 80,  protein: 1,  carbs: 4,  fat: 7),
            ]
        ),
    ]

    /// Cycles through the fixtures per snap (since the v0 has no real Vision).
    static func next(after lastIdx: Int) -> (idx: Int, fixture: SnapFixture) {
        let idx = (lastIdx + 1) % all.count
        return (idx, all[idx])
    }
}

enum PortionStep: Double, CaseIterable, Identifiable {
    case half  = 0.5
    case threeQ = 0.75
    case one   = 1.0
    case oneAndHalf = 1.5
    case two   = 2.0

    var id: String { label }
    var label: String {
        switch self {
        case .half:        return "½"
        case .threeQ:      return "¾"
        case .one:         return "1×"
        case .oneAndHalf:  return "1½×"
        case .two:         return "2×"
        }
    }
}
