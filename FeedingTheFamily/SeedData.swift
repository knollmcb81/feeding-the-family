import Foundation

enum SeedData {
    static let proteins: [String: Protein] = [
        "fresh_chicken": Protein(id: "fresh_chicken", name: "chicken thighs",  perish: .fresh,  aisle: .meat),
        "fresh_chick_b": Protein(id: "fresh_chick_b", name: "chicken breast",  perish: .fresh,  aisle: .meat),
        "fresh_beef":    Protein(id: "fresh_beef",    name: "ground beef",     perish: .fresh,  aisle: .meat),
        "fresh_chuck":   Protein(id: "fresh_chuck",   name: "chuck roast",     perish: .fresh,  aisle: .meat),
        "fresh_steak":   Protein(id: "fresh_steak",   name: "flank steak",     perish: .fresh,  aisle: .meat),
        "fresh_pork":    Protein(id: "fresh_pork",    name: "pork loin",       perish: .fresh,  aisle: .meat),
        "fresh_turkey":  Protein(id: "fresh_turkey",  name: "ground turkey",   perish: .fresh,  aisle: .meat),
        "fresh_bacon":   Protein(id: "fresh_bacon",   name: "bacon",           perish: .fresh,  aisle: .meat),
        "pantry_beans":  Protein(id: "pantry_beans",  name: "black beans",     perish: .pantry, aisle: .pantry),
        "pantry_eggs":   Protein(id: "pantry_eggs",   name: "eggs",            perish: .pantry, aisle: .dairy),
    ]

