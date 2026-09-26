import Foundation

/// 離線備援服務：不呼叫任何網路 API，完全依賴內建精選食譜資料庫產生推薦
final class LocalRecipeService: AIService {
    private let database: RecipeDatabase

    init(database: RecipeDatabase = .shared) {
        self.database = database
    }

    func generateRecipes(params: AIRequestParams) async throws -> AIRecipeResponse {
        guard !database.recipes.isEmpty else {
            throw AIServiceError.apiError("內建食譜資料庫是空的，暫時無法離線推薦")
        }

        let servings = params.constraints.servings ?? 2
        let dishesCount = params.constraints.dishesCount ?? 2
        let soupsCount = params.constraints.soupsCount ?? 1
        let userIngredientNames = params.ingredients.map { $0.name }
        let excludedTerms = params.preferences.allergies + params.preferences.dislikes
        let preferFast = params.constraints.mealType == .breakfast
        let condiments = params.condiments
        let db = database

        // 比對與組裝食譜是 CPU 密集工作，丟到背景執行緒跑，避免卡住主執行緒
        let recipes: [Recipe] = await Task.detached(priority: .userInitiated) {
            let picked = db.pick(
                userIngredients: userIngredientNames,
                condiments: condiments,
                dishes: dishesCount,
                soups: soupsCount,
                excluding: excludedTerms,
                preferFast: preferFast
            )

            var recipes: [Recipe] = []
            recipes.append(contentsOf: LocalRecipeService.buildRecipes(from: picked.dishes, servings: servings))
            recipes.append(contentsOf: LocalRecipeService.buildRecipes(from: picked.soups, servings: servings))

            let missingDishes = dishesCount - picked.dishes.count
            if missingDishes > 0 {
                recipes.append(contentsOf: LocalRecipeService.fillerRecipes(database: db, excluding: recipes, isSoup: false, count: missingDishes, excludedTerms: excludedTerms, servings: servings))
            }

            let missingSoups = soupsCount - picked.soups.count
            if missingSoups > 0 {
                recipes.append(contentsOf: LocalRecipeService.fillerRecipes(database: db, excluding: recipes, isSoup: true, count: missingSoups, excludedTerms: excludedTerms, servings: servings))
            }

            return recipes
        }.value

        return AIRecipeResponse(
            menu: MenuInfo(servings: servings, dishesCount: dishesCount, soupsCount: soupsCount),
            recipes: recipes
        )
    }

    /// 依比對結果組成 Recipe，份量依 servings 縮放，reason 說明用了哪些冰箱食材與參考食譜來源
    private static func buildRecipes(from scored: [RecipeDatabase.ScoredRecipe], servings: Int) -> [Recipe] {
        scored.map { item in
            let matchedNames = item.matchedMain + item.matchedOther
            let usedText = matchedNames.isEmpty ? "你的食材" : matchedNames.joined(separator: "、")
            // 來源已由卡片的「參考：」列顯示，理由只講用了哪些食材
            let reason = "用到你冰箱裡的：\(usedText)"
            return item.recipe.scaled(to: servings).toRecipe(reason: reason)
        }
    }

    /// 當比對結果不足以湊齊需求道數時，用資料庫中標記「快速」的食譜補足（不論是否比對到食材），並排除過敏原/不喜歡的食材，份量依 servings 縮放
    private static func fillerRecipes(database: RecipeDatabase, excluding existing: [Recipe], isSoup: Bool, count: Int, excludedTerms: [String], servings: Int) -> [Recipe] {
        let existingTitles = Set(existing.map { $0.title })
        let candidates = database.recipes
            .filter { $0.isSoup == isSoup && !existingTitles.contains($0.name) }
            .filter { recipe in
                guard !excludedTerms.isEmpty else { return true }
                let names = [recipe.name] + recipe.mainIngredients.map { $0.name } + recipe.otherIngredients.map { $0.name }
                return !excludedTerms.contains { term in names.contains { RecipeDatabase.matches(term, $0) } }
            }
            .sorted { lhs, rhs in
                let lhsFast = lhs.tags.contains("快速")
                let rhsFast = rhs.tags.contains("快速")
                if lhsFast != rhsFast { return lhsFast }
                return lhs.timeMinutes < rhs.timeMinutes
            }

        return candidates.prefix(count).map { $0.scaled(to: servings).toRecipe(reason: "補充建議") }
    }
}
