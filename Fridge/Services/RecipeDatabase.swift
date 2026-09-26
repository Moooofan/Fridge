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
        "牛肉": "牛肉片", "牛肉片": "牛肉片", "牛肉絲": "牛肉片", "牛肉塊": "牛肉片",
        "牛腩": "牛肉片", "牛肋條": "牛肉片",
        "玉米": "玉米", "甜玉米": "玉米",
        "小黃瓜": "小黃瓜", "黃瓜": "小黃瓜",
        "中卷": "透抽", "小卷": "透抽", "透抽": "透抽",
        "蛤蜊": "蛤蜊", "蛤仔": "蛤蜊", "文蛤": "蛤蜊",
        "蚵仔": "蚵仔", "蚵": "蚵仔", "牡蠣": "蚵仔",
        "鮭魚": "鮭魚", "三文魚": "鮭魚",
        "豆干": "豆干", "豆乾": "豆干",
        "白菜": "大白菜", "大白菜": "大白菜",
        "蘑菇": "蘑菇", "洋菇": "蘑菇",
        "冬粉": "冬粉", "粉絲": "冬粉",
        "泡菜": "韓式泡菜", "韓式泡菜": "韓式泡菜",
        "白飯": "白飯", "飯": "白飯", "米飯": "白飯", "隔夜飯": "白飯",
        "義大利麵": "義大利麵", "義大利麵條": "義大利麵", "pasta": "義大利麵"
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

    /// 依「盡量涵蓋使用者輸入的每一項食材」為優先目標，從總分排序結果中挑出前 `limit` 筆，
    /// 而不是單純取總分最高的前 N 筆——分數最高的食譜常常互相重疊（同一批主食材），
    /// 若只看總分，較冷門、只出現在少數食譜裡的食材可能整批被排除在參考庫之外，
    /// 導致 AI 依「以參考庫為基礎」的規則生成菜單時，那樣食材完全沒被用到。
    /// 用於 `OpenAIService` 組 prompt 用的參考食譜庫。
    /// - Parameters:
    ///   - excluded: 過敏原/不喜歡的食材，符合的食譜會被排除
    func matchCoveringAllIngredients(userIngredients: [String], condiments: [String], limit: Int, excluding excluded: [String] = []) -> [ScoredRecipe] {
        let all = match(userIngredients: userIngredients, condiments: condiments, limit: recipes.count, excluding: excluded)
        guard !all.isEmpty else { return [] }

        var uncovered = Set(userIngredients.map { Self.normalize($0) })
        var selected: [ScoredRecipe] = []
        var selectedTitles = Set<String>()

        // 貪婪演算法：每一輪選出「還能涵蓋最多尚未涵蓋食材」的食譜；同樣涵蓋數時取總分較高者
        while !uncovered.isEmpty && selected.count < limit {
            var best: ScoredRecipe?
            var bestNewCoverage = 0
            for candidate in all where !selectedTitles.contains(candidate.recipe.name) {
                let matchedNames = (candidate.matchedMain + candidate.matchedOther).map { Self.normalize($0) }
                let newCoverage = uncovered.intersection(matchedNames).count
                guard newCoverage > 0 else { continue }
                if newCoverage > bestNewCoverage || (newCoverage == bestNewCoverage && candidate.score > (best?.score ?? -1)) {
                    best = candidate
                    bestNewCoverage = newCoverage
                }
            }
            guard let picked = best else { break } // 沒有任何食譜還能涵蓋剩下的食材，就此打住
            selected.append(picked)
            selectedTitles.insert(picked.recipe.name)
            let matchedNames = (picked.matchedMain + picked.matchedOther).map { Self.normalize($0) }
            uncovered.subtract(matchedNames)
        }

        // 名額還有剩，用原本「整體最相關」的總分排序補滿
        for candidate in all where selected.count < limit && !selectedTitles.contains(candidate.recipe.name) {
            selected.append(candidate)
            selectedTitles.insert(candidate.recipe.name)
        }

        return selected
    }

    /// 檢查回應中的食譜是否完全沒用到使用者輸入的某些食材（比對食譜標題與食材名稱），
    /// 過敏原/不喜歡的食材會被視為「本來就該排除」而不算漏掉。
    /// 供 `OpenAIService` 判斷要不要多重試一次，以及畫面上提示使用者哪些食材沒被用到。
    static func unusedIngredients(in response: AIRecipeResponse, userIngredients: [String], excluding excluded: [String] = []) -> [String] {
        let recipeNames = response.recipes.flatMap { recipe in [recipe.title] + recipe.ingredients.map { $0.name } }
        return userIngredients.filter { ingredient in
            guard !excluded.contains(where: { matches($0, ingredient) }) else { return false }
            return !recipeNames.contains { matches(ingredient, $0) }
        }
    }

    /// 挑選前 N 道菜與前 M 道湯：以「涵蓋使用者輸入的每一項食材」為第一優先（貪婪演算法），
    /// 同樣涵蓋數時優先避開與已選項目相同的主要（第一個）主食材，最後才比總分。
    /// 菜和湯共用同一份「已涵蓋食材」狀態（先選菜、再選湯補剩下的），讓固定的道數盡量涵蓋到每一種食材。
    /// - Parameters:
    ///   - excluded: 過敏原/不喜歡的食材，符合的食譜不會被選入
    ///   - preferFast: 分數相同時，是否優先選擇標記「快速」的食譜（供早餐情境使用）
    func pick(userIngredients: [String], condiments: [String], dishes: Int, soups: Int, excluding excluded: [String] = [], preferFast: Bool = false) -> (dishes: [ScoredRecipe], soups: [ScoredRecipe]) {
        let allMatches = match(userIngredients: userIngredients, condiments: condiments, limit: recipes.count, excluding: excluded, preferFast: preferFast)

        let dishMatches = allMatches.filter { !$0.recipe.isSoup }
        let soupMatches = allMatches.filter { $0.recipe.isSoup }

        var uncovered = Set(userIngredients.map { Self.normalize($0) })
        let pickedDishes = selectCoveringIngredients(from: dishMatches, count: dishes, uncovered: &uncovered)
        let pickedSoups = selectCoveringIngredients(from: soupMatches, count: soups, uncovered: &uncovered)

        return (dishes: pickedDishes, soups: pickedSoups)
    }

    /// 貪婪挑選：優先選「還能涵蓋最多尚未涵蓋食材」的食譜；`uncovered` 會被就地更新並跨菜/湯共用，
    /// 涵蓋數相同時優先選還沒用過的主要主食材（維持菜色多樣性），最後才比總分。
    private func selectCoveringIngredients(from candidates: [ScoredRecipe], count: Int, uncovered: inout Set<String>) -> [ScoredRecipe] {
        guard count > 0 else { return [] }

        var selected: [ScoredRecipe] = []
        var usedPrimaryIngredients = Set<String>()
        var remaining = candidates

        while selected.count < count && !remaining.isEmpty {
            var bestIndex = 0
            for index in remaining.indices where index != 0 {
                if isBetterPick(remaining[index], than: remaining[bestIndex], uncovered: uncovered, usedPrimary: usedPrimaryIngredients) {
                    bestIndex = index
                }
            }

            let picked = remaining.remove(at: bestIndex)
            let matchedNames = (picked.matchedMain + picked.matchedOther).map { Self.normalize($0) }
            uncovered.subtract(matchedNames)
            if let primary = picked.recipe.mainIngredients.first.map({ Self.normalize($0.name) }) {
                usedPrimaryIngredients.insert(primary)
            }
            selected.append(picked)
        }

        return selected
    }

    /// `selectCoveringIngredients` 的比較邏輯：涵蓋新食材數 > 是否用了還沒出現過的主要主食材 > 總分
    private func isBetterPick(_ a: ScoredRecipe, than b: ScoredRecipe, uncovered: Set<String>, usedPrimary: Set<String>) -> Bool {
        func newCoverage(_ r: ScoredRecipe) -> Int {
            guard !uncovered.isEmpty else { return 0 }
            let names = (r.matchedMain + r.matchedOther).map { Self.normalize($0) }
            return uncovered.intersection(names).count
        }
        let aCoverage = newCoverage(a)
        let bCoverage = newCoverage(b)
        if aCoverage != bCoverage { return aCoverage > bCoverage }

        func usesNewPrimary(_ r: ScoredRecipe) -> Bool {
            guard let primary = r.recipe.mainIngredients.first.map({ Self.normalize($0.name) }) else { return true }
            return !usedPrimary.contains(primary)
        }
        let aNewPrimary = usesNewPrimary(a)
        let bNewPrimary = usesNewPrimary(b)
        if aNewPrimary != bNewPrimary { return aNewPrimary }

        return a.score > b.score
    }
}
