import Foundation

/// 料理風格偏好
enum CookingStyle: String, Codable, CaseIterable, Identifiable {
    case light = "light"           // 清淡
    case homestyle = "homestyle"   // 家常
    case healthy = "healthy"       // 健康
    case quick = "quick"           // 快速

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light: return "清淡"
        case .homestyle: return "家常"
        case .healthy: return "健康"
        case .quick: return "快速"
        }
    }

    var description: String {
        switch self {
        case .light: return "少油少鹽，口味清爽"
        case .homestyle: return "傳統家常料理風味"
        case .healthy: return "營養均衡，低熱量"
        case .quick: return "30分鐘內完成"
        }
    }

    var icon: String {
        switch self {
        case .light: return "leaf"
        case .homestyle: return "house"
        case .healthy: return "heart"
        case .quick: return "bolt"
        }
    }
}

/// 使用者偏好設定
struct UserPreferences: Codable, Equatable {
    /// 料理風格偏好（可多選）
    var cookingStyles: [CookingStyle]

    /// 忌口/過敏食材
    var allergies: [String]

    /// 不喜歡的食材
    var dislikes: [String]

    init(
        cookingStyles: [CookingStyle] = [.homestyle],
        allergies: [String] = [],
        dislikes: [String] = []
    ) {
        self.cookingStyles = cookingStyles
        self.allergies = allergies
        self.dislikes = dislikes
    }

    /// 產生描述文字（給 prompt 用）
    var promptDescription: String {
        var parts: [String] = []

        if !cookingStyles.isEmpty {
            let styles = cookingStyles.map { $0.displayName }.joined(separator: "、")
            parts.append("偏好風格：\(styles)")
        }

        if !allergies.isEmpty {
            parts.append("過敏/忌口：\(allergies.joined(separator: "、"))")
        }

        if !dislikes.isEmpty {
            parts.append("不喜歡的食材：\(dislikes.joined(separator: "、"))")
        }

        if parts.isEmpty {
            return "無特殊偏好"
        }

        return parts.joined(separator: "\n")
    }

    /// UserDefaults 存取 key
    static let storageKey = "user_preferences"

    /// 從 UserDefaults 讀取
    static func load() -> UserPreferences {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let prefs = try? JSONDecoder().decode(UserPreferences.self, from: data) else {
            return UserPreferences()
        }
        return prefs
    }

    /// 儲存到 UserDefaults
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
