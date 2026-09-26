import Foundation

/// Top-level app navigation stage. Drives which root screen `ContentView`/`FridgeApp`
/// shows: the first-launch onboarding pager, an (upcoming) login screen, or the
/// existing main TabView.
enum AppStage: Equatable {
    case onboarding
    case login
    case main
}

/// Owns the app's top-level flow state (onboarding → login → main).
///
/// `completeOnboarding()` moves to `.login` unless a user is already known locally
/// (see `UserSessionStore`), in which case it skips straight to `.main`.
/// `restoreSession()` should be called once at launch (see `FridgeApp`) to try to
/// silently restore an existing session before the user ever sees `.login`.
@MainActor
final class AppFlowState: ObservableObject {
    @Published var stage: AppStage

    private static let hasCompletedOnboardingKey = "hasCompletedOnboarding"

    private let defaults: UserDefaults
    private let sessionStore: UserSessionStore

    /// - Parameter forcedStage: bypasses the persisted "completed" flag and starts
    ///   the flow on a specific stage. Used by DEBUG demo launch scenarios (see
    ///   `DemoLaunch.swift`) so `-demo onboarding`/`-demo login` always show their
    ///   target stage and the other demo scenarios always skip straight to `.main`.
    init(
        defaults: UserDefaults = .standard,
        sessionStore: UserSessionStore = .shared,
        forcedStage: AppStage? = nil
    ) {
        self.defaults = defaults
        self.sessionStore = sessionStore
        if let forcedStage {
            self.stage = forcedStage
        } else {
            let hasCompletedOnboarding = defaults.bool(forKey: Self.hasCompletedOnboardingKey)
            if !hasCompletedOnboarding {
                self.stage = .onboarding
            } else {
                self.stage = sessionStore.hasStoredUser ? .main : .login
            }
        }
    }

    /// Marks onboarding as complete and advances the flow: straight to `.main` if
    /// a user is already known locally (e.g. relaunching after onboarding replay),
    /// otherwise to `.login`.
    func completeOnboarding() {
        defaults.set(true, forKey: Self.hasCompletedOnboardingKey)
        Analytics.log(.onboardingComplete)
        stage = sessionStore.hasStoredUser ? .main : .login
    }

    /// Called once the login screen (or guest mode) succeeds.
    func completeLogin() {
        stage = .main
    }

    /// Call once at launch to try to silently restore an existing session
    /// (Supabase session in Keychain, or a locally-remembered guest/Apple user)
    /// before deciding whether the user needs to see `.login`.
    func restoreSession() async {
        let authService = AuthServiceFactory.createService()
        _ = await authService.restoreSession()
        if sessionStore.hasStoredUser, stage == .login {
            stage = .main
        }
    }

    /// Resets the flow back to onboarding without touching the persisted
    /// "completed" flag — used by Settings' "重看新手導覽" row.
    func replayOnboarding() {
        stage = .onboarding
    }
}
