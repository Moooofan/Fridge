import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var favoritesVM: FavoritesViewModel
    @StateObject private var recipeVM = RecipeViewModel()
    @State private var selectedRecipe: Recipe?

    var body: some View {
        NavigationStack {
            Group {
                if favoritesVM.favorites.isEmpty {
                    EmptyFavoritesView()
                } else {
                    FavoritesList(
                        favorites: favoritesVM.favorites,
                        selectedRecipe: $selectedRecipe,
                        onDelete: { offsets in
                            favoritesVM.removeFavorite(at: offsets)
                        }
                    )
                }
            }
            .navigationTitle("收藏")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(item: $selectedRecipe) { recipe in
                FavoriteRecipeDetailView(recipe: recipe, recipeVM: recipeVM)
            }
        }
    }
}

// MARK: - Empty Favorites View

private struct EmptyFavoritesView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.slash")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary)

            Text("尚無收藏")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("點擊食譜頁的愛心按鈕\n即可收藏喜愛的料理")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Favorites List

private struct FavoritesList: View {
    let favorites: [Recipe]
    @Binding var selectedRecipe: Recipe?
    let onDelete: (IndexSet) -> Void

    var body: some View {
        List {
            ForEach(favorites) { recipe in
                FavoriteRecipeRow(recipe: recipe)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedRecipe = recipe
                    }
            }
            .onDelete(perform: onDelete)
        }
        .listStyle(.plain)
    }
}

// MARK: - Favorite Recipe Row

private struct FavoriteRecipeRow: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 16) {
            // Type Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .frame(width: 56, height: 56)

                Image(systemName: recipe.type.icon)
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.primary)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(recipe.type.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(recipe.difficulty.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(recipe.title)
                    .font(.headline)

                HStack(spacing: 12) {
                    Label(recipe.timeDisplay, systemImage: "clock")
                    Label("\(recipe.servings) 人份", systemImage: "person.2")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Favorite Recipe Detail View (uses shared components)

struct FavoriteRecipeDetailView: View {
    let recipe: Recipe
    @ObservedObject var recipeVM: RecipeViewModel
    @EnvironmentObject var favoritesVM: FavoritesViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header (using shared component)
                RecipeHeaderView(recipe: recipe)

                VStack(spacing: 32) {
                    // Meta Info (using shared component)
                    RecipeMetaInfoSection(recipe: recipe)

                    Divider()

                    // Ingredients (using shared component)
                    RecipeIngredientsSection(ingredients: recipe.ingredients)

                    Divider()

                    // Steps (using RecipeVM-backed section so progress persists while the app is running)
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
    FavoritesView()
        .environmentObject({
            let vm = FavoritesViewModel()
            // 加入一些測試資料
            return vm
        }())
}
