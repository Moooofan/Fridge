import GoogleSignIn
import LineSDK
import SwiftUI

@main
struct FridgeApp: App {
    @StateObject private var favoritesVM = FavoritesViewModel()
    @StateObject private var historyVM = HistoryViewModel()
    @StateObject private var condimentVM = CondimentViewModel()
    @StateObject private var appFlow: AppFlowState
    @Environment(\.scenePhase) private var scenePhase

    /// DEBUG demo launches (`-demo <scenario>`) force a specific stage and should
    /// skip the real session restore so e.g. `-demo login` reliably shows LoginView
    /// even if a session happens to exist on the simulator.
    private let shouldRestoreSessionAtLaunch: Bool

    init() {
        // Analytics/crash reporting facade（見 Fridge/Services/Analytics.swift）：沒設定
        // Supabase 時整支是 no-op，設定好後會補送上次留在佇列裡的事件。
        Analytics.configure()

        // 提早在背景執行緒觸發 CuratedRecipes.json 載入，避免第一次比對食譜時卡在主執行緒
        RecipeDatabase.shared.preload()

        // LINE SDK 需要在使用任何 LoginManager API 前先 setup 過一次；沒設定 channel id
        // 就完全不呼叫，避免對沒配置的 SDK 做任何事。
        if let channelID = SecretsManager.shared.lineChannelID {
            LoginManager.shared.setup(channelID: channelID, universalLinkURL: nil)
        }

        #if DEBUG
        let forcedStage = DemoLaunch.forcedAppStage
        _appFlow = StateObject(wrappedValue: AppFlowState(forcedStage: forcedStage))
        shouldRestoreSessionAtLaunch = forcedStage == nil
        #else
        _appFlow = StateObject(wrappedValue: AppFlowState())
        shouldRestoreSessionAtLaunch = true
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(favoritesVM)
                .environmentObject(historyVM)
                .environmentObject(condimentVM)
                .environmentObject(appFlow)
                .task {
                    guard shouldRestoreSessionAtLaunch else { return }
                    await appFlow.restoreSession()
                }
                .onOpenURL { url in
                    // Google／LINE 的登入流程會切到各自的 App／Safari 再用自訂 URL scheme
                    // 跳回來；兩個 SDK 都提供「這個 URL 是不是我的回呼」的處理函式，各自
                    // 不認得的 URL 會回傳 false，不會互相干擾。
                    if GIDSignIn.sharedInstance.handle(url) { return }
                    _ = LoginManager.shared.application(.shared, open: url)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    // App 進背景時把還沒送出的分析事件補送一次；沒設定 Supabase 或使用者
                    // 關閉分析時 `Analytics.flush()` 直接是 no-op。
                    guard newPhase == .background else { return }
                    Task { await Analytics.flush() }
                }
        }
    }
}
