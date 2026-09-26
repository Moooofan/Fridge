import Foundation

/// OpenAI API 服務實作
final class OpenAIService: AIService {
    private let apiURL = "https://api.openai.com/v1/chat/completions"
    /// 模型 ID。2026-09-04 依 developers.openai.com/api/docs/models/gpt-5.6-luna 驗證：
    /// 支援 Chat Completions、structured outputs、reasoning_effort（none/low/medium/high）。
    /// GPT-5 系列不接受 temperature / max_tokens，改用 reasoning_effort + max_completion_tokens。
    private static let model = "gpt-5.6-luna"

    /// 上一次成功發出請求的時間，用於簡單的節流保護
    private static var lastRequestDate: Date?
    private static let minRequestInterval: TimeInterval = 3

    private static let systemPrompt = """
    你是擁有 20 年經驗的台灣家常菜主廚。你的任務是依使用者冰箱裡的食材設計菜單。下方提供「專業廚師參考食譜庫」（真實廚師食譜）。規則：\
    (1) 只要參考庫有合適的食譜，必須以它為基礎：菜名、調味比例、步驟順序與火候都要沿用，可依人數等比例調整份量、可省略使用者沒有的次要配料；\
    (2) 每道從參考庫改編的食譜，在 source 欄填入該參考食譜的來源字串（原樣），並在 reason 說明用了哪些冰箱食材；\
    (3) 參考庫沒有合適食譜時才自行設計，此時 source 填 null，且必須是台灣常見家常作法，份量要具體（g/大匙/小匙），不得發明不存在的菜；\
    (4) 不得使用使用者沒有、又無法省略的主食材；\
    (5) 「使用者現有食材」清單中的每一項都必須至少出現在某一道菜或湯的 ingredients 裡，並盡量平均分散到不同菜色（不要全部塞進同一道），除非該項食材明顯不可能入菜（例如調味料以外的非食用品）；\
    (6) 只輸出 JSON。
    """

    func generateRecipes(params: AIRequestParams) async throws -> AIRecipeResponse {
        // 縱深防禦（App Store 5.1.2(i)）：UI 已先取得同意，這裡再檢查一次；
        // 未同意就完全不傳送資料，改用裝置上的內建食譜。
        guard AIConsentStore.isGranted else {
            return try await LocalRecipeService().generateRecipes(params: params)
        }

        // 節流：避免短時間內重複打 API
        if let last = Self.lastRequestDate, Date().timeIntervalSince(last) < Self.minRequestInterval {
            throw AIServiceError.apiError("請稍候再試")
        }

        // 有 Supabase Edge Function 可用時，即使沒有本機 OPENAI_API_KEY 也視為 AI 可用
        // （金鑰留在伺服器端）；兩者都沒有才算真的沒設定好。
        let apiKey = SecretsManager.shared.openAIAPIKey
        guard apiKey != nil || EdgeAIClient.isConfigured else {
            throw AIServiceError.noAPIKey
        }

        // 用冰箱食材比對內建的專業廚師參考食譜，作為 prompt 的依據；同時排除過敏原/不喜歡的食材。
        // 比對是 CPU 密集工作，丟到背景執行緒跑，避免卡住主執行緒。
        var groundedParams = params
        let userIngredientNames = params.ingredients.map { $0.name }
        let condiments = params.condiments
        let excludedTerms = params.preferences.allergies + params.preferences.dislikes
        // 用「盡量涵蓋每一項食材」而非單純總分排序來挑參考食譜，避免冷門食材整批被擠出參考庫
        // （見 RecipeDatabase.matchCoveringAllIngredients 的說明）。
        let refs = await Task.detached(priority: .userInitiated) {
            RecipeDatabase.shared.matchCoveringAllIngredients(userIngredients: userIngredientNames, condiments: condiments, limit: 10, excluding: excludedTerms)
        }.value
        groundedParams.referenceRecipes = refs.map { $0.recipe }

        Self.lastRequestDate = Date()

        let basePrompt = groundedParams.buildPrompt()
        let excludedForCoverage = params.preferences.allergies + params.preferences.dislikes

        do {
            let recipeResponse = try await fetchAndDecode(apiKey: apiKey, userPrompt: basePrompt)
            let filtered = finalize(recipeResponse, references: groundedParams.referenceRecipes, allergies: params.preferences.allergies)
            return try await coverAllIngredientsIfNeeded(
                filtered,
                userIngredientNames: userIngredientNames,
                excluding: excludedForCoverage,
                apiKey: apiKey,
                basePrompt: basePrompt,
                references: groundedParams.referenceRecipes,
                allergies: params.preferences.allergies
            )
        } catch let error as AIServiceError {
            guard case .decodingError = error else { throw error }
            // 解碼失敗只重試一次，附加提示要求模型重新輸出合法 JSON；重試不重新計入 3 秒節流。
            // 這個名額用在修 JSON 上，就不再為了涵蓋率多打一次（每次生成最多重試一次，避免浪費額度），
            // 若這次結果仍缺食材，就照樣回傳，讓 UI 提示使用者哪些食材沒被用到。
            let retryPrompt = basePrompt + "\n\n上一次輸出不是合法 JSON，請重新輸出完整且合法的 JSON。"
            let recipeResponse = try await fetchAndDecode(apiKey: apiKey, userPrompt: retryPrompt)
            return finalize(recipeResponse, references: groundedParams.referenceRecipes, allergies: params.preferences.allergies)
        }
    }

