import SwiftUI

/// 設定 ViewModel
@MainActor
final class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var preferences: UserPreferences

    /// 新增過敏食材的輸入
    @Published var newAllergy: String = ""

    /// 新增不喜歡食材的輸入
    @Published var newDislike: String = ""

    // MARK: - Init

    init() {
        self.preferences = UserPreferences.load()
    }

    // MARK: - Cooking Styles

    /// 切換料理風格
    func toggleStyle(_ style: CookingStyle) {
        if let index = preferences.cookingStyles.firstIndex(of: style) {
            // 至少保留一個風格
            if preferences.cookingStyles.count > 1 {
                preferences.cookingStyles.remove(at: index)
            }
        } else {
            preferences.cookingStyles.append(style)
        }
        save()
    }

    /// 檢查風格是否選中
    func isStyleSelected(_ style: CookingStyle) -> Bool {
        preferences.cookingStyles.contains(style)
    }

    // MARK: - Allergies

    /// 新增過敏食材
    func addAllergy() {
        let trimmed = newAllergy.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard !preferences.allergies.contains(trimmed) else { return }

        preferences.allergies.append(trimmed)
        newAllergy = ""
        save()
    }

    /// 移除過敏食材
    func removeAllergy(_ item: String) {
        preferences.allergies.removeAll { $0 == item }
        save()
    }

    /// 移除指定 index 的過敏食材
    func removeAllergy(at offsets: IndexSet) {
        preferences.allergies.remove(atOffsets: offsets)
        save()
    }

    // MARK: - Dislikes

    /// 新增不喜歡的食材
    func addDislike() {
        let trimmed = newDislike.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard !preferences.dislikes.contains(trimmed) else { return }

        preferences.dislikes.append(trimmed)
        newDislike = ""
        save()
    }

    /// 移除不喜歡的食材
    func removeDislike(_ item: String) {
        preferences.dislikes.removeAll { $0 == item }
        save()
    }

    /// 移除指定 index 的不喜歡食材
    func removeDislike(at offsets: IndexSet) {
        preferences.dislikes.remove(atOffsets: offsets)
        save()
    }

    // MARK: - Persistence

    /// 儲存設定
    func save() {
        preferences.save()
    }

    /// 重置為預設值
    func resetToDefaults() {
        preferences = UserPreferences()
        save()
    }
}
