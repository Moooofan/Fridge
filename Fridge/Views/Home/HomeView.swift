import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var ingredientVM = IngredientViewModel()
    @EnvironmentObject var favoritesVM: FavoritesViewModel

    #if DEBUG
    // DEBUG-only demo mode state, driven by `-demo <name>` launch arg. See DemoLaunch.swift.
    @StateObject private var demoIngredientVM = DemoLaunch.makeIngredientViewModel()
    @StateObject private var demoRecipeVM = DemoLaunch.makeRecipeViewModel()
    @State private var showDemoRecipeList = false
    #endif

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Logo 區域
                LogoSection()

                Spacer()

                // 輸入模式選擇
                VStack(spacing: 16) {
                    Text("選擇輸入方式")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    ForEach(InputMode.allCases, id: \.rawValue) { mode in
                        InputModeButton(mode: mode) {
                            // 開始新的一餐，清空上一餐的食材
                            ingredientVM.reset()
                            viewModel.selectMode(mode)
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
                Spacer()
            }
            .background(Color(.systemBackground))
            .navigationDestination(isPresented: $viewModel.showMealConstraints) {
                if let mode = viewModel.selectedMode {
                    MealConstraintsView(
                        ingredientVM: ingredientVM,
                        inputMode: mode
                    )
                }
            }
            #if DEBUG
            .navigationDestination(isPresented: $showDemoRecipeList) {
                RecipeListView(
                    recipeVM: demoRecipeVM,
                    ingredientVM: demoIngredientVM,
                    autoPushFirstRecipe: DemoLaunch.scenario == "detail"
                )
            }
            .task {
                await runDemoLaunchIfNeeded()
            }
            #endif
        }
    }

    #if DEBUG
    /// Kicks off the seeded demo scenario (if any) and navigates straight to
    /// RecipeListView once recipes are loaded. No-op for normal startup.
    private func runDemoLaunchIfNeeded() async {
        guard DemoLaunch.scenario != nil else { return }

        await demoRecipeVM.generateRecipes(
            ingredients: demoIngredientVM.ingredients,
            constraints: demoIngredientVM.constraints,
            preferences: UserPreferences()
        )

        showDemoRecipeList = true
    }
    #endif
}

// MARK: - Logo Section

private struct LogoSection: View {
    var body: some View {
        VStack(spacing: 16) {
            // Logo
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.black)
                    .frame(width: 100, height: 100)

                VStack(spacing: 4) {
                    Image(systemName: "refrigerator.fill")
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(.white)
                }
            }
            .padding(.top, 60)

            // App 名稱
            Text("Fridge")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            // 標語
            Text("清冰箱好幫手")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Input Mode Button

private struct InputModeButton: View {
    let mode: InputMode
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: mode.icon)
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.primary)
                    .frame(width: 48, height: 48)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(mode.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color(.systemGray6).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView()
        .environmentObject(FavoritesViewModel())
}
