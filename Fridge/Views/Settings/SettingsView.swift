import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    #if DEBUG
    @StateObject private var authViewModel = DemoLaunch.makeAuthViewModel()
    #else
    @StateObject private var authViewModel = AuthViewModel()
    #endif
    @EnvironmentObject var condimentVM: CondimentViewModel
    @EnvironmentObject var favoritesVM: FavoritesViewModel
    @EnvironmentObject var historyVM: HistoryViewModel
    @EnvironmentObject var appFlow: AppFlowState
    @FocusState private var isAllergyFieldFocused: Bool
    @FocusState private var isDislikeFieldFocused: Bool
    @State private var showingLoginSheet = false
    @State private var showingDeleteConfirm = false
    @State private var showingAIConsentSheet = false
    @State private var aiConsentGranted = AIConsentStore.isGranted
    @State private var analyticsEnabled = Analytics.isEnabled

    var body: some View {
        NavigationStack {
            List {
                // 帳號
                Section {
                    accountRow
                } header: {
                    Text("帳號")
                } footer: {
                    if let message = authViewModel.errorMessage {
                        Text(message)
                            .foregroundColor(.red)
                    }
                }

                // AI 資料使用（App Store 5.1.2(i)）
                Section {
                    aiConsentRow
                } header: {
                    Text("隱私")
                } footer: {
                    Text("同意後，食材、用餐條件與你選擇辨識的照片會透過我們的伺服器傳送給 OpenAI。不同意時改用內建食譜離線配菜。")
                }

                // 分析與診斷
                Section {
                    Toggle("分析與診斷", isOn: Binding(
                        get: { analyticsEnabled },
                        set: { newValue in
                            analyticsEnabled = newValue
                            Analytics.isEnabled = newValue
                        }
                    ))
                } footer: {
                    Text("使用統計與當機報告，用來改善 App；不含你的食材、照片或食譜內容。登入時會連結到你的帳號。")
                }

                // 調味料設定
                Section {
                    NavigationLink {
                        CondimentManagementView()
                    } label: {
                        HStack {
                            Image(systemName: "flask.fill")
                                .foregroundColor(.orange)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("我的調味料")
                                Text(condimentVM.hasCondiments ? "\(condimentVM.count) 項調味料" : "尚未設定")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("廚房設定")
                } footer: {
                    Text("設定您廚房有的調味料，AI 會根據這些推薦食譜")
                }

                // 料理風格偏好
                Section {
                    ForEach(CookingStyle.allCases) { style in
                        StyleRow(
                            style: style,
                            isSelected: viewModel.isStyleSelected(style),
                            onToggle: { viewModel.toggleStyle(style) }
                        )
                    }
                } header: {
                    Text("料理風格")
                } footer: {
                    Text("AI 會根據您的偏好推薦合適的料理")
                }

                // 過敏/忌口
                Section {
                    // 輸入新過敏食材
                    HStack {
                        TextField("新增過敏食材...", text: $viewModel.newAllergy)
                            .focused($isAllergyFieldFocused)
                            .submitLabel(.done)
                            .onSubmit {
                                viewModel.addAllergy()
                            }

                        if !viewModel.newAllergy.isEmpty {
                            Button {
                                viewModel.addAllergy()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.black)
                            }
                        }
                    }

                    // 已新增的過敏食材
                    ForEach(viewModel.preferences.allergies, id: \.self) { allergy in
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.red)
                                .font(.system(size: 14))
                            Text(allergy)
                        }
                    }
                    .onDelete { offsets in
                        viewModel.removeAllergy(at: offsets)
                    }
                } header: {
                    Text("過敏/忌口")
                } footer: {
                    Text("AI 會避免使用這些食材")
                }

                // 不喜歡的食材
                Section {
                    // 輸入
                    HStack {
                        TextField("新增不喜歡的食材...", text: $viewModel.newDislike)
                            .focused($isDislikeFieldFocused)
                            .submitLabel(.done)
                            .onSubmit {
                                viewModel.addDislike()
                            }

                        if !viewModel.newDislike.isEmpty {
                            Button {
                                viewModel.addDislike()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.black)
                            }
                        }
                    }

                    // 已新增的不喜歡食材
                    ForEach(viewModel.preferences.dislikes, id: \.self) { dislike in
                        HStack {
                            Image(systemName: "hand.thumbsdown")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14))
                            Text(dislike)
                        }
                    }
                    .onDelete { offsets in
                        viewModel.removeDislike(at: offsets)
                    }
                } header: {
                    Text("不喜歡的食材")
                } footer: {
                    Text("AI 會盡量避免使用這些食材")
                }

                // 關於
                Section {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text(Self.appVersion)
                            .foregroundColor(.secondary)
                    }

                    Link(destination: AIConsentView.privacyURL) {
                        HStack {
                            Text("隱私權政策")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("關於")
                } footer: {
                    Text("本 App 所列之廚師、節目與網站僅為食譜參考來源，與本 App 無合作或背書關係。")
                }

                // 新手導覽
                Section {
                    Button {
                        appFlow.replayOnboarding()
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(.black)
                                .frame(width: 28)
                            Text("重看新手導覽")
                                .foregroundColor(.primary)
                        }
                    }
                }

                // 重置
                Section {
                    Button(role: .destructive) {
                        viewModel.resetToDefaults()
                    } label: {
                        HStack {
                            Spacer()
                            Text("重置所有設定")
                            Spacer()
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingLoginSheet) {
            LoginView(viewModel: authViewModel)
        }
        .sheet(isPresented: $showingAIConsentSheet, onDismiss: {
            aiConsentGranted = AIConsentStore.isGranted
        }) {
            AIConsentView { granted in
                aiConsentGranted = granted
            }
        }
        .alert("刪除帳號", isPresented: $showingDeleteConfirm) {
            Button("刪除", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("刪除後，你的帳號與雲端資料將永久移除，無法復原。")
        }
        .onChange(of: authViewModel.user) { _, newValue in
            // 登入（或訪客）流程完成後自動收起 sheet。
            if newValue != nil {
                showingLoginSheet = false
            }
        }
    }

    /// 例如「1.0.0 (1)」，讀自 Info.plist 的 CFBundleShortVersionString / CFBundleVersion
    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }

    // MARK: - Account Row

    @ViewBuilder
    private var accountRow: some View {
        if let user = authViewModel.user, user.provider != .guest {
            HStack(spacing: 12) {
                accountAvatar(for: user)
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName ?? user.provider.displayName)
                        .font(.body)
                    Text(accountSubtitle(for: user))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Button(role: .destructive) {
                Task { await authViewModel.signOut() }
            } label: {
                Text("登出")
            }
            .disabled(authViewModel.isBusy)

            Button(role: .destructive) {
                showingDeleteConfirm = true
            } label: {
                HStack {
                    Text("刪除帳號")
                    Spacer()
                    if authViewModel.isBusy {
                        ProgressView()
                    }
                }
            }
            .disabled(authViewModel.isBusy)
        } else {
            Button {
                showingLoginSheet = true
            } label: {
                HStack {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .foregroundColor(.black)
                        .frame(width: 28)
                    Text("登入帳號")
                        .foregroundColor(.primary)
                }
            }
        }
    }

    // MARK: - AI Consent Row

    private var aiConsentRow: some View {
        Button {
            if aiConsentGranted {
                AIConsentStore.decline()
                aiConsentGranted = false
            } else {
                showingAIConsentSheet = true
            }
        } label: {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.black)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI 資料使用")
                        .foregroundColor(.primary)
                    Text(aiConsentGranted ? "點一下即可撤回同意" : "點一下查看說明並同意")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(aiConsentGranted ? "已同意" : "未同意")
                    .foregroundColor(aiConsentGranted ? .green : .secondary)
            }
        }
    }

    // MARK: - Delete Account

    /// 刪除成功後：重新載入（已清空的）本機資料，並回到登入畫面。
    /// 登出列本身不切換 stage；這裡直接設 `appFlow.stage = .login`
    /// （`AppFlowState.stage` 是公開可寫的 @Published 屬性）。
    private func deleteAccount() async {
        guard await authViewModel.deleteAccount() else { return }
        favoritesVM.loadFavorites()
        historyVM.loadHistory()
        condimentVM.loadData()
        viewModel.preferences = UserPreferences.load()
        aiConsentGranted = AIConsentStore.isGranted
        appFlow.stage = .login
    }

    private func accountSubtitle(for user: UserProfile) -> String {
        var subtitle = "以 \(user.provider.displayName) 登入"
        if let email = user.email {
            subtitle += "・\(email)"
        }
        return subtitle
    }

    @ViewBuilder
    private func accountAvatar(for user: UserProfile) -> some View {
        if let avatarURL = user.avatarURL, let url = URL(string: avatarURL) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(Color(.systemGray5))
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
        } else {
            ZStack {
                Circle().fill(Color.black)
                Image(systemName: "person.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }
            .frame(width: 40, height: 40)
        }
    }
}

// MARK: - Style Row

private struct StyleRow: View {
    let style: CookingStyle
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: style.icon)
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(.primary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(style.displayName)
                        .font(.body)
                        .foregroundColor(.primary)
                    Text(style.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.black)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView()
        .environmentObject(CondimentViewModel())
        .environmentObject(FavoritesViewModel())
        .environmentObject(HistoryViewModel())
        .environmentObject(AppFlowState())
}