    /// 檢查這次的菜單是否完全沒用到使用者輸入的某些食材；若有，且還沒用過重試名額，
    /// 就多打一次 API，明確點名缺漏的食材要求補上（每次生成最多這一次額外重試）。
    private func coverAllIngredientsIfNeeded(
        _ response: AIRecipeResponse,
        userIngredientNames: [String],
        excluding excluded: [String],
        apiKey: String?,
        basePrompt: String,
        references: [CuratedRecipe],
        allergies: [String]
    ) async throws -> AIRecipeResponse {
        let missing = RecipeDatabase.unusedIngredients(in: response, userIngredients: userIngredientNames, excluding: excluded)
        guard !missing.isEmpty else { return response }

        let coveragePrompt = basePrompt + "\n\n【修正】上一次的菜單完全沒用到這些食材：\(missing.joined(separator: "、"))。請重新設計菜單，確保每一種食材都至少出現在一道菜或湯裡（除非該項食材明顯不可能入菜）。"

        guard let retryResponse = try? await fetchAndDecode(apiKey: apiKey, userPrompt: coveragePrompt) else {
            // 重試失敗（網路、解碼都可能）：回傳原本的結果比整個失敗好，讓 UI 的「未使用食材」提示照舊顯示
            return response
        }
        return finalize(retryResponse, references: references, allergies: allergies)
    }

    /// 補上 source 來源標示、標為 AI 改編、過濾過敏原——AI 回應的共用後處理
    private func finalize(_ response: AIRecipeResponse, references: [CuratedRecipe], allergies: [String]) -> AIRecipeResponse {
        let withSource = markAIAdapted(applySourceFallback(response, references: references))
        return filterOutAllergens(withSource, allergies: allergies)
    }

    /// AI 產生的食譜一律標為「AI 改編」，畫面上以「靈感來源：…（AI 改編）」顯示來源
    private func markAIAdapted(_ response: AIRecipeResponse) -> AIRecipeResponse {
        AIRecipeResponse(menu: response.menu, recipes: response.recipes.map { $0.withSource($0.source, isAIAdapted: true) })
    }

