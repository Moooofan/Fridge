import AuthenticationServices
import SwiftUI

/// 登入畫面：Apple／Google／LINE 三個登入按鈕，加上「先逛逛」訪客模式。
/// 視覺風格沿用 `OnboardingView`（品牌標誌 `BrandMarkView`、黑色圓角按鈕、zh-TW 文案）。
struct LoginView: View {
    @EnvironmentObject var appFlow: AppFlowState
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel: AuthViewModel

    /// Sign in with Apple 的 nonce：每次 `SignInWithAppleButton` 的 `onRequest` 觸發時
    /// 都重新產生一次（見 `buttons`），避免同一個 nonce 被重複使用；產生後存進這個
    /// @State，讓稍後觸發的 `onCompletion` 能讀到同一次授權用的原始值。
    @State private var appleNonce = AppleSignInCoordinator.randomNonceString()

    /// 一般情況（`RootView` 的 `.login` stage）：自己建立一份 `AuthViewModel`。
    @MainActor
    init() {
        _viewModel = StateObject(wrappedValue: AuthViewModel())
    }

    /// `SettingsView` 以 sheet 開啟這個畫面時改用這個 init，傳進自己的
    /// `AuthViewModel`，這樣登入完成後才能從外面
    /// （`onChange(of: authViewModel.user)`）偵測到並自動關閉 sheet。
    @MainActor
    init(viewModel: AuthViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer(minLength: 32)

                heroIcon

                Text("登入 Fridge")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.top, 20)

                Text("使用 Apple、Google 或 LINE 帳號登入，也可以先逛逛")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 40)
                    .padding(.top, 8)

                Spacer(minLength: 28)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                        .transition(.opacity)
                }

                buttons
                    .padding(.horizontal, 24)

                Button {
                    Task { await viewModel.signIn(with: .guest) }
                } label: {
                    Text("先逛逛，之後再登入")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                .padding(.bottom, 28)
            }

            if viewModel.isBusy {
                busyOverlay
            }
        }
        .background(Color(.systemBackground))
        .animation(.easeInOut(duration: 0.2), value: viewModel.errorMessage)
        .onChange(of: viewModel.user) { _, newValue in
            guard newValue != nil else { return }
            appFlow.completeLogin()
        }
    }

    private var heroIcon: some View {
        BrandMarkView(size: 96)
    }

    private var buttons: some View {
        VStack(spacing: 14) {
            SignInWithAppleButton(.signIn) { request in
                let nonce = AppleSignInCoordinator.randomNonceString()
                appleNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = AppleSignInCoordinator.sha256(nonce)
            } onCompletion: { result in
                Task {
                    await viewModel.completeAppleSignIn(result: result, rawNonce: appleNonce)
                }
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            ProviderButton(
                title: "使用 Google 登入",
                background: .white,
                foreground: .black,
                borderColor: Color(.systemGray4)
            ) {
                Text("G")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.blue)
            } action: {
                Task { await viewModel.signIn(with: .google) }
            }

            ProviderButton(
                title: "使用 LINE 登入",
                background: Color(red: 0.024, green: 0.780, blue: 0.333), // LINE Green #06C755
                foreground: .white,
                borderColor: .clear
            ) {
                Image(systemName: "message.fill")
                    .foregroundColor(.white)
            } action: {
                Task { await viewModel.signIn(with: .line) }
            }
        }
    }

    private var busyOverlay: some View {
        ZStack {
            Color.black.opacity(0.15)
                .ignoresSafeArea()
            ProgressView()
                .tint(.black)
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Provider Button

private struct ProviderButton<Icon: View>: View {
    let title: String
    let background: Color
    let foreground: Color
    let borderColor: Color
    @ViewBuilder var icon: () -> Icon
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                icon()
                    .frame(width: 20, height: 20)
                Text(title)
                    .font(.headline)
            }
            .foregroundColor(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LoginView()
        .environmentObject(AppFlowState())
}
