import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe
    @ObservedObject var recipeVM: RecipeViewModel
    @EnvironmentObject var favoritesVM: FavoritesViewModel

    /// Bridge between RecipeViewModel step tracking and the shared component's binding
    @State private var stepCompletionBridge: [Int: Bool] = [:]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header (using shared component)
                RecipeHeaderView(recipe: recipe)

                VStack(spacing: 32) {
                    // Meta Info (using shared component)
                    RecipeMetaInfoSection(recipe: recipe)

                    if let attribution = recipe.attributionText {
                        Text(attribution)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Divider()

                    // Ingredients (using shared component)
                    RecipeIngredientsSection(ingredients: recipe.ingredients)

                    Divider()

                    // Steps (using RecipeVM-backed section for progress persistence)
                    RecipeVMStepsSection(
                        recipe: recipe,
                        recipeVM: recipeVM
                    )

                    // Tips (using shared component)
                    if !recipe.tips.isEmpty {
                        Divider()
                        RecipeTipsSection(tips: recipe.tips)
                    }
                }
                .padding(24)
            }
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Analytics.log(.recipeViewed(fromCurated: recipe.source != nil && !recipe.source!.isEmpty))
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    favoritesVM.toggleFavorite(recipe)
                } label: {
                    Image(systemName: favoritesVM.isFavorite(recipe) ? "heart.fill" : "heart")
                        .foregroundColor(favoritesVM.isFavorite(recipe) ? .red : .primary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        RecipeDetailView(
            recipe: Recipe(
                id: UUID().uuidString,
                type: .dish,
                title: "番茄炒蛋",
                reason: "經典家常菜，營養豐富且老少咸宜",
                timeMinutes: 15,
                difficulty: .easy,
                servings: 2,
                ingredients: [
                    Ingredient(name: "番茄", amount: "2顆"),
                    Ingredient(name: "雞蛋", amount: "3顆"),
                    Ingredient(name: "蔥", amount: "1根", optional: true),
                    Ingredient(name: "糖", amount: "1小匙"),
                    Ingredient(name: "鹽", amount: "適量")
                ],
                steps: [
                    "番茄切塊，蔥切段",
                    "雞蛋打散加少許鹽",
                    "熱鍋下油，倒入蛋液炒至半熟盛出",
                    "同鍋炒番茄至軟爛出汁",
                    "加糖、鹽調味，倒回雞蛋拌炒均勻"
                ],
                tips: [
                    "番茄要炒出汁才會好吃",
                    "加點糖可以提鮮並中和酸味"
                ]
            ),
            recipeVM: RecipeViewModel()
        )
        .environmentObject(FavoritesViewModel())
    }
}
