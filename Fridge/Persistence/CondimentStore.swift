import Foundation

/// Protocol for managing condiment persistence
protocol CondimentStoreProtocol {
    // Condiments
    func loadCondiments() -> [Condiment]
    func saveCondiments(_ condiments: [Condiment])
    func addCondiment(_ condiment: Condiment)
    func removeCondiment(_ condiment: Condiment)
    func clearAllCondiments()

    // Categories
    func loadCategories() -> [CondimentCategory]
    func saveCategories(_ categories: [CondimentCategory])
    func addCategory(_ category: CondimentCategory)
    func removeCategory(_ category: CondimentCategory)
    func updateCategory(_ category: CondimentCategory)
    func clearAllCategories()

    // Clear all
    func clearAll()
}

/// In-memory implementation for unit testing
final class InMemoryCondimentStore: CondimentStoreProtocol {
    private var condiments: [Condiment] = []
    private var categories: [CondimentCategory] = CondimentCategory.defaultCategories

    // MARK: - Condiments

    func loadCondiments() -> [Condiment] {
        condiments
    }

    func saveCondiments(_ condiments: [Condiment]) {
        self.condiments = condiments
    }

    func addCondiment(_ condiment: Condiment) {
        guard !condiments.contains(where: { $0.id == condiment.id }) else { return }
        condiments.append(condiment)
    }

    func removeCondiment(_ condiment: Condiment) {
        condiments.removeAll { $0.id == condiment.id }
    }

    func clearAllCondiments() {
        condiments.removeAll()
    }

    // MARK: - Categories

    func loadCategories() -> [CondimentCategory] {
        categories
    }

    func saveCategories(_ categories: [CondimentCategory]) {
        self.categories = categories
    }

    func addCategory(_ category: CondimentCategory) {
        guard !categories.contains(where: { $0.id == category.id }) else { return }
        categories.append(category)
    }

    func removeCategory(_ category: CondimentCategory) {
        categories.removeAll { $0.id == category.id }
    }

    func updateCategory(_ category: CondimentCategory) {
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index] = category
        }
    }

    func clearAllCategories() {
        categories = CondimentCategory.defaultCategories
    }

    func clearAll() {
        condiments.removeAll()
        categories = CondimentCategory.defaultCategories
    }
}

/// 調味料儲存管理（使用 UserDefaults）
final class CondimentStore: CondimentStoreProtocol {
    static let shared = CondimentStore()

    private let condimentsKey = "user_condiments"
    private let categoriesKey = "user_condiment_categories"

    init() {}

    // MARK: - Condiments

    /// 載入調味料
    func loadCondiments() -> [Condiment] {
        guard let data = UserDefaults.standard.data(forKey: condimentsKey) else {
            return []
        }

        do {
            let condiments = try JSONDecoder().decode([Condiment].self, from: data)
            return condiments.sorted { $0.name < $1.name }
        } catch {
            print("CondimentStore: 載入調味料失敗 - \(error)")
            return []
        }
    }

    /// 儲存調味料
    func saveCondiments(_ condiments: [Condiment]) {
        do {
            let data = try JSONEncoder().encode(condiments)
            UserDefaults.standard.set(data, forKey: condimentsKey)
        } catch {
            print("CondimentStore: 儲存調味料失敗 - \(error)")
        }
    }

    /// 新增調味料
    func addCondiment(_ condiment: Condiment) {
        var condiments = loadCondiments()
        guard !condiments.contains(where: { $0.name == condiment.name }) else { return }
        condiments.append(condiment)
        saveCondiments(condiments)
    }

    /// 移除調味料
    func removeCondiment(_ condiment: Condiment) {
        var condiments = loadCondiments()
        condiments.removeAll { $0.id == condiment.id }
        saveCondiments(condiments)
    }

    /// 清空所有調味料
    func clearAllCondiments() {
        UserDefaults.standard.removeObject(forKey: condimentsKey)
    }

    // MARK: - Categories

    /// 載入類別
    func loadCategories() -> [CondimentCategory] {
        guard let data = UserDefaults.standard.data(forKey: categoriesKey) else {
            // 第一次使用，回傳預設類別
            return CondimentCategory.defaultCategories
        }

        do {
            let categories = try JSONDecoder().decode([CondimentCategory].self, from: data)
            return categories
        } catch {
            print("CondimentStore: 載入類別失敗 - \(error)")
            return CondimentCategory.defaultCategories
        }
    }

    /// 儲存類別
    func saveCategories(_ categories: [CondimentCategory]) {
        do {
            let data = try JSONEncoder().encode(categories)
            UserDefaults.standard.set(data, forKey: categoriesKey)
        } catch {
            print("CondimentStore: 儲存類別失敗 - \(error)")
        }
    }

    /// 新增類別
    func addCategory(_ category: CondimentCategory) {
        var categories = loadCategories()
        guard !categories.contains(where: { $0.id == category.id }) else { return }
        categories.append(category)
        saveCategories(categories)
    }

    /// 移除類別
    func removeCategory(_ category: CondimentCategory) {
        var categories = loadCategories()
        categories.removeAll { $0.id == category.id }
        saveCategories(categories)
    }

    /// 更新類別
    func updateCategory(_ category: CondimentCategory) {
        var categories = loadCategories()
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index] = category
            saveCategories(categories)
        }
    }

    /// 重置類別為預設
    func clearAllCategories() {
        UserDefaults.standard.removeObject(forKey: categoriesKey)
    }

    /// 清空所有資料
    func clearAll() {
        UserDefaults.standard.removeObject(forKey: condimentsKey)
        UserDefaults.standard.removeObject(forKey: categoriesKey)
    }
}
