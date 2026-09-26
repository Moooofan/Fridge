import Foundation

/// 精選食譜中的單一食材項目（主食材/配料/調味料共用）
struct CuratedIngredient: Codable, Equatable, Hashable {
    let name: String
    let amount: String

    enum CodingKeys: String, CodingKey {
        case name, amount
    }

    init(name: String, amount: String) {
        self.name = name
        self.amount = amount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.amount = try container.decodeIfPresent(String.self, forKey: .amount) ?? ""
    }
}

/// 精選食譜的來源資訊（廚師/節目或出版品/連結）
struct CuratedRecipeSource: Codable, Equatable, Hashable {
    let chef: String
    let publisher: String
    let url: String

    enum CodingKeys: String, CodingKey {
        case chef, publisher, url
    }

    init(chef: String = "", publisher: String = "", url: String = "") {
        self.chef = chef
        self.publisher = publisher
        self.url = url
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.chef = try container.decodeIfPresent(String.self, forKey: .chef) ?? ""
        self.publisher = try container.decodeIfPresent(String.self, forKey: .publisher) ?? ""
        self.url = try container.decodeIfPresent(String.self, forKey: .url) ?? ""
    }
}

/// 內建的專業廚師精選食譜（隨 App 附帶，作為 AI 生成的參考依據）
struct CuratedRecipe: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let category: String
    let cuisine: String
    let source: CuratedRecipeSource
    let servings: Int
    let timeMinutes: Int
    let difficulty: String
    let mainIngredients: [CuratedIngredient]
    let otherIngredients: [CuratedIngredient]
    let seasonings: [CuratedIngredient]
    let steps: [String]
    let tips: [String]
    let tags: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, category, cuisine, source, servings, timeMinutes, difficulty
        case mainIngredients, otherIngredients, seasonings, steps, tips, tags
    }

    init(
        id: String,
        name: String,
        category: String,
        cuisine: String,
        source: CuratedRecipeSource,
        servings: Int,
        timeMinutes: Int,
        difficulty: String,
        mainIngredients: [CuratedIngredient],
        otherIngredients: [CuratedIngredient],
        seasonings: [CuratedIngredient],
        steps: [String],
        tips: [String],
        tags: [String]
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.cuisine = cuisine
        self.source = source
        self.servings = servings
        self.timeMinutes = timeMinutes
        self.difficulty = difficulty
        self.mainIngredients = mainIngredients
        self.otherIngredients = otherIngredients
        self.seasonings = seasonings
        self.steps = steps
        self.tips = tips
        self.tags = tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.category = try container.decodeIfPresent(String.self, forKey: .category) ?? ""
        self.cuisine = try container.decodeIfPresent(String.self, forKey: .cuisine) ?? ""
        self.source = try container.decodeIfPresent(CuratedRecipeSource.self, forKey: .source) ?? CuratedRecipeSource()
        self.servings = try container.decodeIfPresent(Int.self, forKey: .servings) ?? 2
        self.timeMinutes = try container.decodeIfPresent(Int.self, forKey: .timeMinutes) ?? 20
        self.difficulty = try container.decodeIfPresent(String.self, forKey: .difficulty) ?? "簡單"
        self.mainIngredients = try container.decodeIfPresent([CuratedIngredient].self, forKey: .mainIngredients) ?? []
        self.otherIngredients = try container.decodeIfPresent([CuratedIngredient].self, forKey: .otherIngredients) ?? []
        self.seasonings = try container.decodeIfPresent([CuratedIngredient].self, forKey: .seasonings) ?? []
        self.steps = try container.decodeIfPresent([String].self, forKey: .steps) ?? []
        self.tips = try container.decodeIfPresent([String].self, forKey: .tips) ?? []
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
    }

    /// 是否為湯品分類
    var isSoup: Bool { category == "湯品" }

    /// 來源歸屬文字，例如 "阿基師（型男大主廚）"
    var attribution: String {
        let chef = source.chef.trimmingCharacters(in: .whitespacesAndNewlines)
        let publisher = source.publisher.trimmingCharacters(in: .whitespacesAndNewlines)
        if !chef.isEmpty && !publisher.isEmpty {
            return "\(chef)（\(publisher)）"
        } else if !chef.isEmpty {
            return chef
        } else if !publisher.isEmpty {
            return publisher
        }
        return ""
    }

    private var mappedDifficulty: Difficulty {
        switch difficulty {
        case "簡單": return .easy
        case "中等": return .medium
        case "進階": return .hard
        default: return .medium
        }
    }

    /// 轉換為 App 內既有的 Recipe 模型
    func toRecipe(reason: String) -> Recipe {
        var ingredients: [Ingredient] = []
        ingredients.append(contentsOf: mainIngredients.map { Ingredient(name: $0.name, amount: $0.amount) })
        ingredients.append(contentsOf: otherIngredients.map { Ingredient(name: $0.name, amount: $0.amount) })
        ingredients.append(contentsOf: seasonings.map { Ingredient(name: $0.name, amount: $0.amount) })

        return Recipe(
            id: UUID().uuidString,
            type: isSoup ? .soup : .dish,
            title: name,
            reason: reason,
            timeMinutes: timeMinutes,
            difficulty: mappedDifficulty,
            servings: servings,
            ingredients: ingredients,
            steps: steps,
            tips: tips,
            source: attribution.isEmpty ? nil : attribution
        )
    }

    /// 回傳一份份量依 targetServings 等比例調整過的複本（食材用量會依比例縮放，步驟/訣竅不變）
    func scaled(to targetServings: Int) -> CuratedRecipe {
        guard targetServings > 0, servings > 0 else { return self }
        let factor = Double(targetServings) / Double(servings)
        guard factor != 1 else { return self }

        func scale(_ ing: CuratedIngredient) -> CuratedIngredient {
            CuratedIngredient(name: ing.name, amount: Self.scaledAmount(ing.amount, factor: factor))
        }

        return CuratedRecipe(
            id: id,
            name: name,
            category: category,
            cuisine: cuisine,
            source: source,
            servings: targetServings,
            timeMinutes: timeMinutes,
            difficulty: difficulty,
            mainIngredients: mainIngredients.map(scale),
            otherIngredients: otherIngredients.map(scale),
            seasonings: seasonings.map(scale),
            steps: steps,
            tips: tips,
            tags: tags
        )
    }

    /// 解析 amount 開頭的數字（支援整數、小數、簡單分數 "1/2"、帶分數 "1又1/2"），回傳數值與剩餘的單位字串
    private static func leadingNumber(from amount: String) -> (value: Double, unitSuffix: Substring)? {
        let s = Substring(amount)

        if let range = s.range(of: #"^\d+又\d+/\d+"#, options: .regularExpression) {
            let parts = s[range].split(separator: "又")
            guard parts.count == 2 else { return nil }
            let fracParts = parts[1].split(separator: "/")
            guard let whole = Double(parts[0]), fracParts.count == 2,
                  let num = Double(fracParts[0]), let den = Double(fracParts[1]), den != 0 else { return nil }
            return (whole + num / den, s[range.upperBound...])
        }

        if let range = s.range(of: #"^\d+/\d+"#, options: .regularExpression) {
            let fracParts = s[range].split(separator: "/")
            guard fracParts.count == 2, let num = Double(fracParts[0]), let den = Double(fracParts[1]), den != 0 else { return nil }
            return (num / den, s[range.upperBound...])
        }

        if let range = s.range(of: #"^\d+(\.\d+)?"#, options: .regularExpression) {
            guard let value = Double(s[range]) else { return nil }
            return (value, s[range.upperBound...])
        }

        return nil
    }

    /// 依單位決定捨入規則後回傳縮放過的 amount 字串；無前導數字（如「少許」「適量」）則原樣回傳
    private static func scaledAmount(_ amount: String, factor: Double) -> String {
        guard let (value, rawSuffix) = leadingNumber(from: amount) else { return amount }
        let scaledValue = value * factor

        // 範圍寫法（"3-4條"、"300~400g"）：兩個數字都要縮放，分隔符原樣保留
        let rangeSeparators: [Character] = ["-", "~", "～", "–", "至"]
        if let sep = rawSuffix.first, rangeSeparators.contains(sep),
           let (_, _) = leadingNumber(from: String(rawSuffix.dropFirst())) {
            let rest = String(rawSuffix.dropFirst())
            let scaledRest = scaledAmount(rest, factor: factor)
            let unitOfRest = leadingNumber(from: scaledRest)?.unitSuffix ?? Substring("")
            let lowerText = scaledAmount("\(value)\(unitOfRest)", factor: factor)
            let lowerNumber = lowerText.dropLast(unitOfRest.count)
            return "\(lowerNumber)\(sep)\(scaledRest)"
        }
        let unitSuffix = rawSuffix

        let massPrefixes = ["g", "ml", "克", "cc"]
        if massPrefixes.contains(where: { unitSuffix.hasPrefix($0) }) {
            let roundedToFive = (scaledValue / 5).rounded() * 5
            let finalValue = max(5, Int(roundedToFive))
            return "\(finalValue)\(unitSuffix)"
        }

        // 其餘單位（顆/瓣/片/條/支/根/大匙/小匙/杯 及其他計數單位）：捨入到最近 0.5
        let doubled = Int((scaledValue * 2).rounded())
        let safeDoubled = doubled <= 0 ? 1 : doubled // 最小 0.5
        let whole = safeDoubled / 2
        let hasHalf = safeDoubled % 2 != 0

        let numberText: String
        if !hasHalf {
            numberText = "\(whole)"
        } else if whole == 0 {
            numberText = "1/2"
        } else {
            numberText = "\(whole)又1/2"
        }

        return "\(numberText)\(unitSuffix)"
    }

    /// 給 LLM prompt 使用的精簡文字摘要
    var promptSummary: String {
        let mainStr = mainIngredients.map { "\($0.name) \($0.amount)" }.joined(separator: "、")
        let otherStr = otherIngredients.map { "\($0.name) \($0.amount)" }.joined(separator: "、")
        let seasoningStr = seasonings.map { "\($0.name) \($0.amount)" }.joined(separator: "、")
        let stepsStr = steps.enumerated().map { "\($0.offset + 1)) \($0.element)" }.joined(separator: " ")
        let tipsStr = tips.joined(separator: "；")

        var lines: [String] = []
        lines.append("【\(id)】\(name)｜\(category)｜\(servings)人｜\(timeMinutes)分｜\(difficulty)｜來源：\(attribution)")
        if !mainStr.isEmpty { lines.append("主食材: \(mainStr)") }
        if !otherStr.isEmpty { lines.append("配料: \(otherStr)") }
        if !seasoningStr.isEmpty { lines.append("調味: \(seasoningStr)") }
        if !stepsStr.isEmpty { lines.append("步驟: \(stepsStr)") }
        if !tipsStr.isEmpty { lines.append("訣竅: \(tipsStr)") }
        return lines.joined(separator: "\n")
    }
}
