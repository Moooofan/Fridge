import SwiftUI

struct RecipeListView: View {
    @ObservedObject var recipeVM: RecipeViewModel
    @ObservedObject var ingredientVM: IngredientViewModel
    @EnvironmentObject var favoritesVM: FavoritesViewModel
    @EnvironmentObject var condimentVM: CondimentViewModel
    @StateObject private var settingsVM = SettingsViewModel()

    @State private var selectedRecipe: Recipe?
    @Environment(\.dismiss) var dismiss

    #if DEBUG
    /// DEBUG-only: when true, auto-pushes the first loaded recipe's detail
    /// screen. Used by DemoLaunch's "detail" scenario for headless screenshot
    /// verification; has no effect in normal (non-demo) navigation.
    var autoPushFirstRecipe: Bool = false
    #endif

    var body: some View {
        Group {
            switch recipeVM.loadingState {
            case .idle:
                EmptyStateView()

            case .loading:
                LoadingView(message: "AI 正在為您設計菜單...")

            case .success(let response):
                SuccessView(
                    response: response,
                    recipeVM: recipeVM,
                    selectedRecipe: $selectedRecipe
                )

            case .error(let message):
                ErrorView(
                    message: message,
                    onRetry: retry
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(recipeVM.isLoading)
        .toolbar {
            if case .success = recipeVM.loadingState {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        // 返回首頁
                        dismiss()
                    }
                }
            }
        }
        .navigationDestination(item: $selectedRecipe) { recipe in
            RecipeDetailView(recipe: recipe, recipeVM: recipeVM)
        }
        #if DEBUG
        .onChange(of: recipeVM.recipes.count) { _, newCount in
            guard autoPushFirstRecipe, selectedRecipe == nil, newCount > 0 else { return }
            selectedRecipe = recipeVM.recipes.first
        }
        .task {
            // 食譜可能在 onChange 掛上前就已載入（離線配菜很快），這裡再補一次
            guard autoPushFirstRecipe, selectedRecipe == nil else { return }
            try? await Task.sleep(for: .seconds(1))
            if selectedRecipe == nil { selectedRecipe = recipeVM.recipes.first }
        }
        #endif
    }

    private func retry() {
        Task {
            await recipeVM.retry(
                ingredients: ingredientVM.ingredients,
                constraints: ingredientVM.constraints,
                preferences: settingsVM.preferences,
                condiments: condimentVM.condimentNames
            )
        }
    }
}

// MARK: - Empty State View

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary)
            Text("尚未生成食譜")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Success View

private struct SuccessView: View {
    let response: AIRecipeResponse
    @ObservedObject var recipeVM: RecipeViewModel
    @Binding var selectedRecipe: Recipe?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // AI 失敗改用內建食譜時的提示
                if let notice = recipeVM.fallbackNotice {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle")
                        Text(notice)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }

                // 菜單摘要
                MenuSummaryCard(menu: response.menu)

                // 菜類
                if !recipeVM.dishes.isEmpty {
                    RecipeSection(
                        title: "菜",
                        icon: "fork.knife",
                        recipes: recipeVM.dishes,
                        selectedRecipe: $selectedRecipe,
                        recipeVM: recipeVM
                    )
                }

                // 湯類
                if !recipeVM.soups.isEmpty {
                    RecipeSection(
                        title: "湯",
                        icon: "cup.and.saucer",
                        recipes: recipeVM.soups,
                        selectedRecipe: $selectedRecipe,
                        recipeVM: recipeVM
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Menu Summary Card

private struct MenuSummaryCard: View {
    let menu: MenuInfo

    var body: some View {
        VStack(spacing: 12) {
            Text("今日菜單")
                .font(.headline)

            HStack(spacing: 24) {
                SummaryItem(icon: "person.2", value: "\(menu.servings)", label: "人份")
                SummaryItem(icon: "fork.knife", value: "\(menu.dishesCount)", label: "道菜")
                SummaryItem(icon: "cup.and.saucer", value: "\(menu.soupsCount)", label: "道湯")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.black)
        .foregroundColor(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct SummaryItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .light))

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))

            Text(label)
                .font(.caption)
                .opacity(0.8)
        }
    }
}

// MARK: - Recipe Section

private struct RecipeSection: View {
    let title: String
    let icon: String
    let recipes: [Recipe]
    @Binding var selectedRecipe: Recipe?
    @ObservedObject var recipeVM: RecipeViewModel
    @EnvironmentObject var favoritesVM: FavoritesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(recipes.count) 道")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Recipe Cards
            ForEach(recipes) { recipe in
                RecipeCard(
                    recipe: recipe,
                    progress: recipeVM.getProgress(for: recipe),
                    isFavorite: favoritesVM.isFavorite(recipe),
                    onTap: {
                        selectedRecipe = recipe
                    },
                    onFavoriteToggle: {
                        favoritesVM.toggleFavorite(recipe)
                    }
                )
            }
        }
    }
}

// MARK: - Error View

private struct ErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("發生錯誤")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onRetry) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("重試")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 120, height: 44)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(24)
    }
}

#Preview {
    NavigationStack {
        RecipeListView(
            recipeVM: {
                let vm = RecipeViewModel(aiService: MockAIService())
                return vm
            }(),
            ingredientVM: IngredientViewModel()
        )
        .environmentObject(FavoritesViewModel())
        .environmentObject(CondimentViewModel())
    }
}
