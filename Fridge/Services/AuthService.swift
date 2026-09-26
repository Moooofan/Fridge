import AuthenticationServices
import UIKit

/// 登入相關錯誤
enum AuthError: LocalizedError {
    case notConfigured(String)
    case cancelled
    case missingIdentityToken
    case deletionFailed(String)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured(let message):
            return message
        case .cancelled:
            return "已取消登入"
        case .missingIdentityToken:
            return "登入失敗：未取得身分驗證資訊"
        case .deletionFailed(let message):
            return "刪除帳號失敗：\(message)"
        case .unknown(let error):
            return "登入失敗：\(error.localizedDescription)"
        }
    }
}

/// 登入服務協議。`SupabaseAuthService`（有後端設定時）與 `LocalAuthService`
/// （沒有 Supabase 設定時的本機備援）皆實作這個協議，UI／ViewModel 完全不需要知道
/// 現在是哪一種實作。
protocol AuthService {
    /// 目前已知的登入使用者（同步、由本地快取回答，見 `UserSessionStore`）。
    var currentUser: UserProfile? { get }

    /// `authorization`／`rawNonce` 來自 SwiftUI 的 `SignInWithAppleButton`（見
    /// `LoginView`）—— 按鈕本身已經驅動了 `ASAuthorizationController`，這裡只需要
    /// 把拿到的 credential 換成後端／本機的登入狀態。
    func signInWithApple(authorization: ASAuthorization, rawNonce: String) async throws -> UserProfile
    func signInWithGoogle(presenting: UIViewController) async throws -> UserProfile
    func signInWithLine() async throws -> UserProfile
    func signOut() async
    /// 永久刪除帳號（App Store 5.1.1(v)）：刪除雲端帳號（Supabase 模式；Apple 使用者
    /// 另外撤銷 Sign in with Apple 授權）、登出，並清除本機使用者資料（保留新手導覽旗標）。
    func deleteAccount() async throws
    /// App 啟動時呼叫一次，嘗試還原已存在的登入狀態（例如 Supabase session 仍有效、
    /// 或本機曾經以訪客／Apple 本機模式登入過）。
    @discardableResult
    func restoreSession() async -> UserProfile?
}

/// 刪除帳號時清除本機的使用者資料。刻意不動 `hasCompletedOnboarding`
/// （見 `AppFlowState`），刪除後直接回到登入畫面，不必重看新手導覽。
enum LocalUserData {
    static func clearAll() {
        UserSessionStore.shared.clear()
        FavoritesStore.shared.clearAll()
        HistoryStore.shared.clearAll()
        CondimentStore.shared.clearAll()
        UserDefaults.standard.removeObject(forKey: UserPreferences.storageKey)
        AIConsentStore.reset()
    }
}

/// 依目前設定挑選要用哪個 `AuthService` 實作。
enum AuthServiceFactory {
    static func createService() -> AuthService {
        if AuthConfig.isSupabaseConfigured {
            return SupabaseAuthService()
        } else {
            #if DEBUG
            print("⚠️ 未設定 Supabase，使用本機登入模式（訪客／Apple 本機）")
            #endif
            return LocalAuthService()
        }
    }
}
