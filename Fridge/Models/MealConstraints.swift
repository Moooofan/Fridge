import Foundation

/// 餐次類型
enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast = "breakfast"
    case lunch = "lunch"
    case dinner = "dinner"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breakfast: return "早餐"
        case .lunch: return "午餐"
        case .dinner: return "晚餐"
        }
    }

    var icon: String {
        switch self {
        case .breakfast: return "sunrise"
        case .lunch: return "sun.max"
        case .dinner: return "moon.stars"
        }
    }
}

/// 用餐條件設定
struct MealConstraints: Codable, Equatable {
    /// 用餐日期
    var date: Date?

    /// 餐次（早餐/午餐/晚餐）
    var mealType: MealType?

    /// 用餐人數（可空，讓 AI 自行決定）
    var servings: Int?

    /// 幾道菜（可空）
    var dishesCount: Int?

    /// 幾道湯（可空）
    var soupsCount: Int?

    init(
        date: Date? = nil,
        mealType: MealType? = nil,
        servings: Int? = nil,
        dishesCount: Int? = nil,
        soupsCount: Int? = nil
    ) {
        self.date = date
        self.mealType = mealType
        self.servings = servings
        self.dishesCount = dishesCount
        self.soupsCount = soupsCount
    }

    /// 是否所有欄位都是空的
    var isEmpty: Bool {
        servings == nil && dishesCount == nil && soupsCount == nil && date == nil && mealType == nil
    }

    /// 日期顯示格式
    var dateDisplay: String? {
        guard let date = date else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.dateFormat = "M/d (E)"
        return formatter.string(from: date)
    }

    /// 完整餐次描述
    var mealDescription: String? {
        var parts: [String] = []
        if let dateStr = dateDisplay {
            parts.append(dateStr)
        }
        if let meal = mealType {
            parts.append(meal.displayName)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    /// 產生描述文字（給 prompt 用）
    var promptDescription: String {
        var parts: [String] = []

        // 餐次資訊
        if let mealDesc = mealDescription {
            parts.append("用餐時段：\(mealDesc)")
        }

        if let servings = servings {
            parts.append("用餐人數：\(servings) 人")
        } else {
            parts.append("用餐人數：請 AI 合理推定")
        }

        if let dishes = dishesCount {
            parts.append("菜的數量：\(dishes) 道")
        } else {
            parts.append("菜的數量：請 AI 合理推定")
        }

        if let soups = soupsCount {
            parts.append("湯的數量：\(soups) 道")
        } else {
            parts.append("湯的數量：請 AI 合理推定")
        }

        return parts.joined(separator: "\n")
    }
}
