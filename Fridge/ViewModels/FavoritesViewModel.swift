import SwiftUI

/// 收藏管理 ViewModel
@MainActor
final class FavoritesViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var favorites: [Recipe] = []
    @Published var selectedRecipe: Recipe?

    // MARK: - Private Properties

    private let store: FavoritesStoreProtocol

    // MARK: - Computed Properties

    /// 收藏數量
    var count: Int {
        favorites.count
    }

    /// 是否有收藏
    var hasFavorites: Bool {
        !favorites.isEmpty
    }

    // MARK: - Init

    /// Creates a FavoritesViewModel with the specified store
    /// - Parameter store: The store to use for persistence. Defaults to shared FavoritesStore.
    init(store: FavoritesStoreProtocol = FavoritesStore.shared) {
        self.store = store
        loadFavorites()
    }

    // MARK: - Methods

    /// 載入收藏
    func loadFavorites() {
        favorites = store.loadFavorites()
    }

    /// 新增收藏
    func addFavorite(_ recipe: Recipe) {
        guard !isFavorite(recipe) else { return }
        favorites.append(recipe)
        store.saveFavorites(favorites)
    }

    /// 移除收藏
    func removeFavorite(_ recipe: Recipe) {
        favorites.removeAll { isSameRecipe($0, recipe) }
        store.saveFavorites(favorites)
    }

    /// 移除指定 index 的收藏
    func removeFavorite(at offsets: IndexSet) {
        favorites.remove(atOffsets: offsets)
        store.saveFavorites(favorites)
    }

    /// 切換收藏狀態
    func toggleFavorite(_ recipe: Recipe) {
        if isFavorite(recipe) {
            removeFavorite(recipe)
        } else {
            addFavorite(recipe)
        }
    }

    /// 檢查是否已收藏
    func isFavorite(_ recipe: Recipe) -> Bool {
        favorites.contains { isSameRecipe($0, recipe) }
    }

    /// 判斷兩道食譜是否視為同一道菜：id 相同，或 (title + type) 相同
    /// （AI 重新生成的相同菜色 id 不同，但仍應視為已收藏）
    private func isSameRecipe(_ lhs: Recipe, _ rhs: Recipe) -> Bool {
        lhs.id == rhs.id || (lhs.title == rhs.title && lhs.type == rhs.type)
    }

    /// 清空所有收藏
    func clearAll() {
        favorites.removeAll()
        store.saveFavorites(favorites)
    }
}
