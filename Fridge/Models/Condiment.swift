import Foundation

/// 調味料類別（可自訂）
struct CondimentCategory: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var icon: String

    init(id: UUID = UUID(), name: String, icon: String = "ellipsis.circle.fill") {
        self.id = id
        self.name = name
        self.icon = icon
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - 預設類別

extension CondimentCategory {
    /// 預設類別
    static let defaultCategories: [CondimentCategory] = [
        CondimentCategory(name: "鹽類", icon: "drop.fill"),
        CondimentCategory(name: "糖類", icon: "cube.fill"),
        CondimentCategory(name: "油類", icon: "drop.halffull"),
        CondimentCategory(name: "醬料", icon: "flask.fill"),
        CondimentCategory(name: "香料", icon: "leaf.fill"),
        CondimentCategory(name: "香草", icon: "leaf"),
        CondimentCategory(name: "醋類", icon: "waterbottle.fill"),
        CondimentCategory(name: "其他", icon: "ellipsis.circle.fill"),
    ]

    /// 找到「其他」類別
    static var other: CondimentCategory {
        defaultCategories.first { $0.name == "其他" } ?? CondimentCategory(name: "其他", icon: "ellipsis.circle.fill")
    }

    /// 可用的圖示選項
    static let availableIcons: [String] = [
        "drop.fill",
        "drop.halffull",
        "cube.fill",
        "flask.fill",
        "leaf.fill",
        "leaf",
        "waterbottle.fill",
        "flame.fill",
        "sparkles",
        "star.fill",
        "heart.fill",
        "bolt.fill",
        "wand.and.stars",
        "circle.fill",
        "square.fill",
        "triangle.fill",
        "diamond.fill",
        "hexagon.fill",
        "ellipsis.circle.fill",
    ]
}

/// 使用者的調味料
struct Condiment: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var categoryId: UUID  // 改為參照類別 ID

    init(id: UUID = UUID(), name: String, categoryId: UUID) {
        self.id = id
        self.name = name
        self.categoryId = categoryId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - 預設調味料建議

struct CondimentSuggestion {
    let name: String
    let categoryName: String  // 用類別名稱對應

    /// 轉換為 Condiment（需要提供類別列表）
    func toCondiment(with categories: [CondimentCategory]) -> Condiment? {
        guard let category = categories.first(where: { $0.name == categoryName }) else {
            return nil
        }
        return Condiment(name: name, categoryId: category.id)
    }
}

extension CondimentSuggestion {
    /// 常見調味料建議清單
    static let suggestions: [CondimentSuggestion] = [
        // 鹽類
        CondimentSuggestion(name: "鹽巴", categoryName: "鹽類"),
        CondimentSuggestion(name: "海鹽", categoryName: "鹽類"),
        CondimentSuggestion(name: "岩鹽", categoryName: "鹽類"),

        // 糖類
        CondimentSuggestion(name: "白糖", categoryName: "糖類"),
        CondimentSuggestion(name: "冰糖", categoryName: "糖類"),
        CondimentSuggestion(name: "黑糖", categoryName: "糖類"),
        CondimentSuggestion(name: "蜂蜜", categoryName: "糖類"),

        // 油類
        CondimentSuggestion(name: "沙拉油", categoryName: "油類"),
        CondimentSuggestion(name: "橄欖油", categoryName: "油類"),
        CondimentSuggestion(name: "麻油", categoryName: "油類"),
        CondimentSuggestion(name: "香油", categoryName: "油類"),
        CondimentSuggestion(name: "豬油", categoryName: "油類"),
        CondimentSuggestion(name: "奶油", categoryName: "油類"),

        // 醬料
        CondimentSuggestion(name: "醬油", categoryName: "醬料"),
        CondimentSuggestion(name: "醬油膏", categoryName: "醬料"),
        CondimentSuggestion(name: "蠔油", categoryName: "醬料"),
        CondimentSuggestion(name: "味噌", categoryName: "醬料"),
        CondimentSuggestion(name: "番茄醬", categoryName: "醬料"),
        CondimentSuggestion(name: "辣椒醬", categoryName: "醬料"),
        CondimentSuggestion(name: "豆瓣醬", categoryName: "醬料"),
        CondimentSuggestion(name: "沙茶醬", categoryName: "醬料"),
        CondimentSuggestion(name: "芝麻醬", categoryName: "醬料"),
        CondimentSuggestion(name: "美乃滋", categoryName: "醬料"),
        CondimentSuggestion(name: "魚露", categoryName: "醬料"),

        // 香料
        CondimentSuggestion(name: "胡椒粉", categoryName: "香料"),
        CondimentSuggestion(name: "白胡椒", categoryName: "香料"),
        CondimentSuggestion(name: "黑胡椒", categoryName: "香料"),
        CondimentSuggestion(name: "辣椒粉", categoryName: "香料"),
        CondimentSuggestion(name: "花椒", categoryName: "香料"),
        CondimentSuggestion(name: "五香粉", categoryName: "香料"),
        CondimentSuggestion(name: "咖哩粉", categoryName: "香料"),
        CondimentSuggestion(name: "肉桂粉", categoryName: "香料"),
        CondimentSuggestion(name: "孜然", categoryName: "香料"),

        // 香草
        CondimentSuggestion(name: "蒜頭", categoryName: "香草"),
        CondimentSuggestion(name: "薑", categoryName: "香草"),
        CondimentSuggestion(name: "蔥", categoryName: "香草"),
        CondimentSuggestion(name: "辣椒", categoryName: "香草"),
        CondimentSuggestion(name: "香菜", categoryName: "香草"),
        CondimentSuggestion(name: "九層塔", categoryName: "香草"),
        CondimentSuggestion(name: "迷迭香", categoryName: "香草"),
        CondimentSuggestion(name: "月桂葉", categoryName: "香草"),

        // 醋類
        CondimentSuggestion(name: "白醋", categoryName: "醋類"),
        CondimentSuggestion(name: "黑醋", categoryName: "醋類"),
        CondimentSuggestion(name: "米醋", categoryName: "醋類"),
        CondimentSuggestion(name: "蘋果醋", categoryName: "醋類"),

        // 其他
        CondimentSuggestion(name: "米酒", categoryName: "其他"),
        CondimentSuggestion(name: "紹興酒", categoryName: "其他"),
        CondimentSuggestion(name: "味醂", categoryName: "其他"),
        CondimentSuggestion(name: "太白粉", categoryName: "其他"),
        CondimentSuggestion(name: "玉米粉", categoryName: "其他"),
        CondimentSuggestion(name: "雞粉", categoryName: "其他"),
        CondimentSuggestion(name: "柴魚粉", categoryName: "其他"),
    ]

    /// 依類別名稱分組的建議
    static var suggestionsByCategoryName: [String: [CondimentSuggestion]] {
        Dictionary(grouping: suggestions, by: { $0.categoryName })
    }
}
