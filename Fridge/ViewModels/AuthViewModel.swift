import AuthenticationServices
import UIKit

/// 登入畫面的 ViewModel。實際的登入服務（`SupabaseAuthService` 或 `LocalAuthService`）
/// 由 `AuthServiceFactory` 依目前設定挑選，這個類別本身不需要知道現在是哪一種。
///
/// 注意：這裡刻意不持有 `AppFlowState`（環境物件在 View 的 init 階段還拿不到），改由
/// `LoginView` 在 `user` 變成非 nil（登入或訪客成功）之後自己呼叫
/// `appFlow.completeLogin()`，跟 `SettingsView`／`OnboardingView` 直接用
/// `@EnvironmentObject appFlow` 的作法一致。
@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var user: UserProfile?
    @Published var isBusy = false
    @Published var errorMessage: String?

    private let authService: AuthService

    init(authService: AuthService = AuthServiceFactory.createService()) {
        self.authService = authService
        self.user = authService.currentUser
    }

    /// App 啟動時呼叫一次，嘗試還原已登入的使用者。
    func restoreSession() async {
        if let restored = await authService.restoreSession() {
            user = restored
        }
    }

    /// 依 provider 觸發對應的登入流程（Google／LINE／訪客）。Apple 走
    /// `SignInWithAppleButton` 自己的 request/completion，見 `completeAppleSignIn`。
    func signIn(with provider: AuthProvider) async {
        switch provider {
        case .guest:
            continueAsGuest()
        case .google:
            await run(method: "google") {
                guard let presenting = Self.topViewController() else {
                    throw AuthError.unknown(NSError(domain: "AuthViewModel", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "無法顯示登入畫面，請重試",
                    ]))
                }
                return try await self.authService.signInWithGoogle(presenting: presenting)
            }
        case .line:
            await run(method: "line") { try await self.authService.signInWithLine() }
        case .apple:
            assertionFailure("Apple 登入請走 completeAppleSignIn(authorization:rawNonce:)")
        }
    }

    /// `LoginView` 的 `SignInWithAppleButton.onCompletion` 呼叫這個，把已經跑完
    /// `ASAuthorizationController` 流程的結果交給 `AuthService` 換成登入狀態。
    func completeAppleSignIn(result: Result<ASAuthorization, Error>, rawNonce: String) async {
        switch result {
        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                return // 使用者自己取消
            }
            errorMessage = error.localizedDescription
        case .success(let authorization):
            await run(method: "apple") { try await self.authService.signInWithApple(authorization: authorization, rawNonce: rawNonce) }
        }
    }

    /// 共用的「跑一段登入流程、處理忙碌狀態與錯誤」邏輯。`method` 非 nil 時，成功後記一筆
    /// `.login(method:)` 分析事件。
    private func run(method: String? = nil, _ action: @escaping () async throws -> UserProfile) async {
        errorMessage = nil
        isBusy = true
        defer { isBusy = false }
        do {
            user = try await action()
            if let method {
                Analytics.log(.login(method: method))
            }
        } catch let error as AuthError {
            if case .cancelled = error {
                return
            }
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 訪客模式：不需要呼叫任何登入服務，直接記一個本機訪客身分。
    func continueAsGuest() {
        errorMessage = nil
        let profile = UserProfile.guest()
        UserSessionStore.shared.currentUser = profile
        user = profile
        Analytics.log(.loginSkipGuest)
    }

    func signOut() async {
        isBusy = true
        defer { isBusy = false }
        await authService.signOut()
        user = nil
    }

    /// 永久刪除帳號。成功回傳 true（呼叫端負責把 App 導回登入畫面）；
    /// 使用者取消 Apple 重新授權時回傳 false 且不顯示錯誤。
    @discardableResult
    func deleteAccount() async -> Bool {
        errorMessage = nil
        isBusy = true
        defer { isBusy = false }
        do {
            try await authService.deleteAccount()
            Analytics.log(.accountDeleted)
            await Analytics.flush()
            user = nil
            return true
        } catch let error as AuthError {
            if case .cancelled = error { return false }
            errorMessage = error.errorDescription
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private static func topViewController() -> UIViewController? {
        guard var top = AppleSignInCoordinator.keyWindow()?.rootViewController else { return nil }
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
