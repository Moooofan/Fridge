import SwiftUI

/// 調味料管理 ViewModel
@MainActor
final class CondimentViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var condiments: [Condiment] = []
    @Published var categories: [CondimentCategory] = []
    @Published var searchText: String = ""

    // MARK: - Private Properties

    private let store: CondimentStoreProtocol

    // MARK: - Computed Properties

    /// 調味料數量
    var count: Int {
        condiments.count
    }

    /// 是否有調味料
    var hasCondiments: Bool {
        !condiments.isEmpty
    }

    /// 依類別分組的調味料
    var condimentsByCategory: [CondimentCategory: [Condiment]] {
        var result: [CondimentCategory: [Condiment]] = [:]
        for category in categories {
            result[category] = condiments.filter { $0.categoryId == category.id }
        }
        return result
    }

    /// 取得類別（依 ID）
    func category(for id: UUID) -> CondimentCategory? {
        categories.first { $0.id == id }
    }

    /// 取得類別（依名稱）
    func category(named name: String) -> CondimentCategory? {
        categories.first { $0.name == name }
    }

    /// 「其他」類別（fallback）
    var otherCategory: CondimentCategory {
        categories.first { $0.name == "其他" } ?? categories.last ?? CondimentCategory(name: "其他")
    }

    /// 過濾後的建議調味料（排除已新增的）
    func filteredSuggestions(for category: CondimentCategory) -> [CondimentSuggestion] {
        let existingNames = Set(condiments.map { $0.name })
        var suggestions = CondimentSuggestion.suggestionsByCategoryName[category.name] ?? []

        if !searchText.isEmpty {
            suggestions = suggestions.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }

        return suggestions.filter { !existingNames.contains($0.name) }
    }

    /// 調味料名稱列表（用於 AI prompt）
    var condimentNames: [String] {
        condiments.map { $0.name }
    }

    // MARK: - Init

    init(store: CondimentStoreProtocol = CondimentStore.shared) {
        self.store = store
        loadData()
    }

    // MARK: - Data Loading

    /// 載入所有資料
    func loadData() {
        categories = store.loadCategories()
        condiments = store.loadCondiments()
    }

    // MARK: - Condiment Methods

    /// 新增調味料
    func addCondiment(_ condiment: Condiment) {
        guard !condiments.contains(where: { $0.name == condiment.name }) else { return }
        condiments.append(condiment)
        condiments.sort { $0.name < $1.name }
        store.saveCondiments(condiments)
    }

    /// 從建議新增調味料
    func addCondimentFromSuggestion(_ suggestion: CondimentSuggestion) {
        guard let condiment = suggestion.toCondiment(with: categories) else { return }
        addCondiment(condiment)
    }

    /// 新增自訂調味料（從文字輸入）
    func addCustomCondiment(name: String, categoryId: UUID) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let condiment = Condiment(name: trimmed, categoryId: categoryId)
        addCondiment(condiment)
    }

    /// 批次新增調味料
    func addCondiments(_ newCondiments: [Condiment]) {
        for condiment in newCondiments {
            if !condiments.contains(where: { $0.name == condiment.name }) {
                condiments.append(condiment)
            }
        }
        condiments.sort { $0.name < $1.name }
        store.saveCondiments(condiments)
    }

    /// 移除調味料
    func removeCondiment(_ condiment: Condiment) {
        condiments.removeAll { $0.id == condiment.id }
        store.saveCondiments(condiments)
    }

    /// 移除指定 index 的調味料
    func removeCondiment(at offsets: IndexSet) {
        condiments.remove(atOffsets: offsets)
        store.saveCondiments(condiments)
    }

    /// 檢查是否已有該調味料
    func hasCondiment(named name: String) -> Bool {
        condiments.contains { $0.name == name }
    }

    /// 切換調味料（新增或移除）
    func toggleCondiment(_ condiment: Condiment) {
        if let index = condiments.firstIndex(where: { $0.name == condiment.name }) {
            condiments.remove(at: index)
        } else {
            condiments.append(condiment)
            condiments.sort { $0.name < $1.name }
        }
        store.saveCondiments(condiments)
    }

    /// 清空所有調味料
    func clearAllCondiments() {
        condiments.removeAll()
        store.clearAllCondiments()
    }

    // MARK: - Category Methods

    /// 新增類別
    func addCategory(_ category: CondimentCategory) {
        guard !categories.contains(where: { $0.name == category.name }) else { return }
        categories.append(category)
        store.saveCategories(categories)
    }

    /// 新增自訂類別
    func addCustomCategory(name: String, icon: String = "ellipsis.circle.fill") {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let category = CondimentCategory(name: trimmed, icon: icon)
        addCategory(category)
    }

    /// 更新類別
    func updateCategory(_ category: CondimentCategory) {
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index] = category
            store.saveCategories(categories)
        }
    }

    /// 移除類別（同時移除該類別下的調味料）
    func removeCategory(_ category: CondimentCategory) {
        // 移除該類別下的調味料
        condiments.removeAll { $0.categoryId == category.id }
        store.saveCondiments(condiments)

        // 移除類別
        categories.removeAll { $0.id == category.id }
        store.saveCategories(categories)
    }

    /// 重置類別為預設
    func resetCategoriesToDefault() {
        categories = CondimentCategory.defaultCategories
        store.saveCategories(categories)
    }

    /// 檢查類別是否有調味料
    func hasCondiments(in category: CondimentCategory) -> Bool {
        condiments.contains { $0.categoryId == category.id }
    }

    /// 取得類別下的調味料數量
    func condimentCount(in category: CondimentCategory) -> Int {
        condiments.filter { $0.categoryId == category.id }.count
    }

    // MARK: - Clear All

    /// 清空所有資料
    func clearAll() {
        condiments.removeAll()
        categories = CondimentCategory.defaultCategories
        store.clearAll()
    }
}
