import Foundation

/// 單次用餐規劃的歷史紀錄
struct MealHistory: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let createdAt: Date
    let constraints: MealConstraints
    let ingredients: [UserIngredient]
    let menu: MenuInfo
    let recipes: [Recipe]

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        constraints: MealConstraints,
        ingredients: [UserIngredient],
        menu: MenuInfo,
        recipes: [Recipe]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.constraints = constraints
        self.ingredients = ingredients
        self.menu = menu
        self.recipes = recipes
    }

    // Hashable 實作（用 id 來做 hash）
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// 日期顯示格式
    var dateDisplay: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.dateFormat = "M/d (E) HH:mm"
        return formatter.string(from: createdAt)
    }

    /// 用餐日期顯示
    var mealDateDisplay: String? {
        constraints.mealDescription
    }

    /// 摘要文字
    var summary: String {
        let recipeNames = recipes.prefix(2).map { $0.title }.joined(separator: "、")
        if recipes.count > 2 {
            return "\(recipeNames) 等 \(recipes.count) 道"
        }
        return recipeNames
    }

    /// 食材數量
    var ingredientCount: Int {
        ingredients.count
    }
}
