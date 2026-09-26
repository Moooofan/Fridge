import Foundation

/// 目前登入使用者的本地快取（使用 UserDefaults）。
///
/// 這不是各服務（Supabase session／Apple userIdentifier）本身的 source of truth ——
/// 那些各自存在 Keychain（supabase-swift 內建）或由 `LocalAuthService` 管理。這裡只是
/// 一份「最後已知使用者」的輕量快取，讓 `AppFlowState` 能在啟動當下同步判斷要不要
/// 顯示登入畫面，不必等待任何非同步的 session 還原。
final class UserSessionStore {
    static let shared = UserSessionStore()

    private let key = "fridge.currentUserProfile"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 目前已知的使用者（訪客或已登入），nil 代表尚未登入過。
    var currentUser: UserProfile? {
        get {
            guard let data = defaults.data(forKey: key) else { return nil }
            return try? JSONDecoder().decode(UserProfile.self, from: data)
        }
        set {
            guard let newValue else {
                defaults.removeObject(forKey: key)
                return
            }
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: key)
        }
    }

    var hasStoredUser: Bool {
        currentUser != nil
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