    static let meals: [Meal] = [
        Meal(id: "daddy-dinner", title: "Daddy dinner (noodles + tomato sauce)", time: 20, kid: true, tags: ["quick","kid"], proteinId: "fresh_beef",
             ings: ing(("ground beef","1 lb",.meat),("marinara","1 jar",.pantry),("spaghetti","1 lb",.pantry),("parmesan","1 wedge",.dairy)),
             steps: ["Boil pasta.","Brown beef, drain.","Stir marinara into beef. Simmer 5 min.","Top pasta with sauce + parm."]),

        Meal(id: "meatloaf", title: "Classic meatloaf", time: 60, kid: true, tags: ["kid","family"], proteinId: "fresh_beef",
             ings: ing(("ground beef","2 lb",.meat),("breadcrumbs","1 cup",.pantry),("eggs","2 ct",.dairy),("ketchup","1 bottle",.pantry),("carrots","1 bag",.produce)),
             steps: ["Oven 375°F.","Mix beef, breadcrumbs, eggs, 1/4 cup ketchup, salt.","Loaf pan. Top with ketchup.","55 min until 160°F.","Roasted carrots on the side."]),

        Meal(id: "meatball-soup", title: "Meatball soup", time: 35, kid: true, tags: ["family","soup"], proteinId: "fresh_beef",
             ings: ing(("ground beef","1 lb",.meat),("beef broth","64 oz",.pantry),("carrots","1 bag",.produce),("celery","1 head",.produce),("orzo","1 cup",.pantry),("parmesan","1 wedge",.dairy)),
             steps: ["Roll beef into 1\" meatballs.","Brown in pot, set aside.","Diced carrots + celery, 5 min.","Add broth, simmer 10 min.","Add orzo + meatballs, 8 min more.","Top with parm."]),

        Meal(id: "taco-bowls", title: "Taco bowls", time: 25, kid: true, tags: ["quick","kid"], proteinId: "fresh_beef",
             ings: ing(("ground beef","1.5 lb",.meat),("rice","2 cups",.pantry),("cheddar","8 oz",.dairy),("salsa","1 jar",.pantry),("black beans","1 can",.pantry),("avocado","3 ct",.produce)),
             steps: ["Start rice.","Brown beef, drain. Season: 1 tsp cumin, 1 tsp chili powder, salt.","Warm beans.","Build bowls: rice, beef, beans, cheese, salsa, avocado."]),

        Meal(id: "burgers", title: "Hamburgers + roasted veg", time: 30, kid: true, tags: ["kid","family"], proteinId: "fresh_beef",
             ings: ing(("ground beef","2 lb",.meat),("burger buns","8 ct",.bakery),("cheddar","8 oz",.dairy),("lettuce","1 head",.produce),("tomato","3 ct",.produce),("zucchini","3 ct",.produce)),
             steps: ["Form 6 patties, salt heavily.","Slice zucchini, toss in oil + salt. Sheet pan, 425°F, 18 min.","Sear patties 3 min/side. Cheese last min.","Toast buns. Assemble."]),

        Meal(id: "hot-dogs", title: "Hot dogs + cucumber salad", time: 15, kid: true, tags: ["quick","kid"], proteinId: "fresh_beef",
             ings: ing(("hot dogs","1 pkg",.meat),("hot dog buns","8 ct",.bakery),("cucumber","3 ct",.produce),("cherry tomatoes","1 pint",.produce)),
             steps: ["Boil or grill dogs.","Toast buns.","Sliced cucumber + tomato, drizzle of olive oil + salt."]),

        Meal(id: "mama-pizza", title: "Mama pizza (homemade)", time: 45, kid: true, tags: ["weekend","kid"], proteinId: "fresh_beef",
             ings: ing(("pizza dough","2 balls",.bakery),("mozzarella","1 lb",.dairy),("marinara","1 jar",.pantry),("pepperoni","1 pkg",.meat),("basil","1 bunch",.produce)),
             steps: ["Oven 500°F. Stone or steel if you have one.","Stretch dough thin.","Sauce, cheese, pepperoni.","8–10 min until charred at edges.","Fresh basil on top."]),

        Meal(id: "nuggets-night", title: "Chicken nuggets night (kid-led)", time: 30, kid: true, tags: ["kid"], proteinId: "fresh_chick_b",
             ings: ing(("chicken breast","1.5 lb",.meat),("breadcrumbs","1 cup",.pantry),("eggs","2 ct",.dairy),("carrots","1 bag",.produce),("ketchup","1 bottle",.pantry)),
             steps: ["Cube chicken.","Egg wash, then breadcrumbs.","Bake 425°F, 15 min, flip halfway.","Carrot sticks + ketchup."]),

        Meal(id: "bbq-sandwich", title: "BBQ chicken sandwiches", time: 30, kid: true, tags: ["kid","crockpot"], proteinId: "fresh_chick_b",
             ings: ing(("chicken breast","2 lb",.meat),("bbq sauce","1 bottle",.pantry),("burger buns","8 ct",.bakery),("coleslaw mix","1 bag",.produce)),
             steps: ["Crockpot: chicken + 1/2 bottle bbq, low 6 hr.","Shred with forks. Stir in more sauce.","Pile on buns. Slaw on top."]),

        Meal(id: "lemon-caper", title: "Lemon caper chicken", time: 30, kid: false, tags: ["weeknight"], proteinId: "fresh_chick_b",
             ings: ing(("chicken breast","1.5 lb",.meat),("lemons","2 ct",.produce),("capers","1 jar",.pantry),("butter","1 stick",.dairy),("rice","2 cups",.pantry),("green beans","1 lb",.produce)),
             steps: ["Pound chicken thin. Salt.","Sear in butter, 3 min/side.","Pan sauce: lemon juice, capers, splash of broth.","Pour over chicken. Rice + green beans on side."]),

        Meal(id: "korean-bowl", title: "Korean chicken bowls", time: 35, kid: false, tags: ["weeknight","asian"], proteinId: "fresh_chicken",
             ings: ing(("chicken thighs","2 lb",.meat),("gochujang","1 tub",.pantry),("rice","2 cups",.pantry),("cucumber","2 ct",.produce),("carrots","1 bag",.produce),("sesame oil","1 bottle",.pantry)),
             steps: ["Marinade: 3 tbsp gochujang, 2 tbsp soy, 1 tbsp sesame, 1 tbsp sugar.","Toss with cubed chicken, 15 min.","Sear hard, 8 min.","Quick pickle cucumber + carrot in rice vinegar.","Build bowls: rice, chicken, pickles."]),

        Meal(id: "red-curry", title: "Red curry chicken", time: 35, kid: false, tags: ["asian"], proteinId: "fresh_chicken",
             ings: ing(("chicken thighs","1.5 lb",.meat),("red curry paste","1 jar",.pantry),("coconut milk","2 cans",.pantry),("bell pepper","2 ct",.produce),("snap peas","1 bag",.produce),("rice","2 cups",.pantry),("basil","1 bunch",.produce)),
             steps: ["Start rice.","Fry 3 tbsp curry paste in oil, 1 min.","Add coconut milk + cubed chicken. Simmer 12 min.","Add peppers + snap peas, 5 min.","Basil on top. Serve over rice."]),

        Meal(id: "turkey-ginger", title: "Turkey ginger bowls", time: 25, kid: false, tags: ["quick","asian"], proteinId: "fresh_turkey",
             ings: ing(("ground turkey","1.5 lb",.meat),("ginger","1 hand",.produce),("garlic","1 head",.produce),("soy sauce","1 bottle",.pantry),("rice","2 cups",.pantry),("broccoli","1 head",.produce)),
             steps: ["Start rice.","Brown turkey. Add 2 tbsp grated ginger, 4 garlic cloves.","3 tbsp soy + 1 tbsp brown sugar. Toss.","Steam broccoli alongside.","Bowls: rice, turkey, broccoli."]),

        Meal(id: "pad-thai", title: "Chicken pad thai", time: 30, kid: false, tags: ["asian"], proteinId: "fresh_chick_b",
             ings: ing(("chicken breast","1 lb",.meat),("rice noodles","1 pkg",.pantry),("eggs","3 ct",.dairy),("bean sprouts","1 bag",.produce),("peanuts","1 bag",.pantry),("lime","3 ct",.produce),("fish sauce","1 bottle",.pantry)),
             steps: ["Soak noodles in hot water 8 min.","Sear sliced chicken 4 min.","Push aside, scramble eggs.","Add noodles + sauce (3 tbsp fish sauce, 2 tbsp brown sugar, 2 tbsp lime).","Toss with sprouts. Top with peanuts + lime."]),

        Meal(id: "lo-mein", title: "Beef lo mein", time: 30, kid: true, tags: ["asian"], proteinId: "fresh_steak",
             ings: ing(("flank steak","1 lb",.meat),("lo mein noodles","1 pkg",.pantry),("bell pepper","2 ct",.produce),("carrots","1 bag",.produce),("cabbage","1/2 head",.produce),("soy sauce","1 bottle",.pantry)),
             steps: ["Slice steak thin against grain. Salt.","Cook noodles per package.","High heat: sear steak 2 min, set aside.","Stir-fry veg 4 min.","Combine + sauce: 3 tbsp soy, 1 tbsp sesame, 1 tsp sugar."]),

        Meal(id: "teriyaki", title: "Chicken teriyaki", time: 30, kid: true, tags: ["asian","kid"], proteinId: "fresh_chick_b",
             ings: ing(("chicken breast","1.5 lb",.meat),("teriyaki sauce","1 bottle",.pantry),("rice","2 cups",.pantry),("broccoli","1 head",.produce),("sesame seeds","1 jar",.pantry)),
             steps: ["Start rice.","Cube chicken. Sear 6 min.","Pour 1/2 cup teriyaki, reduce 3 min.","Steam broccoli.","Plate, sprinkle sesame seeds."]),

        Meal(id: "beef-skillet", title: "Beef + sweet potato skillet", time: 35, kid: true, tags: ["weeknight"], proteinId: "fresh_beef",
             ings: ing(("ground beef","1.5 lb",.meat),("sweet potato","3 ct",.produce),("bell pepper","2 ct",.produce),("paprika","1 jar",.pantry),("eggs","4 ct",.dairy)),
             steps: ["Diced sweet potato in skillet, oil + salt, lid on, 12 min.","Push aside. Brown beef.","Add diced peppers, 1 tsp paprika.","Optional: crack eggs over top, lid on, 4 min."]),

        Meal(id: "french-dip", title: "French dips", time: 30, kid: true, tags: ["crockpot"], proteinId: "fresh_chuck",
             ings: ing(("chuck roast","3 lb",.meat),("beef broth","64 oz",.pantry),("hoagie rolls","6 ct",.bakery),("provolone","1 pkg",.dairy),("garlic","1 head",.produce)),
             steps: ["Crockpot: chuck + broth + 4 garlic cloves + salt. Low 8 hr.","Shred meat, reserve juice (au jus).","Pile on rolls with provolone.","Broil 2 min to melt.","Serve with juice for dipping."]),

        Meal(id: "italian-beef", title: "Crockpot Italian beef", time: 20, kid: true, tags: ["crockpot"], proteinId: "fresh_chuck",
             ings: ing(("chuck roast","3 lb",.meat),("pepperoncini","1 jar",.pantry),("italian seasoning","1 jar",.pantry),("hoagie rolls","6 ct",.bakery),("provolone","1 pkg",.dairy)),
             steps: ["Crockpot: chuck + whole jar pepperoncini (with juice) + 2 tbsp italian seasoning. Low 8 hr.","Shred. Pile on rolls with provolone."]),

        Meal(id: "spicy-tort", title: "Spicy tortellini", time: 25, kid: false, tags: ["quick"], proteinId: "fresh_beef",
             ings: ing(("cheese tortellini","2 pkg",.dairy),("ground beef","1 lb",.meat),("marinara","1 jar",.pantry),("red pepper flakes","1 jar",.pantry),("heavy cream","1 pint",.dairy),("parmesan","1 wedge",.dairy)),
             steps: ["Boil tortellini per package.","Brown beef. Add marinara + 1 tsp red pepper flakes.","Splash of cream. Simmer 3 min.","Toss with tortellini + parm."]),

        Meal(id: "nachos", title: "Loaded nachos", time: 25, kid: true, tags: ["quick","kid"], proteinId: "fresh_beef",
             ings: ing(("ground beef","1 lb",.meat),("tortilla chips","1 bag",.pantry),("cheddar","8 oz",.dairy),("black beans","1 can",.pantry),("salsa","1 jar",.pantry),("avocado","2 ct",.produce),("sour cream","8 oz",.dairy)),
             steps: ["Brown beef + taco seasoning.","Sheet pan: chips, beef, beans, cheese.","Broil 3 min until cheese bubbles.","Top with salsa, avocado, sour cream."]),

        Meal(id: "blts", title: "BLTs + soup", time: 20, kid: true, tags: ["quick"], proteinId: "fresh_bacon",
             ings: ing(("bacon","1 lb",.meat),("sourdough","1 loaf",.bakery),("lettuce","1 head",.produce),("tomato","3 ct",.produce),("mayo","1 jar",.pantry),("tomato soup","2 cans",.pantry)),
             steps: ["Bacon in oven, 400°F, 18 min.","Toast bread.","Heat soup.","Build BLTs."]),

        Meal(id: "pork-loin", title: "Roasted pork loin", time: 60, kid: true, tags: ["family"], proteinId: "fresh_pork",
             ings: ing(("pork loin","3 lb",.meat),("potatoes","2 lb",.produce),("green beans","1 lb",.produce),("rosemary","1 bunch",.produce),("olive oil","1 bottle",.pantry)),
             steps: ["Oven 400°F.","Salt loin heavily. Sear all sides in oven-safe pan.","Surround with quartered potatoes + oil + rosemary.","Roast 35 min until 145°F.","Steam green beans.","Rest meat 10 min before slicing."]),

        Meal(id: "ramen-bowl", title: "Ramen chicken bowls", time: 25, kid: false, tags: ["quick","asian"], proteinId: "fresh_chick_b",
             ings: ing(("chicken breast","1 lb",.meat),("ramen noodles","4 pkg",.pantry),("eggs","4 ct",.dairy),("bok choy","2 heads",.produce),("scallions","1 bunch",.produce),("soy sauce","1 bottle",.pantry)),
             steps: ["Soft boil eggs, 7 min. Ice bath. Peel.","Sear sliced chicken 5 min.","Cook noodles, drain.","Wilt bok choy in pan.","Bowls: noodles, broth (use seasoning), chicken, halved egg, scallions."]),

        Meal(id: "chop-salad", title: "Micro chop salad", time: 20, kid: false, tags: ["quick","salad"], proteinId: "fresh_chick_b",
             ings: ing(("chicken breast","1 lb",.meat),("romaine","2 heads",.produce),("cherry tomatoes","1 pint",.produce),("cucumber","2 ct",.produce),("feta","8 oz",.dairy),("chickpeas","1 can",.pantry),("italian dressing","1 bottle",.pantry)),
             steps: ["Grill or pan-sear chicken. Slice.","Chop everything tiny — same size dice.","Toss with feta, chickpeas, dressing."]),

        Meal(id: "enchiladas", title: "Chicken enchiladas (2-night)", time: 50, kid: true, tags: ["family"], proteinId: "fresh_chick_b",
             ings: ing(("chicken breast","2 lb",.meat),("tortillas","12 ct",.bakery),("enchilada sauce","2 cans",.pantry),("cheddar","1 lb",.dairy),("black beans","1 can",.pantry)),
             steps: ["Poach chicken 18 min, shred.","Mix shredded chicken with 1 can sauce + beans.","Roll in tortillas, place in baking dish.","Top with sauce + cheese.","Bake 375°F, 25 min. (Enough for 2 nights.)"]),

        Meal(id: "korean-beef", title: "Korean beef bowls", time: 25, kid: true, tags: ["quick","asian"], proteinId: "fresh_beef",
             ings: ing(("ground beef","1.5 lb",.meat),("rice","2 cups",.pantry),("soy sauce","1 bottle",.pantry),("brown sugar","1 box",.pantry),("ginger","1 hand",.produce),("garlic","1 head",.produce),("cucumber","2 ct",.produce)),
             steps: ["Start rice.","Brown beef.","Sauce: 1/4 cup soy + 3 tbsp brown sugar + 1 tbsp ginger + 4 garlic cloves.","Pour over beef, reduce 2 min.","Bowls: rice, beef, sliced cucumber."]),

        Meal(id: "leftovers", title: "Leftovers night", time: 5, kid: true, tags: ["leftovers"], proteinId: "pantry_eggs",
             ings: [],
             steps: ["Reheat what's in the fridge.","Toast bread or scramble an egg as filler."]),
    ]

