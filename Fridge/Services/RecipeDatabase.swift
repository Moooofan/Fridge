import Foundation

/// 內建精選食譜資料庫的載入與比對邏輯
final class RecipeDatabase {
    static let shared = RecipeDatabase()

    /// 精選食譜清單：以鎖保護的延遲載入，只解析一次，且對多執行緒安全（避免 `lazy var` 在並發首次存取下的資料競爭）
    private let lock = NSLock()
    private var cachedRecipes: [CuratedRecipe]?

    var recipes: [CuratedRecipe] {
        lock.lock()
        defer { lock.unlock() }
        if let cached = cachedRecipes { return cached }
        let loaded = Self.loadRecipes()
        cachedRecipes = loaded
        return loaded
    }

    private init() {}

    /// 在背景執行緒預先觸發載入，讓 App 啟動時 CuratedRecipes.json 的解析不會卡在主執行緒的第一次存取上
    func preload() {
        Task.detached(priority: .utility) {
            _ = RecipeDatabase.shared.recipes
        }
    }

    private static func loadRecipes() -> [CuratedRecipe] {
        guard let url = Bundle.main.url(forResource: "CuratedRecipes", withExtension: "json") else {
            #if DEBUG
            print("⚠️ RecipeDatabase: 找不到 CuratedRecipes.json")
            #endif
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([CuratedRecipe].self, from: data)
        } catch {
            #if DEBUG
            print("⚠️ RecipeDatabase: 載入食譜資料庫失敗：\(error)")
            #endif
            return []
        }
    }

    // MARK: - Normalization

    /// 食材同義詞對照表（可持續擴充）
    private static let synonymTable: [String: String] = [
        "蛋": "雞蛋", "雞蛋": "雞蛋", "土雞蛋": "雞蛋",
        "蔥": "青蔥", "青蔥": "青蔥", "蔥段": "青蔥",
        "蒜": "蒜頭", "大蒜": "蒜頭", "蒜頭": "蒜頭", "蒜瓣": "蒜頭",
        "五花": "豬五花", "五花肉": "豬五花", "豬五花": "豬五花",
        "絞肉": "豬絞肉", "豬絞肉": "豬絞肉",
        "里肌": "豬里肌", "里肌肉": "豬里肌", "豬里肌": "豬里肌",
        "梅花肉": "豬梅花", "豬梅花": "豬梅花",
        "排骨": "豬排骨", "豬排骨": "豬排骨",
        "番茄": "番茄", "西紅柿": "番茄", "蕃茄": "番茄",
        "馬鈴薯": "馬鈴薯", "土豆": "馬鈴薯", "洋芋": "馬鈴薯",
        "高麗菜": "高麗菜", "包心菜": "高麗菜", "甘藍": "高麗菜",
        "青花菜": "青花菜", "綠花椰": "青花菜", "西蘭花": "青花菜",
        "花椰菜": "花椰菜", "白花椰": "花椰菜",
        "雞腿肉": "雞腿", "去骨雞腿": "雞腿", "雞腿": "雞腿",
        "雞胸": "雞胸肉", "雞胸肉": "雞胸肉",
        "蝦": "白蝦", "蝦子": "白蝦", "白蝦": "白蝦",
        "豆腐": "板豆腐",
        "紅蘿蔔": "紅蘿蔔", "胡蘿蔔": "紅蘿蔔",
        "白蘿蔔": "白蘿蔔", "蘿蔔": "白蘿蔔",
        "香菇": "香菇", "乾香菇": "香菇", "鮮香菇": "香菇",
        "木耳": "木耳", "黑木耳": "木耳",
        "牛肉": "牛肉片", "牛肉片": "牛肉片",
        "玉米": "玉米", "甜玉米": "玉米",
        "小黃瓜": "小黃瓜", "黃瓜": "小黃瓜"
    ]

    /// 正規化食材名稱：去空白、轉小寫、套用同義詞表
    static func normalize(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let noSpaces = trimmed.replacingOccurrences(of: " ", with: "")
        if let canonical = synonymTable[noSpaces] {
            return canonical
        }
        return noSpaces
    }

    /// 判斷使用者食材與食譜食材是否視為同一項
    static func matches(_ userItem: String, _ recipeItem: String) -> Bool {
        let a = normalize(userItem)
        let b = normalize(recipeItem)
        guard !a.isEmpty, !b.isEmpty else { return false }
        if a == b { return true }
        if a.count >= 2 && b.count >= 2 && (a.contains(b) || b.contains(a)) {
            return true
        }
        return false
    }

    // MARK: - Matching

