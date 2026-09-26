import SwiftUI

/// 載入狀態
enum LoadingState<T> {
    case idle
    case loading
    case success(T)
    case error(String)
}

/// 食譜生成與顯示 ViewModel
@MainActor
final class RecipeViewModel: ObservableObject {
    // MARK: - Published Properties

    /// 載入狀態
    @Published var loadingState: LoadingState<AIRecipeResponse> = .idle

    /// 當前查看的食譜
    @Published var selectedRecipe: Recipe?

    /// AI 失敗改用內建食譜時顯示給使用者的說明；nil 表示沒有發生備援
    @Published var fallbackNotice: String?

    /// 步驟完成狀態（RecipeID -> [StepIndex: Bool]）
    @Published var stepProgress: [String: [Int: Bool]] = [:]

    // MARK: - Private Properties

    private let aiService: AIService

    // MARK: - Computed Properties

    /// 是否正在載入
    var isLoading: Bool {
        if case .loading = loadingState { return true }
        return false
    }

    /// 成功取得的回應
    var response: AIRecipeResponse? {
        if case .success(let response) = loadingState { return response }
        return nil
    }

    /// 錯誤訊息
    var errorMessage: String? {
        if case .error(let message) = loadingState { return message }
        return nil
    }

    /// 所有食譜
    var recipes: [Recipe] {
        response?.recipes ?? []
    }

    /// 菜類食譜
    var dishes: [Recipe] {
        recipes.filter { $0.type == .dish }
    }

    /// 湯類食譜
    var soups: [Recipe] {
        recipes.filter { $0.type == .soup }
    }

    /// 菜單資訊
    var menuInfo: MenuInfo? {
        response?.menu
    }

    // MARK: - Init

    init(aiService: AIService? = nil) {
        self.aiService = aiService ?? AIServiceFactory.createService()
    }

    // MARK: - Methods

    /// 生成食譜
    func generateRecipes(
        ingredients: [UserIngredient],
        constraints: MealConstraints,
        preferences: UserPreferences,
        condiments: [String] = []
    ) async {
        guard !ingredients.isEmpty else {
            loadingState = .error("請至少輸入一種食材")
            return
        }

        loadingState = .loading
        fallbackNotice = nil

        let params = AIRequestParams(
            ingredients: ingredients,
            constraints: constraints,
            preferences: preferences,
            condiments: condiments
        )

        do {
            let response = try await aiService.generateRecipes(params: params)
            loadingState = .success(response)
        } catch {
            let aiMessage = error.localizedDescription
            // AI 失敗（金鑰無效、沒網路、額度不足…）時改用內建專業食譜配菜，不讓使用者卡在錯誤頁
            if !(aiService is LocalRecipeService),
               let fallback = try? await LocalRecipeService().generateRecipes(params: params),
               !fallback.recipes.isEmpty {
                fallbackNotice = "AI 暫時無法使用（\(aiMessage)），改用內建的專業廚師食譜為你配菜。"
                loadingState = .success(fallback)
                return
            }
            loadingState = .error(aiMessage)
        }
    }

    /// 重試生成
    func retry(
        ingredients: [UserIngredient],
        constraints: MealConstraints,
        preferences: UserPreferences,
        condiments: [String] = []
    ) async {
        await generateRecipes(
            ingredients: ingredients,
            constraints: constraints,
            preferences: preferences,
            condiments: condiments
        )
    }

    /// 重置狀態
    func reset() {
        loadingState = .idle
        selectedRecipe = nil
        fallbackNotice = nil
        stepProgress.removeAll()
    }

    // MARK: - Step Progress

    /// 切換步驟完成狀態
    func toggleStep(for recipeId: String, stepIndex: Int) {
        stepProgress[recipeId, default: [:]][stepIndex, default: false].toggle()
    }

    /// 檢查步驟是否完成
    func isStepCompleted(for recipeId: String, stepIndex: Int) -> Bool {
        stepProgress[recipeId]?[stepIndex] ?? false
    }

    /// 取得食譜完成進度
    func getProgress(for recipe: Recipe) -> Double {
        guard !recipe.steps.isEmpty else { return 0 }
        let completed = recipe.steps.indices.filter { isStepCompleted(for: recipe.id, stepIndex: $0) }.count
        return Double(completed) / Double(recipe.steps.count)
    }
}