    static let week: [DayPlan] = [
        DayPlan(day: "Mon", date: "May 4",  mealId: "taco-bowls",    locked: false, slot: .cook),
        DayPlan(day: "Tue", date: "May 5",  mealId: "turkey-ginger", locked: true,  slot: .quick),
        DayPlan(day: "Wed", date: "May 6",  mealId: "leftovers",     locked: true,  slot: .leftover),
        DayPlan(day: "Thu", date: "May 7",  mealId: "daddy-dinner",  locked: true,  slot: .quick),
        DayPlan(day: "Fri", date: "May 8",  mealId: "french-dip",    locked: false, slot: .crockpot),
        DayPlan(day: "Sat", date: "May 9",  mealId: "mama-pizza",    locked: false, slot: .weekend),
        DayPlan(day: "Sun", date: "May 10", mealId: "pork-loin",     locked: false, slot: .weekend),
    ]

    static let defaultStaples: [GroceryItem] = [
        GroceryItem(name: "milk",          aisle: .dairy,   qty: ["1 gal"],   meals: [], source: .staple),
        GroceryItem(name: "eggs",          aisle: .dairy,   qty: ["1 dozen"], meals: [], source: .staple),
        GroceryItem(name: "bread",         aisle: .bakery,  qty: ["1 loaf"],  meals: [], source: .staple),
        GroceryItem(name: "bananas",       aisle: .produce, qty: ["1 bunch"], meals: [], source: .staple),
        GroceryItem(name: "baby carrots",  aisle: .produce, qty: ["1 lb"],    meals: [], source: .staple),
        GroceryItem(name: "yogurt cups",   aisle: .dairy,   qty: ["8"],       meals: [], source: .staple),
        GroceryItem(name: "sliced cheese", aisle: .dairy,   qty: ["1 pack"],  meals: [], source: .staple),
        GroceryItem(name: "apples",        aisle: .produce, qty: ["6"],       meals: [], source: .staple),
        GroceryItem(name: "paper towels",  aisle: .pantry,  qty: ["1"],       meals: [], source: .staple),
        GroceryItem(name: "dish soap",     aisle: .pantry,  qty: ["1"],       meals: [], source: .staple),
    ]

    static let rules = Rules(
        meatDays: 4,
        shopDay: "Sun",
        quickNights: ["Tue", "Thu"],
        avoidIngredients: ["onions","onion","mushrooms","mushroom","shrimp","salmon","fish","shellfish"],
        proteinTarget: 140,
        carbStyle: "small",
        weeknightMax: 40,
        householdAdults: 2,
        householdKids: 3,
        pantryHave: ["soy sauce","olive oil","rice","pasta","marinara","salt","pepper","flour","sugar","brown sugar","sesame oil","italian seasoning","red pepper flakes","ketchup","mayo","breadcrumbs","rosemary","paprika","sesame seeds"]
    )

    private static func ing(_ tuples: (String, String, Aisle)...) -> [Ingredient] {
        tuples.map { Ingredient(name: $0.0, qty: $0.1, aisle: $0.2) }
    }
}