    /// 發送一次請求並解析成食譜 JSON；解碼失敗會拋出 `.decodingError`（呼叫端負責重試邏輯）
    ///
    /// 傳輸層有兩種：Supabase 有設定時一律走 Edge Function（`EdgeAIClient`，金鑰留在伺服器端）；
    /// 否則才直接打 OpenAI API（需要本機 `apiKey`）。兩條路徑回應的 JSON 形狀相同
    /// （`aiProxy.ts` 把 OpenAI 的回應原樣轉傳），所以下面的狀態碼檢查／解碼邏輯共用。
    private func fetchAndDecode(apiKey: String?, userPrompt: String) async throws -> AIRecipeResponse {
        let requestBody: [String: Any] = [
            "messages": [
                [
                    "role": "system",
                    "content": Self.systemPrompt
                ],
                [
                    "role": "user",
                    "content": userPrompt
                ]
            ],
            "reasoning_effort": "low",
            "max_completion_tokens": 6000,
            "response_format": ["type": "json_object"]
        ]

        let data: Data
        let statusCode: Int

        if EdgeAIClient.isConfigured {
            (data, statusCode) = try await EdgeAIClient.send(function: .chat, body: requestBody, timeout: 60)
        } else {
            guard let apiKey else { throw AIServiceError.noAPIKey }
            guard let url = URL(string: apiURL) else { throw AIServiceError.invalidURL }

            var directBody = requestBody
            directBody["model"] = Self.model

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 60
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: directBody)

            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }
            data = responseData
            statusCode = httpResponse.statusCode
        }

        if statusCode != 200 {
            // 嘗試解析錯誤訊息
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                // 把 OpenAI 的英文錯誤換成使用者看得懂的說明（不回傳金鑰片段）
                if message.contains("Incorrect API key") {
                    throw AIServiceError.apiError("API Key 無效，請檢查 Secrets.plist 的設定")
                }
                if message.contains("insufficient_quota") || message.contains("exceeded your current quota") {
                    throw AIServiceError.apiError("OpenAI 額度不足，請到 OpenAI 後台檢查帳單")
                }
                throw AIServiceError.apiError(message)
            }
            throw AIServiceError.apiError("HTTP \(statusCode)")
        }

        // 解析 OpenAI 回應
        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)

        guard let content = openAIResponse.choices.first?.message.content else {
            throw AIServiceError.invalidResponse
        }

        // 解析實際的食譜 JSON
        guard let contentData = content.data(using: .utf8) else {
            throw AIServiceError.invalidResponse
        }

        do {
            return try JSONDecoder().decode(AIRecipeResponse.self, from: contentData)
        } catch {
            #if DEBUG
            print("❌ 解析食譜 JSON 失敗：\(error)")
            print("📄 原始內容：\(content)")
            #endif
            throw AIServiceError.decodingError(error)
        }
    }

    /// 若 AI 忘記填 source，但標題與參考食譜完全相同，就補上來源字串
    private func applySourceFallback(_ response: AIRecipeResponse, references: [CuratedRecipe]) -> AIRecipeResponse {
        guard !references.isEmpty else { return response }

        let recipes = response.recipes.map { recipe -> Recipe in
            let hasSource = !(recipe.source ?? "").isEmpty
            guard !hasSource else { return recipe }
            guard let match = references.first(where: { $0.name == recipe.title }) else { return recipe }
            let attribution = match.attribution
            guard !attribution.isEmpty else { return recipe }
            return recipe.withSource(attribution)
        }

        return AIRecipeResponse(menu: response.menu, recipes: recipes)
    }

    /// 安全防呆：即使 AI 忘記排除，解碼後仍再次檢查，含過敏原食材的食譜靜默捨棄（不額外加提示文字），僅於 DEBUG 記錄
    private func filterOutAllergens(_ response: AIRecipeResponse, allergies: [String]) -> AIRecipeResponse {
        guard !allergies.isEmpty else { return response }

        let filtered = response.recipes.filter { recipe in
            let names = [recipe.title] + recipe.ingredients.map { $0.name }
            let containsAllergen = allergies.contains { allergy in
                names.contains { RecipeDatabase.matches(allergy, $0) }
            }
            #if DEBUG
            if containsAllergen {
                print("⚠️ OpenAIService: 因含過敏原已捨棄食譜「\(recipe.title)」")
            }
            #endif
            return !containsAllergen
        }

        guard filtered.count != response.recipes.count else { return response }
        return AIRecipeResponse(menu: response.menu, recipes: filtered)
    }
}

// MARK: - OpenAI API Response Models

private struct OpenAIResponse: Codable {
    let choices: [Choice]
}

private struct Choice: Codable {
    let message: Message
}

private struct Message: Codable {
    let content: String
}
