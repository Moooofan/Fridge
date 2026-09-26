import Foundation

/// 收藏儲存管理（使用 UserDefaults）
final class FavoritesStore: FavoritesStoreProtocol {
    static let shared = FavoritesStore()

    private let key = "favorites_recipes"

    init() {}

    /// 載入收藏
    func loadFavorites() -> [Recipe] {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return []
        }

        do {
            let recipes = try JSONDecoder().decode([Recipe].self, from: data)
            return recipes
        } catch {
            print("❌ FavoritesStore: 載入失敗 - \(error)")
            return []
        }
    }

    /// 儲存收藏
    func saveFavorites(_ recipes: [Recipe]) {
        do {
            let data = try JSONEncoder().encode(recipes)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("❌ FavoritesStore: 儲存失敗 - \(error)")
        }
    }

    /// 新增收藏
    func addFavorite(_ recipe: Recipe) {
        var favorites = loadFavorites()
        guard !favorites.contains(where: { $0.id == recipe.id }) else { return }
        favorites.append(recipe)
        saveFavorites(favorites)
    }

    /// 移除收藏
    func removeFavorite(_ recipe: Recipe) {
        var favorites = loadFavorites()
        favorites.removeAll { $0.id == recipe.id }
        saveFavorites(favorites)
    }

    /// 檢查是否已收藏
    func isFavorite(_ recipe: Recipe) -> Bool {
        loadFavorites().contains { $0.id == recipe.id }
    }

    /// 清空所有收藏
    func clearAll() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
