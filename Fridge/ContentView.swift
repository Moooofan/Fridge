import SwiftUI

// MARK: - Root View

/// Switches between onboarding, the (future) login screen, and the main
/// TabView based on `AppFlowState.stage`.
struct RootView: View {
    @EnvironmentObject var appFlow: AppFlowState

    var body: some View {
        Group {
            switch appFlow.stage {
            case .onboarding:
                OnboardingView()
                    .transition(.opacity)
            case .login:
                LoginView()
                    .transition(.opacity)
            case .main:
                ContentView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appFlow.stage)
    }
}

struct ContentView: View {
    @State private var selectedTab = 0
    #if DEBUG
    @State private var showDemoConsent = false
    #endif

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            HomeView()
                .tabItem {
                    Label("首頁", systemImage: "house")
                }
                .tag(0)

            // History Tab
            HistoryView()
                .tabItem {
                    Label("歷史", systemImage: "clock.arrow.circlepath")
                }
                .tag(1)

            // Favorites Tab
            FavoritesView()
                .tabItem {
                    Label("收藏", systemImage: "heart")
                }
                .tag(2)

            // Settings Tab
            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape")
                }
                .tag(3)
        }
        .tint(.black)
        #if DEBUG
        .onAppear {
            if DemoLaunch.scenario == "settings" { selectedTab = 3 }
            if DemoLaunch.scenario == "consent" { showDemoConsent = true }
        }
        .sheet(isPresented: $showDemoConsent) {
            AIConsentView { _ in }
        }
        #endif
    }
}

#Preview {
    ContentView()
        .environmentObject(FavoritesViewModel())
        .environmentObject(HistoryViewModel())
        .environmentObject(CondimentViewModel())
        .environmentObject(AppFlowState())
}
