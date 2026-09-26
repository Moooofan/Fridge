import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var historyVM: HistoryViewModel
    @EnvironmentObject var favoritesVM: FavoritesViewModel
    @StateObject private var recipeVM = RecipeViewModel()
    @State private var selectedHistory: MealHistory?

    var body: some View {
        NavigationStack {
            Group {
                if historyVM.history.isEmpty {
                    EmptyHistoryView()
                } else {
                    HistoryList(
                        history: historyVM.history,
                        selectedHistory: $selectedHistory,
                        onDelete: { offsets in
                            historyVM.removeHistory(at: offsets)
                        }
                    )
                }
            }
            .navigationTitle("歷史紀錄")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if historyVM.hasHistory {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(role: .destructive) {
                                historyVM.clearAll()
                            } label: {
                                Label("清空全部", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .navigationDestination(item: $selectedHistory) { history in
                HistoryDetailView(history: history, recipeVM: recipeVM)
            }
        }
    }
}

// MARK: - Empty History View

private struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary)

            Text("尚無歷史紀錄")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("使用 AI 生成食譜後\n會自動保存在這裡")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - History List

private struct HistoryList: View {
    let history: [MealHistory]
    @Binding var selectedHistory: MealHistory?
    let onDelete: (IndexSet) -> Void

    var body: some View {
        List {
            ForEach(history) { item in
                HistoryRow(history: item)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedHistory = item
                    }
            }
            .onDelete(perform: onDelete)
        }
        .listStyle(.plain)
    }
}

// MARK: - History Row

private struct HistoryRow: View {
    let history: MealHistory

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .frame(width: 56, height: 56)

                VStack(spacing: 2) {
                    Image(systemName: history.constraints.mealType?.icon ?? "fork.knife")
                        .font(.system(size: 20, weight: .light))
                    Text("\(history.recipes.count)")
                        .font(.caption2.weight(.medium))
                }
                .foregroundColor(.primary)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                // Date and meal type
                HStack {
                    if let mealDesc = history.mealDateDisplay {
                        Text(mealDesc)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(history.dateDisplay)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Recipe names
                Text(history.summary)
                    .font(.headline)
                    .lineLimit(1)

                // Meta info
                HStack(spacing: 12) {
                    Label("\(history.menu.servings) 人份", systemImage: "person.2")
                    Label("\(history.ingredientCount) 食材", systemImage: "basket")
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

// MARK: - History Detail View

struct HistoryDetailView: View {
    let history: MealHistory
    @ObservedObject var recipeVM: RecipeViewModel
    @EnvironmentObject var favoritesVM: FavoritesViewModel
    @State private var selectedRecipe: Recipe?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HistoryDetailHeader(history: history)

                // Ingredients
                HistoryIngredientsSection(ingredients: history.ingredients)

                // Recipes
                HistoryRecipesSection(
                    recipes: history.recipes,
                    selectedRecipe: $selectedRecipe
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedRecipe) { recipe in
            FavoriteRecipeDetailView(recipe: recipe, recipeVM: recipeVM)
        }
    }
}

private struct HistoryDetailHeader: View {
    let history: MealHistory

    var body: some View {
        VStack(spacing: 12) {
            if let mealDesc = history.mealDateDisplay {
                Text(mealDesc)
                    .font(.headline)
            }

            Text(history.dateDisplay)
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("\(history.menu.servings)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("人份")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 4) {
                    Text("\(history.menu.dishesCount)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("道菜")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 4) {
                    Text("\(history.menu.soupsCount)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("道湯")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 8)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.black)
        .foregroundColor(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct HistoryIngredientsSection: View {
    let ingredients: [UserIngredient]
    @State private var showAll = false

    private var displayedIngredients: [UserIngredient] {
        if showAll || ingredients.count <= 6 {
            return ingredients
        }
        return Array(ingredients.prefix(6))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "basket")
                    .font(.system(size: 16, weight: .medium))
                Text("使用食材")
                    .font(.headline)
                Spacer()
                Text("\(ingredients.count) 項")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Ingredient chips
            FlowLayout(spacing: 8) {
                ForEach(displayedIngredients) { ingredient in
                    Text(ingredient.name)
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .clipShape(Capsule())
                }

                if ingredients.count > 6 && !showAll {
                    Button {
                        withAnimation {
                            showAll = true
                        }
                    } label: {
                        Text("+\(ingredients.count - 6)")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
}

private struct HistoryRecipesSection: View {
    let recipes: [Recipe]
    @Binding var selectedRecipe: Recipe?
    @EnvironmentObject var favoritesVM: FavoritesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "fork.knife")
                    .font(.system(size: 16, weight: .medium))
                Text("食譜")
                    .font(.headline)
                Spacer()
                Text("\(recipes.count) 道")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            ForEach(recipes) { recipe in
                HistoryRecipeCard(
                    recipe: recipe,
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

private struct HistoryRecipeCard: View {
    let recipe: Recipe
    let isFavorite: Bool
    let onTap: () -> Void
    let onFavoriteToggle: () -> Void

    var body: some View {
        Button(action: onTap) {
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
                        Text(recipe.difficulty.displayName)
                            .font(.caption)
                            .foregroundColor(recipe.difficulty.swiftUIColor)
                    }

                    Text(recipe.title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    HStack(spacing: 12) {
                        Label(recipe.timeDisplay, systemImage: "clock")
                        Label("\(recipe.servings) 人份", systemImage: "person.2")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()

                // Favorite button
                Button {
                    onFavoriteToggle()
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 20))
                        .foregroundColor(isFavorite ? .red : .secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color(.systemBackground))
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
    HistoryView()
        .environmentObject(HistoryViewModel())
        .environmentObject(FavoritesViewModel())
}
