import SwiftUI

struct IngredientReviewView: View {
    @ObservedObject var ingredientVM: IngredientViewModel
    @StateObject private var recipeVM = RecipeViewModel()
    /// 使用者不同意 AI 資料使用時改用的離線配菜（LocalRecipeService，不會傳送任何資料）。
    @StateObject private var offlineRecipeVM = RecipeViewModel(aiService: LocalRecipeService(), offlineNotice: RecipeViewModel.consentDeclinedNotice)
    /// 這次產生結果用的是哪一個 ViewModel（結果頁要顯示同一個）。
    @State private var usedOfflineRecipes = false
    @State private var showAIConsent = false
    @StateObject private var settingsVM = SettingsViewModel()
    @EnvironmentObject var historyVM: HistoryViewModel
    @EnvironmentObject var condimentVM: CondimentViewModel

    @State private var newIngredient = ""
    @State private var showRecipeList = false
    @State private var editingIngredient: UserIngredient?
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 標題區
            VStack(spacing: 8) {
                Text("確認食材")
                    .font(.title2.bold())

                Text("可增加、刪除或編輯食材")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 24)
            .padding(.bottom, 16)

            // 新增食材輸入
            HStack(spacing: 12) {
                TextField("新增食材...", text: $newIngredient)
                    .focused($isTextFieldFocused)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Button {
                    addNewIngredient()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(newIngredient.isEmpty ? Color(.systemGray4) : Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(newIngredient.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            // 食材列表
            if ingredientVM.ingredients.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "basket")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.secondary)
                    Text("尚未新增任何食材")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                List {
                    ForEach(ingredientVM.ingredients) { ingredient in
                        IngredientListRow(
                            ingredient: ingredient,
                            onEdit: { editingIngredient = ingredient }
                        )
                    }
                    .onDelete { offsets in
                        ingredientVM.removeIngredient(at: offsets)
                    }
                }
                .listStyle(.plain)
            }

            // 條件摘要
            if !ingredientVM.constraints.isEmpty {
                ConstraintsSummaryBar(constraints: ingredientVM.constraints)
            }

            // 生成按鈕
            Button {
                generateRecipes()
            } label: {
                HStack {
                    if activeRecipeVM.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "wand.and.stars")
                        Text("生成推薦料理")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(canGenerate ? Color.black : Color(.systemGray4))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(!canGenerate || activeRecipeVM.isLoading)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showRecipeList) {
            RecipeListView(recipeVM: activeRecipeVM, ingredientVM: ingredientVM)
        }
        .sheet(isPresented: $showAIConsent) {
            AIConsentView { granted in
                runGeneration(useAI: granted)
            }
        }
        .sheet(item: $editingIngredient) { ingredient in
            EditIngredientSheet(
                ingredient: ingredient,
                onSave: { newName in
                    ingredientVM.updateIngredient(ingredient, newName: newName)
                }
            )
        }
        .onTapGesture {
            isTextFieldFocused = false
        }
    }

    private var canGenerate: Bool {
        !ingredientVM.ingredients.isEmpty
    }

    private func addNewIngredient() {
        ingredientVM.addIngredient(newIngredient)
        newIngredient = ""
    }

    private var activeRecipeVM: RecipeViewModel {
        usedOfflineRecipes ? offlineRecipeVM : recipeVM
    }

    /// App Store 5.1.2(i)：第一次產生食譜前先取得使用者對「傳送資料給 OpenAI」的同意。
    /// 已同意 → 走 AI；曾經明確不同意 → 直接離線配菜（可在設定改回）；還沒回答 → 顯示同意畫面。
    private func generateRecipes() {
        if AIConsentStore.isGranted {
            runGeneration(useAI: true)
        } else if AIConsentStore.hasAnswered {
            runGeneration(useAI: false)
        } else {
            showAIConsent = true
        }
    }

    private func runGeneration(useAI: Bool) {
        usedOfflineRecipes = !useAI
        let vm = activeRecipeVM
        Task {
            await vm.generateRecipes(
                ingredients: ingredientVM.ingredients,
                constraints: ingredientVM.constraints,
                preferences: settingsVM.preferences,
                condiments: condimentVM.condimentNames
            )

            // 成功時儲存歷史紀錄
            if case .success(let response) = vm.loadingState {
                historyVM.addHistory(
                    constraints: ingredientVM.constraints,
                    ingredients: ingredientVM.ingredients,
                    response: response
                )
            }

            // 無論成功或失敗都導航到結果頁（結果頁會顯示錯誤訊息）
            showRecipeList = true
        }
    }
}

// MARK: - Ingredient List Row

private struct IngredientListRow: View {
    let ingredient: UserIngredient
    let onEdit: () -> Void

    var body: some View {
        HStack {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 8, height: 8)

            Text(ingredient.name)
                .font(.body)

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Constraints Summary Bar

private struct ConstraintsSummaryBar: View {
    let constraints: MealConstraints

    var body: some View {
        VStack(spacing: 8) {
            // 餐次資訊
            if let mealDesc = constraints.mealDescription {
                Text(mealDesc)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
            }

            // 其他設定
            HStack(spacing: 16) {
                if let servings = constraints.servings {
                    Label("\(servings) 人", systemImage: "person.2")
                }

                if let dishes = constraints.dishesCount {
                    Label("\(dishes) 菜", systemImage: "fork.knife")
                }

                if let soups = constraints.soupsCount {
                    Label("\(soups) 湯", systemImage: "cup.and.saucer")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
    }
}

// MARK: - Edit Ingredient Sheet

private struct EditIngredientSheet: View {
    let ingredient: UserIngredient
    let onSave: (String) -> Void

    @State private var editedName: String
    @Environment(\.dismiss) var dismiss

    init(ingredient: UserIngredient, onSave: @escaping (String) -> Void) {
        self.ingredient = ingredient
        self.onSave = onSave
        self._editedName = State(initialValue: ingredient.name)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                TextField("食材名稱", text: $editedName)
                    .textFieldStyle(.plain)
                    .padding(16)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                Spacer()
            }
            .navigationTitle("編輯食材")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        onSave(editedName)
                        dismiss()
                    }
                    .disabled(editedName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.height(200)])
    }
}

#Preview {
    NavigationStack {
        IngredientReviewView(ingredientVM: {
            let vm = IngredientViewModel()
            vm.ingredients = [
                UserIngredient(name: "雞蛋"),
                UserIngredient(name: "番茄"),
                UserIngredient(name: "洋蔥"),
                UserIngredient(name: "青椒")
            ]
            vm.constraints.servings = 2
            vm.constraints.dishesCount = 2
            vm.constraints.soupsCount = 1
            return vm
        }())
        .environmentObject(HistoryViewModel())
        .environmentObject(CondimentViewModel())
    }
}