    struct ScoredRecipe {
        let recipe: CuratedRecipe
        let score: Double
        let matchedMain: [String]
        let matchedOther: [String]
    }

    /// 判斷食譜是否含有任一排除詞（過敏原/不喜歡的食材），比對名稱與主/配食材
    private static func isExcluded(_ recipe: CuratedRecipe, excluded: [String]) -> Bool {
        guard !excluded.isEmpty else { return false }
        let names = [recipe.name] + recipe.mainIngredients.map { $0.name } + recipe.otherIngredients.map { $0.name }
        return excluded.contains { term in
            names.contains { matches(term, $0) }
        }
    }

    /// 依使用者食材/調味料為所有精選食譜評分，回傳分數最高的前 limit 筆
    /// - Parameters:
    ///   - excluded: 過敏原/不喜歡的食材，符合的食譜（依名稱或主/配食材比對）會被排除
    ///   - preferFast: 分數相同時，是否優先選擇標記「快速」的食譜（供早餐情境使用）
    func match(userIngredients: [String], condiments: [String], limit: Int, excluding excluded: [String] = [], preferFast: Bool = false) -> [ScoredRecipe] {
        var scored: [ScoredRecipe] = []

        for recipe in recipes {
            if Self.isExcluded(recipe, excluded: excluded) { continue }

            let matchedMain = recipe.mainIngredients
                .map { $0.name }
                .filter { mainName in userIngredients.contains { Self.matches($0, mainName) } }

            guard !matchedMain.isEmpty else { continue }

            let matchedOther = recipe.otherIngredients
                .map { $0.name }
                .filter { otherName in userIngredients.contains { Self.matches($0, otherName) } }

            let matchedSeasoningsCount = recipe.seasonings
                .filter { seasoning in condiments.contains { Self.matches($0, seasoning.name) } }
                .count

            var score = 3.0 * Double(matchedMain.count)
                + 1.0 * Double(matchedOther.count)
                + 0.25 * Double(matchedSeasoningsCount)

            if matchedMain.count == recipe.mainIngredients.count {
                score += 2.0
            }

            scored.append(ScoredRecipe(recipe: recipe, score: score, matchedMain: matchedMain, matchedOther: matchedOther))
        }

        scored.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if preferFast {
                let lhsFast = lhs.recipe.tags.contains("快速")
                let rhsFast = rhs.recipe.tags.contains("快速")
                if lhsFast != rhsFast { return lhsFast }
            }
            return lhs.recipe.timeMinutes < rhs.recipe.timeMinutes
        }

        return Array(scored.prefix(limit))
    }

    /// 挑選前 N 道菜與前 M 道湯，盡量避免兩道菜共用同一個主要（第一個）主食材
    /// - Parameters:
    ///   - excluded: 過敏原/不喜歡的食材，符合的食譜不會被選入
    ///   - preferFast: 分數相同時，是否優先選擇標記「快速」的食譜（供早餐情境使用）
    func pick(userIngredients: [String], condiments: [String], dishes: Int, soups: Int, excluding excluded: [String] = [], preferFast: Bool = false) -> (dishes: [ScoredRecipe], soups: [ScoredRecipe]) {
        let allMatches = match(userIngredients: userIngredients, condiments: condiments, limit: recipes.count, excluding: excluded, preferFast: preferFast)

        let dishMatches = allMatches.filter { !$0.recipe.isSoup }
        let soupMatches = allMatches.filter { $0.recipe.isSoup }

        return (
            dishes: selectDiverse(from: dishMatches, count: dishes),
            soups: selectDiverse(from: soupMatches, count: soups)
        )
    }

    /// 依分數高低挑選，若還有替代方案就避開與已選項目相同的主要主食材
    private func selectDiverse(from candidates: [ScoredRecipe], count: Int) -> [ScoredRecipe] {
        guard count > 0 else { return [] }

        var selected: [ScoredRecipe] = []
        var usedPrimaryIngredients = Set<String>()
        var remaining = candidates

        var index = 0
        while selected.count < count && index < remaining.count {
            let candidate = remaining[index]
            let primary = candidate.recipe.mainIngredients.first.map { RecipeDatabase.normalize($0.name) }
            if let primary, usedPrimaryIngredients.contains(primary) {
                index += 1
                continue
            }
            selected.append(candidate)
            if let primary { usedPrimaryIngredients.insert(primary) }
            remaining.remove(at: index)
        }

        var fillIndex = 0
        while selected.count < count && fillIndex < remaining.count {
            selected.append(remaining[fillIndex])
            fillIndex += 1
        }

        return selected
    }
}
