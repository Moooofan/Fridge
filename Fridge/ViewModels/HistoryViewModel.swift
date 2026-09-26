import SwiftUI

/// 歷史紀錄管理 ViewModel
@MainActor
final class HistoryViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var history: [MealHistory] = []
    @Published var selectedHistory: MealHistory?

    // MARK: - Private Properties

    private let store: HistoryStoreProtocol

    // MARK: - Computed Properties

    /// 歷史紀錄數量
    var count: Int {
        history.count
    }

    /// 是否有歷史紀錄
    var hasHistory: Bool {
        !history.isEmpty
    }

    // MARK: - Init

    /// Creates a HistoryViewModel with the specified store
    /// - Parameter store: The store to use for persistence. Defaults to shared HistoryStore.
    init(store: HistoryStoreProtocol = HistoryStore.shared) {
        self.store = store
        loadHistory()
    }

    // MARK: - Methods

    /// 載入歷史紀錄
    func loadHistory() {
        history = store.loadHistory()
    }

    /// 新增歷史紀錄
    func addHistory(
        constraints: MealConstraints,
        ingredients: [UserIngredient],
        response: AIRecipeResponse
    ) {
        let item = MealHistory(
            constraints: constraints,
            ingredients: ingredients,
            menu: response.menu,
            recipes: response.recipes
        )
        store.addHistory(item)
        loadHistory()
    }

    /// 刪除歷史紀錄
    func removeHistory(_ item: MealHistory) {
        store.removeHistory(item)
        loadHistory()
    }

    /// 刪除指定 index 的歷史紀錄
    func removeHistory(at offsets: IndexSet) {
        for index in offsets {
            if index < history.count {
                store.removeHistory(history[index])
            }
        }
        loadHistory()
    }

    /// 清空所有歷史紀錄
    func clearAll() {
        store.clearAll()
        loadHistory()
    }
}
