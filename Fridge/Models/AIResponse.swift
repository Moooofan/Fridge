import Foundation

/// AI 回傳的菜單資訊
struct MenuInfo: Codable, Equatable {
    let servings: Int
    let dishesCount: Int
    let soupsCount: Int

    /// 總共幾道料理
    var totalCount: Int {
        dishesCount + soupsCount
    }

    /// 顯示摘要
    var summary: String {
        "\(servings) 人份 / \(dishesCount) 菜 \(soupsCount) 湯"
    }

    // 自定義解碼，支援多種 key 命名方式
    enum CodingKeys: String, CodingKey {
        case servings
        case dishesCount
        case soupsCount
        // 支援 snake_case
        case dishes_count
        case soups_count
    }

    init(servings: Int, dishesCount: Int, soupsCount: Int) {
        self.servings = servings
        self.dishesCount = dishesCount
        self.soupsCount = soupsCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // servings
        self.servings = try container.decodeIfPresent(Int.self, forKey: .servings) ?? 2

        // dishesCount - 嘗試多種 key
        if let count = try? container.decode(Int.self, forKey: .dishesCount) {
            self.dishesCount = count
        } else if let count = try? container.decode(Int.self, forKey: .dishes_count) {
            self.dishesCount = count
        } else {
            self.dishesCount = 2
        }

        // soupsCount - 嘗試多種 key
        if let count = try? container.decode(Int.self, forKey: .soupsCount) {
            self.soupsCount = count
        } else if let count = try? container.decode(Int.self, forKey: .soups_count) {
            self.soupsCount = count
        } else {
            self.soupsCount = 1
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(servings, forKey: .servings)
        try container.encode(dishesCount, forKey: .dishesCount)
        try container.encode(soupsCount, forKey: .soupsCount)
    }
}

/// AI 完整回應結構
struct AIRecipeResponse: Codable, Equatable {
    let menu: MenuInfo
    let recipes: [Recipe]

    init(menu: MenuInfo, recipes: [Recipe]) {
        self.menu = menu
        self.recipes = recipes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // menu 可選，若沒有則根據 recipes 自動計算
        if let menu = try? container.decode(MenuInfo.self, forKey: .menu) {
            self.menu = menu
        } else {
            // 預設值
            self.menu = MenuInfo(servings: 2, dishesCount: 2, soupsCount: 1)
        }

        // recipes 必須有
        self.recipes = try container.decode([Recipe].self, forKey: .recipes)
    }

    enum CodingKeys: String, CodingKey {
        case menu, recipes
    }
}

/// AI 請求參數
struct AIRequestParams {
    let ingredients: [UserIngredient]
    let constraints: MealConstraints
    let preferences: UserPreferences
    let condiments: [String] // 使用者擁有的調味料
    /// 依使用者食材比對出的專業廚師參考食譜（由 OpenAIService 於送出請求前填入）
    var referenceRecipes: [CuratedRecipe] = []

    init(ingredients: [UserIngredient], constraints: MealConstraints, preferences: UserPreferences, condiments: [String] = []) {
        self.ingredients = ingredients
        self.constraints = constraints
        self.preferences = preferences
        self.condiments = condiments
    }

    /// 產生完整 prompt
    func buildPrompt() -> String {
        let ingredientList = ingredients.map { "- \($0.name)" }.joined(separator: "\n")

        // 調味料列表
        let condimentSection: String
        if condiments.isEmpty {
            condimentSection = "（未設定，請使用常見調味料）"
        } else {
            condimentSection = condiments.joined(separator: "、")
        }

        let prompt = """
        你是一位專業的家庭料理顧問，專門幫助使用者「清冰箱」。
        使用者會提供現有的食材清單，你需要根據這些食材推薦合適的料理組合。

        【使用者現有食材】
        \(ingredientList)

        【使用者擁有的調味料】
        \(condimentSection)

        【用餐條件】
        \(constraints.promptDescription)

        【使用者偏好】
        \(preferences.promptDescription)

        【重要規則】
        1. 只輸出 JSON，不要任何其他文字或 markdown 標記
        2. recipes 總數必須等於 dishesCount + soupsCount
        3. 優先使用現有食材；若食材不足，在 ingredients 中標示 optional: true 或提供 substitutes
        4. 清冰箱導向：盡量消耗現有食材、融合多種食材、減少額外採買
        5. 調味料請優先使用使用者擁有的調味料，若需要使用者沒有的調味料，請在 tips 中說明可替代方案
        6. menu 中的 servings / dishesCount / soupsCount 必須是數字（即使使用者沒填，你也要合理決定並填入）
        7. 所有文字內容請使用繁體中文
        8. 【必須使用的食材，逐一檢查】「使用者現有食材」清單中的每一項，都必須至少出現在某一道菜或湯的 ingredients 裡；
           盡量把不同食材分散到不同道菜（不要把所有食材都塞進同一道），除非某項食材明顯不可能入菜（例如非食用品）才可以省略——
           省略時請在該食材對應的推薦理由或 tips 稍微說明為什麼。生成完成後請自行核對：清單裡的每一項食材是否都用到了。

        【回傳 JSON 格式】
        {
          "menu": {
            "servings": 2,
            "dishesCount": 2,
            "soupsCount": 1
          },
          "recipes": [
            {
              "type": "dish",
              "title": "料理名稱",
              "reason": "推薦這道料理的原因",
              "timeMinutes": 15,
              "difficulty": "easy",
              "servings": 2,
              "ingredients": [
                {
                  "name": "食材名稱",
                  "amount": "用量"
                }
              ],
              "steps": ["步驟1", "步驟2"],
              "tips": ["小技巧1"],
              "source": null
            }
          ]
        }

        請根據以上規則，推薦適合的料理組合。
        """

        if referenceRecipes.isEmpty {
            return prompt + "\n\n## 專業廚師參考食譜庫\n（參考庫無符合食譜，請依台灣家常作法設計）"
        }

        let refsText = referenceRecipes.map { $0.promptSummary }.joined(separator: "\n\n")
        return prompt + "\n\n## 專業廚師參考食譜庫\n" + refsText
    }
}
