import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var authViewModel = AuthViewModel()
    @EnvironmentObject var condimentVM: CondimentViewModel
    @EnvironmentObject var appFlow: AppFlowState
    @FocusState private var isAllergyFieldFocused: Bool
    @FocusState private var isDislikeFieldFocused: Bool
    @State private var showingLoginSheet = false

    var body: some View {
        NavigationStack {
            List {
                // 帳號
                Section {
                    accountRow
                } header: {
                    Text("帳號")
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
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("AI 模式")
                        Spacer()
                        Text(SecretsManager.shared.hasValidAPIKey ? "OpenAI" : (EdgeAIClient.isConfigured ? "OpenAI (Edge)" : "Mock"))
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("關於")
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
        .onChange(of: authViewModel.user) { _, newValue in
            // 登入（或訪客）流程完成後自動收起 sheet。
            if newValue != nil {
                showingLoginSheet = false
            }
        }
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
        } else {
            Button {
                showingLoginSheet = true
            } label: {
                HStack {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .foregroundColor(.black)
                        .frame(width: 28)
                    Text("登入以同步收藏（即將推出）")
                        .foregroundColor(.primary)
                }
            }
        }
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
        .environmentObject(AppFlowState())
}
