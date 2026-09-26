import Foundation
import SwiftUI

/// 料理類型
enum RecipeType: String, Codable, CaseIterable {
    case dish = "dish"
    case soup = "soup"

    var displayName: String {
        switch self {
        case .dish: return "菜"
        case .soup: return "湯"
        }
    }

    var icon: String {
        switch self {
        case .dish: return "fork.knife"
        case .soup: return "cup.and.saucer.fill"
        }
    }
}

/// 難度等級
enum Difficulty: String, Codable, CaseIterable {
    case easy = "easy"
    case medium = "medium"
    case hard = "hard"

    /// 寬鬆解碼：AI 有時會忘記 prompt 裡「用 easy/medium/hard」的指示，直接填中文顯示字串
    /// （例如 "簡單"）。除了標準 rawValue，也接受這裡列出的中文別名，避免整份食譜因為
    /// 這種小地方解碼失敗、被迫改用離線食譜庫。
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        switch raw {
        case Difficulty.easy.rawValue, "簡單", "容易", "簡易":
            self = .easy
        case Difficulty.medium.rawValue, "中等", "普通", "適中":
            self = .medium
        case Difficulty.hard.rawValue, "困難", "難", "高難度":
            self = .hard
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot initialize Difficulty from invalid String value \(raw)"
            )
        }
    }

    var displayName: String {
        switch self {
        case .easy: return "簡單"
        case .medium: return "中等"
        case .hard: return "困難"
        }
    }

    var color: String {
        switch self {
        case .easy: return "green"
        case .medium: return "orange"
        case .hard: return "red"
        }
    }

    /// SwiftUI Color for this difficulty level
    var swiftUIColor: Color {
        switch self {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }
}

/// 食譜模型
struct Recipe: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let type: RecipeType
    let title: String
    let reason: String
    let timeMinutes: Int
    let difficulty: Difficulty
    let servings: Int
    let ingredients: [Ingredient]
    let steps: [String]
    let tips: [String]
    /// 參考食譜來源（例如專業廚師/節目名），沒有則為 nil
    let source: String?

    /// 時間顯示格式
    var timeDisplay: String {
        if timeMinutes >= 60 {
            let hours = timeMinutes / 60
            let mins = timeMinutes % 60
            if mins == 0 {
                return "\(hours) 小時"
            }
            return "\(hours) 小時 \(mins) 分鐘"
        }
        return "\(timeMinutes) 分鐘"
    }

    /// 用於收藏的唯一標識
    var favoriteId: String {
        id
    }

    // 自定義解碼
    enum CodingKeys: String, CodingKey {
        case id, type, title, reason, timeMinutes, difficulty, servings, ingredients, steps, tips, source
    }

    init(
        id: String,
        type: RecipeType,
        title: String,
        reason: String,
        timeMinutes: Int,
        difficulty: Difficulty,
        servings: Int,
        ingredients: [Ingredient],
        steps: [String],
        tips: [String],
        source: String? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.reason = reason
        self.timeMinutes = timeMinutes
        self.difficulty = difficulty
        self.servings = servings
        self.ingredients = ingredients
        self.steps = steps
        self.tips = tips
        self.source = source
    }

    /// 回傳一份 source 欄位被替換的複本（Recipe 為不可變 struct，供 AI 回應後補上參考來源用）
    func withSource(_ source: String?) -> Recipe {
        Recipe(
            id: id,
            type: type,
            title: title,
            reason: reason,
            timeMinutes: timeMinutes,
            difficulty: difficulty,
            servings: servings,
            ingredients: ingredients,
            steps: steps,
            tips: tips,
            source: source
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // id: 嘗試解碼，若失敗則自動生成
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString

        // type: 必須有
        self.type = try container.decode(RecipeType.self, forKey: .type)

        // title: 必須有
        self.title = try container.decode(String.self, forKey: .title)

        // reason: 可選
        self.reason = try container.decodeIfPresent(String.self, forKey: .reason) ?? ""

        // timeMinutes: 必須有
        self.timeMinutes = try container.decode(Int.self, forKey: .timeMinutes)

        // difficulty: 可選，預設 medium
        self.difficulty = try container.decodeIfPresent(Difficulty.self, forKey: .difficulty) ?? .medium

        // servings: 必須有
        self.servings = try container.decode(Int.self, forKey: .servings)

        // ingredients: 必須有
        self.ingredients = try container.decode([Ingredient].self, forKey: .ingredients)

        // steps: 必須有
        self.steps = try container.decode([String].self, forKey: .steps)

        // tips: 可選
        self.tips = try container.decodeIfPresent([String].self, forKey: .tips) ?? []

        // source: 可選（舊資料沒有這個欄位時為 nil）
        self.source = try container.decodeIfPresent(String.self, forKey: .source)
    }
}

/// 用於步驟勾選狀態追蹤
struct StepProgress: Identifiable {
    let id: Int
    var isCompleted: Bool
    let content: String

    init(index: Int, content: String, isCompleted: Bool = false) {
        self.id = index
        self.content = content
        self.isCompleted = isCompleted
    }
}
