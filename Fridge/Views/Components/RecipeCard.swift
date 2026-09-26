import SwiftUI

// MARK: - Recipe Card

struct RecipeCard: View {
    let recipe: Recipe
    let progress: Double
    let isFavorite: Bool
    let onTap: () -> Void
    let onFavoriteToggle: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    // Type badge
                    HStack(spacing: 4) {
                        Image(systemName: recipe.type.icon)
                            .font(.system(size: 12))
                        Text(recipe.type.displayName)
                            .font(.caption.weight(.medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .clipShape(Capsule())

                    Spacer()

                    // Favorite button
                    Button {
                        onFavoriteToggle()
                    } label: {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 18))
                            .foregroundColor(isFavorite ? .red : .secondary)
                    }
                    .buttonStyle(.plain)

                    // Difficulty badge
                    Text(recipe.difficulty.displayName)
                        .font(.caption)
                        .foregroundColor(recipe.difficulty.swiftUIColor)
                }

                // Title
                Text(recipe.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                // Reason
                Text(recipe.reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                // Meta info
                HStack(spacing: 16) {
                    Label(recipe.timeDisplay, systemImage: "clock")
                    Label("\(recipe.servings) 人份", systemImage: "person.2")
                    Label("\(recipe.ingredients.count) 食材", systemImage: "basket")
                }
                .font(.caption)
                .foregroundColor(.secondary)

                // Source caption (if from a curated/reference recipe)
                if let attribution = recipe.attributionText {
                    Text(attribution)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Progress bar (if started)
                if progress > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("進度")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(progress * 100))%")
                                .font(.caption2.weight(.medium))
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color(.systemGray5))
                                    .frame(height: 4)

                                Rectangle()
                                    .fill(Color.black)
                                    .frame(width: geo.size.width * progress, height: 4)
                            }
                            .clipShape(Capsule())
                        }
                        .frame(height: 4)
                    }
                }
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
    VStack(spacing: 16) {
        RecipeCard(
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
                    Ingredient(name: "雞蛋", amount: "3顆")
                ],
                steps: ["步驟1", "步驟2", "步驟3"],
                tips: ["小技巧"]
            ),
            progress: 0.33,
            isFavorite: true,
            onTap: {},
            onFavoriteToggle: {}
        )

        RecipeCard(
            recipe: Recipe(
                id: UUID().uuidString,
                type: .soup,
                title: "番茄蛋花湯",
                reason: "清爽開胃，製作簡單快速",
                timeMinutes: 10,
                difficulty: .easy,
                servings: 4,
                ingredients: [
                    Ingredient(name: "番茄", amount: "2顆"),
                    Ingredient(name: "雞蛋", amount: "2顆")
                ],
                steps: ["步驟1", "步驟2"],
                tips: []
            ),
            progress: 0,
            isFavorite: false,
            onTap: {},
            onFavoriteToggle: {}
        )
    }
    .padding()
    .background(Color(.systemGray6))
}

// MARK: - Recipe Header View

/// Shared recipe header component showing type badge, title, and reason
struct RecipeHeaderView: View {
    let recipe: Recipe

    var body: some View {
        VStack(spacing: 16) {
            // Type Badge
            HStack {
                Image(systemName: recipe.type.icon)
                Text(recipe.type.displayName)
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .clipShape(Capsule())

            // Title
            Text(recipe.title)
                .font(.title.bold())
                .multilineTextAlignment(.center)

            // Reason
            Text(recipe.reason)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6).opacity(0.5))
    }
}

// MARK: - Meta Info Section

/// Shared meta info section showing time, difficulty, and servings
struct RecipeMetaInfoSection: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 0) {
            RecipeMetaInfoItem(
                icon: "clock",
                value: recipe.timeDisplay,
                label: "時間"
            )

            Divider()
                .frame(height: 40)

            RecipeMetaInfoItem(
                icon: "chart.bar",
                value: recipe.difficulty.displayName,
                label: "難度"
            )

            Divider()
                .frame(height: 40)

            RecipeMetaInfoItem(
                icon: "person.2",
                value: "\(recipe.servings) 人",
                label: "份量"
            )
        }
        .padding(.vertical, 16)
        .background(Color(.systemGray6).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Individual meta info item
private struct RecipeMetaInfoItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .light))
                .foregroundColor(.secondary)

            Text(value)
                .font(.subheadline.weight(.semibold))

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Ingredients Section

/// Shared ingredients section with optional expand/collapse
struct RecipeIngredientsSection: View {
    let ingredients: [Ingredient]
    @State private var showAll = false

