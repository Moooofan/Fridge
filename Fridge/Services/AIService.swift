import Foundation

/// AI 服務錯誤類型
enum AIServiceError: LocalizedError {
    case noAPIKey
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "未設定 API Key，請在 Secrets.plist 或環境變數中設定 OPENAI_API_KEY"
        case .invalidURL:
            return "無效的 API URL"
        case .networkError(let error):
            return "網路錯誤：\(error.localizedDescription)"
        case .invalidResponse:
            return "伺服器回應無效"
        case .decodingError(let error):
            return "解析回應失敗：\(error.localizedDescription)"
        case .apiError(let message):
            return "API 錯誤：\(message)"
        }
    }
}

/// AI 服務協議
protocol AIService {
    /// 根據食材和條件生成食譜推薦
    func generateRecipes(params: AIRequestParams) async throws -> AIRecipeResponse
}

/// AI 服務工廠
final class AIServiceFactory {
    /// 根據是否有可用的 AI 後端（本機 OPENAI_API_KEY，或 Supabase Edge Function）決定使用哪個服務
    static func createService() -> AIService {
        if SecretsManager.shared.hasValidAPIKey || EdgeAIClient.isConfigured {
            return OpenAIService()
        } else {
            #if DEBUG
            print("⚠️ 未找到有效的 API Key，使用離線精選食譜資料庫")
            #endif
            return LocalRecipeService()
        }
    }
}
