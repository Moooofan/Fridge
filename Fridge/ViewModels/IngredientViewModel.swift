import SwiftUI
import PhotosUI

/// 食材輸入與管理 ViewModel
@MainActor
final class IngredientViewModel: ObservableObject {
    // MARK: - Published Properties

    /// 用餐條件
    @Published var constraints = MealConstraints()

    /// 使用者輸入的食材列表
    @Published var ingredients: [UserIngredient] = []

    /// 文字輸入內容
    @Published var textInput: String = ""

    /// 選擇的照片
    @Published var selectedImage: UIImage?

    /// 照片補充說明
    @Published var photoNote: String = ""

    /// 是否正在處理
    @Published var isProcessing = false

    /// 錯誤訊息
    @Published var errorMessage: String?

    /// 是否正在辨識照片中的食材
    @Published var isRecognizing = false

    /// 照片辨識錯誤訊息
    @Published var recognitionError: String?

    /// 未同意 AI 資料使用時的照片辨識提示。
    static let consentRequiredMessage = "需要同意使用 AI 才能辨識照片，你也可以改用文字輸入"

    // MARK: - Services

    private let visionService = VisionIngredientService()

    /// 食材名稱同義詞表，僅用於比對去重，不會覆寫使用者原始輸入的顯示名稱
    private static let ingredientSynonyms: [String: String] = [
        "蕃茄": "番茄",
        "土豆": "馬鈴薯",
        "蛋": "雞蛋"
    ]

    // MARK: - Computed Properties

    /// 是否有有效的食材
    var hasIngredients: Bool {
        !ingredients.isEmpty
    }

    /// 食材數量
    var ingredientCount: Int {
        ingredients.count
    }

    // MARK: - Methods

    /// 從文字解析食材（以逗號、頓號、換行、空格分隔）
    func parseTextInput() {
        let items = parseIngredientString(textInput)

        for item in items {
            addIngredient(item)
        }

        textInput = ""
    }

    /// 從照片補充說明解析食材
    func parsePhotoNote() {
        guard !photoNote.isEmpty else { return }

        let items = parseIngredientString(photoNote)

        for item in items {
            addIngredient(item)
        }

        photoNote = ""
    }

    /// 從已選照片呼叫 AI 辨識食材，並合併進現有食材清單（沿用 addIngredient 的去重邏輯）
    func recognizeFromPhoto() async {
        guard let image = selectedImage else { return }
        // 防呆：沒有取得 AI 資料使用同意時絕不送出照片（UI 端應先顯示 AIConsentView）。
        guard AIConsentStore.isGranted else {
            recognitionError = Self.consentRequiredMessage
            return
        }

        isRecognizing = true
        recognitionError = nil
        defer { isRecognizing = false }

        do {
            let names = try await visionService.recognizeIngredients(image: image)
            for name in names {
                addIngredient(name)
            }
        } catch let error as AIServiceError {
            if case .apiError(let message) = error {
                recognitionError = message
            } else {
                recognitionError = error.localizedDescription
            }
        } catch {
            recognitionError = error.localizedDescription
        }
    }

    /// 正規化食材名稱以便比對去重（去除空白、套用同義詞表）
    private func canonicalName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return Self.ingredientSynonyms[trimmed] ?? trimmed
    }

    /// 解析食材字串（支援逗號、頓號、換行、空格分隔）
    private func parseIngredientString(_ input: String) -> [String] {
        // 先用逗號、頓號、換行分隔
        let primarySeparators = CharacterSet(charactersIn: ",、，\n")
        var items: [String] = []

        let primaryParts = input.components(separatedBy: primarySeparators)

        for part in primaryParts {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            // 檢查是否需要用空格進一步分隔
            // 如果包含多個空格分隔的詞，則分開
            let spaceParts = trimmed.components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }

            if spaceParts.count > 1 {
                // 有多個空格分隔的詞，分別加入
                items.append(contentsOf: spaceParts)
            } else {
                // 單一項目
                items.append(trimmed)
            }
        }

        return items
    }

    /// 新增單一食材（比對去重時會正規化名稱，同義詞視為同一項）
    func addIngredient(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let canonical = canonicalName(trimmed)
        guard !ingredients.contains(where: { canonicalName($0.name) == canonical }) else { return }

        ingredients.append(UserIngredient(name: trimmed))
    }

    /// 刪除食材
    func removeIngredient(_ ingredient: UserIngredient) {
        ingredients.removeAll { $0.id == ingredient.id }
    }

    /// 刪除指定 index 的食材
    func removeIngredient(at offsets: IndexSet) {
        ingredients.remove(atOffsets: offsets)
    }

    /// 更新食材名稱
    func updateIngredient(_ ingredient: UserIngredient, newName: String) {
        guard let index = ingredients.firstIndex(where: { $0.id == ingredient.id }) else { return }
        ingredients[index].name = newName
    }

    /// 清空所有食材
    func clearIngredients() {
        ingredients.removeAll()
    }

    /// 重置所有狀態
    func reset() {
        constraints = MealConstraints()
        ingredients.removeAll()
        textInput = ""
        selectedImage = nil
        photoNote = ""
        isProcessing = false
        errorMessage = nil
        isRecognizing = false
        recognitionError = nil
    }

    /// 設定照片（從 PhotosPicker）
    func setImage(_ image: UIImage?) {
        selectedImage = image
    }
}
