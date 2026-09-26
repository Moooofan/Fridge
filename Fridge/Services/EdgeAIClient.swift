import Foundation
import Supabase

/// 呼叫 Supabase Edge Function（`openai-chat` / `openai-vision`）取代直接打 OpenAI API 的傳輸層。
///
/// 好處：OpenAI API Key 留在伺服器端（Edge Function secret），不用塞進 App bundle 的
/// `Secrets.plist`。伺服器端（`supabase/functions/_shared/aiProxy.ts`）固定模型、做
/// rate limit，並把 OpenAI 的回應原樣轉傳回來，所以呼叫端（`OpenAIService` /
/// `VisionIngredientService`）沿用既有的 `OpenAIResponse` 解碼與錯誤訊息邏輯即可，
/// 只差在 URL／headers／request body 少了 `model` 欄位（伺服器端固定）。
enum EdgeFunction: String {
    case chat = "openai-chat"
    case vision = "openai-vision"
}

enum EdgeAIClient {
    /// Supabase 是否已設定（`SUPABASE_URL` + `SUPABASE_ANON_KEY`，與 `AuthConfig.isSupabaseConfigured`
    /// 判斷條件相同）；只要這裡是 true，`AIServiceFactory` 就可以在沒有 `OPENAI_API_KEY` 時仍然視為
    /// AI 可用（改走 Edge Function）。
    static var isConfigured: Bool {
        SecretsManager.shared.supabaseURL != nil && SecretsManager.shared.supabaseAnonKey != nil
    }

    /// 送出請求到指定的 Edge Function。`body` 應為 Chat Completions 請求的子集
    /// （`messages` / `reasoning_effort` / `max_completion_tokens` / `response_format`），
    /// 不含 `model`——模型由伺服器端固定（`aiProxy.ts` 的 `MODEL` 常數）。
    ///
    /// 回傳原始回應 body 與 HTTP 狀態碼；HTTP 層以外的網路錯誤（斷線、逾時等）直接拋出，
    /// 由呼叫端既有的 catch 邏輯處理。
    static func send(
        function: EdgeFunction,
        body: [String: Any],
        timeout: TimeInterval = 60
    ) async throws -> (data: Data, statusCode: Int) {
        guard let baseURL = SecretsManager.shared.supabaseURL,
              let anonKey = SecretsManager.shared.supabaseAnonKey else {
            throw AIServiceError.invalidURL
        }

        let url = baseURL.appendingPathComponent("functions/v1/\(function.rawValue)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.addValue(anonKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(await bearerToken(anonKey: anonKey))", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        #if DEBUG
        print("🌐 EdgeAIClient: POST \(url.host ?? "?")\(url.path)")
        #endif

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }
        return (data, httpResponse.statusCode)
    }

    /// 已登入時帶使用者的 Supabase session access token（讓伺服器依 user id 做 rate limit）；
    /// 訪客或沒有有效 session 時退回 anon/publishable key —— Edge Function 的
    /// `auth: ["user", "publishable"]` 兩者都接受，所以訪客一樣能拿到食譜／辨識結果。
    ///
    /// 這裡另外建立一個輕量的 `SupabaseClient` 讀 session，而不是共用
    /// `SupabaseAuthService` 內部的實例：supabase-swift 用 Keychain 存 session，storage key
    /// 是由 Supabase URL 的 host 算出的固定值（`SupabaseClient` 的
    /// `defaultStorageKey = "sb-<host-prefix>-auth-token"`），只要指到同一個
    /// `SUPABASE_URL`，兩個 client 實例就會讀到同一份已登入 session，不需要重構
    /// `SupabaseAuthService` 把內部 client 暴露出來。絕不印出 token 本身。
    private static func bearerToken(anonKey: String) async -> String {
        guard let url = SecretsManager.shared.supabaseURL,
              let key = SecretsManager.shared.supabaseAnonKey else {
            return anonKey
        }
        let client = SupabaseClient(supabaseURL: url, supabaseKey: key)
        if let token = try? await client.auth.session.accessToken {
            return token
        }
        return anonKey
    }
}
