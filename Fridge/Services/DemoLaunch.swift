import Foundation

#if DEBUG
/// DEBUG-only launch-argument demo mode used to drive the app straight to a
/// specific screen for headless simulator screenshot verification.
///
/// Trigger with `-demo <name>` as a launch argument, or the `FRIDGE_DEMO`
/// environment variable. Recognized scenarios:
///   - "list":   jump straight to RecipeListView with seeded ingredients.
///   - "detail": same as "list", then auto-push the first recipe's detail.
///   - "nokey":  same seeded ingredients, but routed through the real
///               AIServiceFactory.createService() so whatever API key is
///               actually configured (or missing/invalid) drives the result.
///   - "onboarding": forces AppFlowState to start on `.onboarding`, regardless
///               of the persisted `hasCompletedOnboarding` flag, for screenshot
///               verification. See FridgeApp.swift.
///   - "login":  forces AppFlowState to start on `.login`, regardless of any
///               locally-stored user, for screenshot verification of LoginView.
///   - "consent": main TabView with the AIConsentView sheet presented on launch.
///   - "settings": main TabView on the Settings tab, with a stubbed signed-in
///               Apple user so the 帳號 section shows 登出／刪除帳號.
///
/// Everything here is compiled out of Release builds.
@MainActor
enum DemoLaunch {
    /// The requested demo scenario, or nil for normal startup.
    static var scenario: String? = {
        let args = ProcessInfo.processInfo.arguments
        if let flagIndex = args.firstIndex(of: "-demo"), flagIndex + 1 < args.count {
            return args[flagIndex + 1]
        }
        if let env = ProcessInfo.processInfo.environment["FRIDGE_DEMO"], !env.isEmpty {
            return env
        }
        return nil
    }()

    /// The `AppFlowState` stage a demo scenario should force, if any.
    /// `"onboarding"` forces `.onboarding`, `"login"` forces `.login`; every
    /// other non-nil scenario (`"list"`, `"detail"`, `"nokey"`) skips straight
    /// to `.main` so the existing demo navigation in HomeView still runs
    /// unobstructed.
    static var forcedAppStage: AppStage? {
        guard let scenario else { return nil }
        switch scenario {
        case "onboarding": return .onboarding
        case "login": return .login
        default: return .main
        }
    }

    /// Whether HomeView should run the seeded recipe demo (list/detail/nokey only).
    static var runsRecipeDemo: Bool {
        ["list", "detail", "nokey"].contains(scenario ?? "")
    }

    /// SettingsView's AuthViewModel. In the "settings" scenario it is backed by a
    /// stub service with a fake signed-in user (no network, deleteAccount is a no-op
    /// that only clears the stub); otherwise the real factory.
    static func makeAuthViewModel() -> AuthViewModel {
        if scenario == "settings" {
            return AuthViewModel(authService: DemoAuthService())
        }
        return AuthViewModel()
    }

    /// Fridge contents seeded for every demo scenario.
    static let seededIngredientNames = ["雞蛋", "番茄", "高麗菜", "蒜頭", "豬絞肉", "青蔥", "蛤蜊", "絲瓜"]

    /// Builds an IngredientViewModel pre-filled with the seeded fridge contents
    /// and constraints (2 servings / 2 dishes / 1 soup).
    static func makeIngredientViewModel() -> IngredientViewModel {
        let vm = IngredientViewModel()
        for name in seededIngredientNames {
            vm.addIngredient(name)
        }
        vm.constraints.servings = 2
        vm.constraints.dishesCount = 2
        vm.constraints.soupsCount = 1
        return vm
    }

    /// Builds the RecipeViewModel for the current demo scenario.
    /// `list`/`detail` go through the offline LocalRecipeService so results are
    /// deterministic; `nokey` goes through the real factory so whatever key is
    /// (or isn't) configured drives the outcome, including the error view.
    static func makeRecipeViewModel() -> RecipeViewModel {
        if scenario == "nokey" {
            return RecipeViewModel()
        }
        return RecipeViewModel(aiService: LocalRecipeService())
    }
}

import AuthenticationServices
import UIKit

/// DEBUG-only stub used by the "settings" demo scenario.
final class DemoAuthService: AuthService {
    private var user: UserProfile? = UserProfile(
        id: "demo-user",
        provider: .apple,
        displayName: "示範使用者",
        email: "demo@example.com"
    )

    var currentUser: UserProfile? { user }

    func signInWithApple(authorization: ASAuthorization, rawNonce: String) async throws -> UserProfile {
        throw AuthError.notConfigured("示範模式")
    }
    func signInWithGoogle(presenting: UIViewController) async throws -> UserProfile {
        throw AuthError.notConfigured("示範模式")
    }
    func signInWithLine() async throws -> UserProfile {
        throw AuthError.notConfigured("示範模式")
    }
    func signOut() async { user = nil }
    func deleteAccount() async throws { user = nil }
    func restoreSession() async -> UserProfile? { user }
}
#endif
