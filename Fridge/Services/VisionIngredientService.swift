import Foundation
import UIKit

/// 使用 OpenAI Vision（Chat Completions + image_url）辨識照片中的食材
final class VisionIngredientService {
    private let apiURL = "https://api.openai.com/v1/chat/completions"

    /// 模型 ID，與 OpenAIService 使用同一顆支援圖片輸入的模型。
    /// GPT-5 系列不接受 temperature / max_tokens，改用 reasoning_effort + max_completion_tokens。
    private static let model = "gpt-5.6-luna"

    private static let systemPrompt = """
    你是食材辨識助手，辨識照片中所有可食用的食材，用台灣常見名稱（例如 高麗菜、番茄、雞蛋、豬絞肉、青蔥、蒜頭），忽略調味料罐與包裝文字以外的物件，不確定的不要列。只輸出 JSON：{"ingredients":[{"name":"高麗菜","confidence":0.9}]}
    """

    private static let userPromptText = "請辨識這張冰箱／食材照片裡的食材"

    /// 最長邊縮放後的像素上限
    private static let maxImageSide: CGFloat = 1024
    /// JPEG 壓縮品質
    private static let jpegQuality: CGFloat = 0.7
    /// 信心門檻
    private static let minConfidence: Double = 0.5
    /// 最多回傳幾個食材
    private static let maxIngredientCount = 25

    /// 辨識照片中的食材，回傳去重後的名稱列表
    ///
    /// 傳輸層與 `OpenAIService` 一致：Supabase 有設定時走 Edge Function
    /// （`EdgeAIClient`，金鑰留在伺服器端），否則才直接打 OpenAI API（需要本機 API Key）。
    func recognizeIngredients(image: UIImage) async throws -> [String] {
        // 縱深防禦（App Store 5.1.2(i)）：未同意傳送資料給第三方 AI 時，絕不上傳照片
        guard AIConsentStore.isGranted else {
            throw AIServiceError.apiError("需要先在「設定 > AI 資料使用」同意，才能用照片辨識食材")
        }
        let apiKey = SecretsManager.shared.openAIAPIKey
        guard apiKey != nil || EdgeAIClient.isConfigured else {
            throw AIServiceError.apiError("需要設定 OpenAI API Key 才能辨識照片")
        }

        guard let dataURL = Self.encodeImageAsDataURL(image) else {
            throw AIServiceError.invalidResponse
        }

        let requestBody: [String: Any] = [
            "messages": [
                [
                    "role": "system",
                    "content": Self.systemPrompt
                ],
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": Self.userPromptText
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": dataURL,
                                "detail": "low"
                            ]
                        ]
                    ]
                ]
            ],
            "reasoning_effort": "low",
            "max_completion_tokens": 800,
            "response_format": ["type": "json_object"]
        ]

        let data: Data
        let statusCode: Int

        if EdgeAIClient.isConfigured {
            (data, statusCode) = try await EdgeAIClient.send(function: .vision, body: requestBody, timeout: 60)
        } else {
            guard let apiKey else { throw AIServiceError.apiError("需要設定 OpenAI API Key 才能辨識照片") }
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
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AIServiceError.apiError(message)
            }
            throw AIServiceError.apiError("HTTP \(statusCode)")
        }

        let openAIResponse = try JSONDecoder().decode(VisionOpenAIResponse.self, from: data)

        guard let content = openAIResponse.choices.first?.message.content,
              let contentData = content.data(using: .utf8) else {
            throw AIServiceError.invalidResponse
        }

        do {
            let recognition = try JSONDecoder().decode(VisionRecognitionResult.self, from: contentData)
            return Self.filterAndDedupe(recognition.ingredients)
        } catch {
            #if DEBUG
            print("❌ 解析食材辨識 JSON 失敗：\(error)")
            #endif
            throw AIServiceError.decodingError(error)
        }
    }

    /// 依信心門檻過濾、去除空白重複，最多回傳 maxIngredientCount 筆
    private static func filterAndDedupe(_ items: [VisionRecognizedIngredient]) -> [String] {
        var seen = Set<String>()
        var names: [String] = []

        for item in items {
            guard item.confidence >= minConfidence else { continue }
            let trimmed = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { continue }
            seen.insert(trimmed)
            names.append(trimmed)
            if names.count >= maxIngredientCount { break }
        }

        return names
    }

    /// 將照片縮小至最長邊 ≤ maxImageSide，轉成 JPEG 並編碼為 data URL
    private static func encodeImageAsDataURL(_ image: UIImage) -> String? {
        let resized = resizedImage(image, maxSide: maxImageSide)
        guard let jpegData = resized.jpegData(compressionQuality: jpegQuality) else {
            return nil
        }
        let base64 = jpegData.base64EncodedString()
        return "data:image/jpeg;base64,\(base64)"
    }

    /// 等比例縮小圖片，讓最長邊不超過 maxSide；已經夠小則原圖返回
    private static func resizedImage(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let size = image.size
        let longestSide = max(size.width, size.height)
        guard longestSide > maxSide, longestSide > 0 else {
            return image
        }

        let scale = maxSide / longestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - OpenAI Vision Response Models

private struct VisionOpenAIResponse: Codable {
    let choices: [Choice]

    struct Choice: Codable {
        let message: Message
    }

    struct Message: Codable {
        let content: String
    }
}

private struct VisionRecognitionResult: Codable {
    let ingredients: [VisionRecognizedIngredient]
}

private struct VisionRecognizedIngredient: Codable {
    let name: String
    let confidence: Double
}
