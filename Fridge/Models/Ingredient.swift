import Foundation

/// 食材模型（用於食譜中）
struct Ingredient: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var amount: String
    var optional: Bool
    var substitutes: [String]

    init(
        id: UUID = UUID(),
        name: String,
        amount: String = "",
        optional: Bool = false,
        substitutes: [String] = []
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.optional = optional
        self.substitutes = substitutes
    }

    // 自定義解碼，處理 AI 回傳的 JSON 可能缺少某些欄位
    enum CodingKeys: String, CodingKey {
        case name, amount, optional, substitutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // id 自動生成
        self.id = UUID()

        // name 必須有
        self.name = try container.decode(String.self, forKey: .name)

        // amount 可選，預設空字串
        self.amount = try container.decodeIfPresent(String.self, forKey: .amount) ?? ""

        // optional 可選，預設 false
        self.optional = try container.decodeIfPresent(Bool.self, forKey: .optional) ?? false

        // substitutes 可選，預設空陣列
        self.substitutes = try container.decodeIfPresent([String].self, forKey: .substitutes) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(amount, forKey: .amount)
        try container.encode(optional, forKey: .optional)
        try container.encode(substitutes, forKey: .substitutes)
    }
}

/// 使用者輸入的簡化食材（食材確認頁用）
struct UserIngredient: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}