    private var displayedIngredients: [Ingredient] {
        if showAll || ingredients.count <= 5 {
            return ingredients
        }
        return Array(ingredients.prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("食材")
                    .font(.headline)
                Spacer()
                Text("\(ingredients.count) 項")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Ingredients List
            VStack(spacing: 12) {
                ForEach(displayedIngredients) { ingredient in
                    RecipeIngredientRow(ingredient: ingredient)
                }

                // Show more button
                if ingredients.count > 5 && !showAll {
                    Button {
                        withAnimation {
                            showAll = true
                        }
                    } label: {
                        HStack {
                            Text("顯示全部 \(ingredients.count) 項")
                            Image(systemName: "chevron.down")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
        }
    }
}

/// Individual ingredient row
struct RecipeIngredientRow: View {
    let ingredient: Ingredient

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(ingredient.optional ? Color(.systemGray4) : Color.black)
                    .frame(width: 6, height: 6)

                Text(ingredient.name)
                    .font(.body)

                if ingredient.optional {
                    Text("(可選)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(ingredient.amount)
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            // Substitutes
            if !ingredient.substitutes.isEmpty {
                HStack {
                    Text("可替換：")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(ingredient.substitutes.joined(separator: "、"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 14)
            }
        }
    }
}

// MARK: - Steps Section

/// Shared steps section with checkable progress
struct RecipeStepsSection: View {
    let steps: [String]
    @Binding var stepCompletion: [Int: Bool]

    private var completedCount: Int {
        steps.indices.filter { stepCompletion[$0] ?? false }.count
    }

    private var progress: Double {
        guard !steps.isEmpty else { return 0 }
        return Double(completedCount) / Double(steps.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("步驟")
                    .font(.headline)
                Spacer()
                Text("\(completedCount)/\(steps.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 4)

                    Rectangle()
                        .fill(Color.black)
                        .frame(width: geo.size.width * progress, height: 4)
                }
                .clipShape(Capsule())
            }
            .frame(height: 4)

            // Steps List
            VStack(spacing: 16) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    RecipeStepRow(
                        index: index,
                        content: step,
                        isCompleted: stepCompletion[index] ?? false,
                        onToggle: {
                            stepCompletion[index] = !(stepCompletion[index] ?? false)
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Steps Section (RecipeVM-backed for step persistence)
// Shared across RecipeDetailView / FavoriteRecipeDetailView / HistoryDetailView so step
// completion is tracked via RecipeViewModel.stepProgress and persists while the app is running.

struct RecipeVMStepsSection: View {
    let recipe: Recipe
    @ObservedObject var recipeVM: RecipeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("步驟")
                    .font(.headline)
                Spacer()
                Text("\(completedCount)/\(recipe.steps.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 4)

                    Rectangle()
                        .fill(Color.black)
                        .frame(width: geo.size.width * progress, height: 4)
                }
                .clipShape(Capsule())
            }
            .frame(height: 4)

            // Steps List
            VStack(spacing: 16) {
                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                    RecipeStepRow(
                        index: index,
                        content: step,
                        isCompleted: recipeVM.isStepCompleted(for: recipe.id, stepIndex: index),
                        onToggle: {
                            recipeVM.toggleStep(for: recipe.id, stepIndex: index)
                        }
                    )
                }
            }
        }
    }

    private var completedCount: Int {
        recipe.steps.indices.filter { recipeVM.isStepCompleted(for: recipe.id, stepIndex: $0) }.count
    }

    private var progress: Double {
        guard !recipe.steps.isEmpty else { return 0 }
        return Double(completedCount) / Double(recipe.steps.count)
    }
}

/// Individual step row
struct RecipeStepRow: View {
    let index: Int
    let content: String
    let isCompleted: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 16) {
                // Step number / check
                ZStack {
                    Circle()
                        .fill(isCompleted ? Color.black : Color(.systemGray6))
                        .frame(width: 32, height: 32)

                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text("\(index + 1)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }

                // Content
                Text(content)
                    .font(.body)
                    .foregroundColor(isCompleted ? .secondary : .primary)
                    .strikethrough(isCompleted)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tips Section

/// Shared tips section with orange styling
struct RecipeTipsSection: View {
    let tips: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lightbulb")
                    .foregroundColor(.orange)
                Text("小技巧")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(tips.enumerated()), id: \.offset) { _, tip in
                    HStack(alignment: .top, spacing: 12) {
                        Text("•")
                            .foregroundColor(.orange)
                        Text(tip)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
