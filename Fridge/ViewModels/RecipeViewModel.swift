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

    /// 菜單完全沒用到某些使用者輸入的食材時顯示的提示；nil 表示都用到了
    @Published var unusedIngredientsNotice: String?

    /// 步驟完成狀態（RecipeID -> [StepIndex: Bool]）
    @Published var stepProgress: [String: [Int: Bool]] = [:]

    // MARK: - Private Properties

    private let aiService: AIService
    /// 成功產生後固定顯示的提示（例如使用者不同意 AI 資料使用、改走離線配菜時）；
    /// AI 失敗改用備援時則顯示備援提示，兩者不會同時出現。
    private let offlineNotice: String?

    /// 使用者不同意 AI 資料使用時，離線配菜結果頂端的提示
    static let consentDeclinedNotice = "目前使用內建離線食譜。想要 AI 依你的食材配菜，可到 設定 > AI 資料使用 開啟。"

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

    init(aiService: AIService? = nil, offlineNotice: String? = nil) {
        self.aiService = aiService ?? AIServiceFactory.createService()
        self.offlineNotice = offlineNotice
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
        unusedIngredientsNotice = nil

        let params = AIRequestParams(
            ingredients: ingredients,
            constraints: constraints,
            preferences: preferences,
            condiments: condiments
        )

        do {
            let response = try await aiService.generateRecipes(params: params)
            fallbackNotice = offlineNotice
            unusedIngredientsNotice = Self.buildUnusedIngredientsNotice(response: response, ingredients: ingredients, preferences: preferences)
            loadingState = .success(response)
            logRecipesGenerated(response, source: aiService is LocalRecipeService ? .local : .ai)
        } catch {
            let aiMessage = error.localizedDescription
            // AI 失敗（金鑰無效、沒網路、額度不足…）時改用內建專業食譜配菜，不讓使用者卡在錯誤頁
            if !(aiService is LocalRecipeService),
               let fallback = try? await LocalRecipeService().generateRecipes(params: params),
               !fallback.recipes.isEmpty {
                fallbackNotice = "AI 暫時無法使用（\(aiMessage)），改用內建的專業廚師食譜為你配菜。"
                unusedIngredientsNotice = Self.buildUnusedIngredientsNotice(response: fallback, ingredients: ingredients, preferences: preferences)
                loadingState = .success(fallback)
                logRecipesGenerated(fallback, source: .localFallback)
                return
            }
            loadingState = .error(aiMessage)
        }
    }

    /// 檢查是否有食材完全沒被用到（已排除過敏原/不喜歡的食材），組成給使用者看的提示文字；都用到了就回傳 nil
    private static func buildUnusedIngredientsNotice(response: AIRecipeResponse, ingredients: [UserIngredient], preferences: UserPreferences) -> String? {
        let names = ingredients.map { $0.name }
        let excluded = preferences.allergies + preferences.dislikes
        let unused = RecipeDatabase.unusedIngredients(in: response, userIngredients: names, excluding: excluded)
        guard !unused.isEmpty else { return nil }
        return "這次沒用到：\(unused.joined(separator: "、"))。可以重新產生一次，或手動調整食材清單。"
    }

    /// 記錄一次食譜生成完成（不含食譜文字／食材名稱，只有菜／湯數量與來源）。
    private func logRecipesGenerated(_ response: AIRecipeResponse, source: AnalyticsEvent.RecipeSource) {
        let dishes = response.recipes.filter { $0.type == .dish }.count
        let soups = response.recipes.filter { $0.type == .soup }.count
        Analytics.log(.recipesGenerated(dishes: dishes, soups: soups, source: source))
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
        unusedIngredientsNotice = nil
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
