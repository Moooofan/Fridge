import Foundation

// MARK: - Protocol Definitions

/// Protocol for managing favorites persistence
protocol FavoritesStoreProtocol {
    func loadFavorites() -> [Recipe]
    func saveFavorites(_ recipes: [Recipe])
    func addFavorite(_ recipe: Recipe)
    func removeFavorite(_ recipe: Recipe)
    func isFavorite(_ recipe: Recipe) -> Bool
    func clearAll()
}

/// Protocol for managing history persistence
protocol HistoryStoreProtocol {
    func loadHistory() -> [MealHistory]
    func saveHistory(_ history: [MealHistory])
    func addHistory(_ item: MealHistory)
    func removeHistory(_ item: MealHistory)
    func clearAll()
}

// MARK: - In-Memory Stores for Testing

/// In-memory implementation for unit testing favorites
final class InMemoryFavoritesStore: FavoritesStoreProtocol {
    private var favorites: [Recipe] = []

    func loadFavorites() -> [Recipe] {
        favorites
    }

    func saveFavorites(_ recipes: [Recipe]) {
        favorites = recipes
    }

    func addFavorite(_ recipe: Recipe) {
        guard !favorites.contains(where: { $0.id == recipe.id }) else { return }
        favorites.append(recipe)
    }

    func removeFavorite(_ recipe: Recipe) {
        favorites.removeAll { $0.id == recipe.id }
    }

    func isFavorite(_ recipe: Recipe) -> Bool {
        favorites.contains { $0.id == recipe.id }
    }

    func clearAll() {
        favorites.removeAll()
    }
}

/// In-memory implementation for unit testing history
final class InMemoryHistoryStore: HistoryStoreProtocol {
    private var history: [MealHistory] = []
    private let maxHistoryCount = 50

    func loadHistory() -> [MealHistory] {
        history.sorted { $0.createdAt > $1.createdAt }
    }

    func saveHistory(_ history: [MealHistory]) {
        self.history = Array(history.prefix(maxHistoryCount))
    }

    func addHistory(_ item: MealHistory) {
        history.insert(item, at: 0)
        if history.count > maxHistoryCount {
            history = Array(history.prefix(maxHistoryCount))
        }
    }

    func removeHistory(_ item: MealHistory) {
        history.removeAll { $0.id == item.id }
    }

    func clearAll() {
        history.removeAll()
    }
}

// MARK: - History Store Implementation

/// 歷史紀錄儲存管理（使用 UserDefaults）
final class HistoryStore: HistoryStoreProtocol {
    static let shared = HistoryStore()

    private let key = "meal_history"
    private let maxHistoryCount = 50 // 最多保留 50 筆

    init() {}

    /// 載入歷史紀錄
    func loadHistory() -> [MealHistory] {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return []
        }

        do {
            let history = try JSONDecoder().decode([MealHistory].self, from: data)
            return history.sorted { $0.createdAt > $1.createdAt }
        } catch {
            print("HistoryStore: 載入失敗 - \(error)")
            return []
        }
    }

    /// 儲存歷史紀錄
    func saveHistory(_ history: [MealHistory]) {
        do {
            // 只保留最新的 maxHistoryCount 筆
            let trimmed = Array(history.prefix(maxHistoryCount))
            let data = try JSONEncoder().encode(trimmed)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("HistoryStore: 儲存失敗 - \(error)")
        }
    }

    /// 新增歷史紀錄
    func addHistory(_ item: MealHistory) {
        var history = loadHistory()
        history.insert(item, at: 0) // 最新的在前面
        saveHistory(history)
    }

    /// 刪除歷史紀錄
    func removeHistory(_ item: MealHistory) {
        var history = loadHistory()
        history.removeAll { $0.id == item.id }
        saveHistory(history)
    }

    /// 清空所有歷史紀錄
    func clearAll() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
