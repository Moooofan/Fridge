import Foundation

/// 登入來源
enum AuthProvider: String, Codable, CaseIterable, Equatable {
    case apple
    case google
    case line
    case guest

    var displayName: String {
        switch self {
        case .apple: return "Apple"
        case .google: return "Google"
        case .line: return "LINE"
        case .guest: return "訪客"
        }
    }
}

/// 登入後的使用者資料（本地快取用，不含任何 token）
struct UserProfile: Codable, Equatable, Identifiable {
    var id: String
    var provider: AuthProvider
    var displayName: String?
    var email: String?
    var avatarURL: String?

    init(
        id: String,
        provider: AuthProvider,
        displayName: String? = nil,
        email: String? = nil,
        avatarURL: String? = nil
    ) {
        self.id = id
        self.provider = provider
        self.displayName = displayName
        self.email = email
        self.avatarURL = avatarURL
    }

    /// 訪客模式的固定 profile（本機隨機 id，不需登入任何服務）
    static func guest(id: String = UUID().uuidString) -> UserProfile {
        UserProfile(id: id, provider: .guest, displayName: "訪客")
    }
}
