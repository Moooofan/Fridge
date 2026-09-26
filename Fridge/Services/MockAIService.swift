import Foundation

/// Mock AI 服務（用於無 API Key 時的 Demo）
final class MockAIService: AIService {
    /// 模擬網路延遲（秒）
    private let simulatedDelay: TimeInterval = 1.5

    func generateRecipes(params: AIRequestParams) async throws -> AIRecipeResponse {
        // 模擬網路延遲
        try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))

        // 根據使用者條件決定菜單配置
        let servings = params.constraints.servings ?? 2
        let dishesCount = params.constraints.dishesCount ?? 2
        let soupsCount = params.constraints.soupsCount ?? 1

        // 產生 Mock 食譜
        var recipes: [Recipe] = []

        // 產生菜
        let mockDishes = generateMockDishes(count: dishesCount, servings: servings, ingredients: params.ingredients)
        recipes.append(contentsOf: mockDishes)

        // 產生湯
        let mockSoups = generateMockSoups(count: soupsCount, servings: servings, ingredients: params.ingredients)
        recipes.append(contentsOf: mockSoups)

        return AIRecipeResponse(
            menu: MenuInfo(
                servings: servings,
                dishesCount: dishesCount,
                soupsCount: soupsCount
            ),
            recipes: recipes
        )
    }

    private func generateMockDishes(count: Int, servings: Int, ingredients: [UserIngredient]) -> [Recipe] {
        let dishTemplates: [(title: String, reason: String, time: Int, difficulty: Difficulty, mockIngredients: [Ingredient], steps: [String], tips: [String])] = [
            (
                title: "蒜香炒時蔬",
                reason: "簡單快速，能有效利用多種蔬菜食材",
                time: 15,
                difficulty: .easy,
                mockIngredients: [
                    Ingredient(name: "蒜頭", amount: "3瓣", optional: false, substitutes: []),
                    Ingredient(name: "青菜", amount: "300g", optional: false, substitutes: ["高麗菜", "空心菜"]),
                    Ingredient(name: "鹽", amount: "適量", optional: false, substitutes: []),
                    Ingredient(name: "油", amount: "2大匙", optional: false, substitutes: [])
                ],
                steps: [
                    "蒜頭切末備用",
                    "熱鍋下油，爆香蒜末",
                    "加入青菜大火快炒",
                    "加鹽調味，翻炒均勻即可起鍋"
                ],
                tips: [
                    "大火快炒可以保持蔬菜脆嫩",
                    "蒜末不要炒太久避免焦苦"
                ]
            ),
            (
                title: "番茄炒蛋",
                reason: "經典家常菜，營養豐富且老少咸宜",
                time: 10,
                difficulty: .easy,
                mockIngredients: [
                    Ingredient(name: "番茄", amount: "2顆", optional: false, substitutes: []),
                    Ingredient(name: "雞蛋", amount: "3顆", optional: false, substitutes: []),
                    Ingredient(name: "蔥", amount: "1根", optional: true, substitutes: []),
                    Ingredient(name: "糖", amount: "1小匙", optional: false, substitutes: []),
                    Ingredient(name: "鹽", amount: "適量", optional: false, substitutes: [])
                ],
                steps: [
                    "番茄切塊，蔥切段",
                    "雞蛋打散加少許鹽",
                    "熱鍋下油，倒入蛋液炒至半熟盛出",
                    "同鍋炒番茄至軟爛出汁",
                    "加糖、鹽調味，倒回雞蛋拌炒均勻"
                ],
                tips: [
                    "番茄要炒出汁才會好吃",
                    "加點糖可以提鮮並中和酸味"
                ]
            ),
            (
                title: "蔥爆肉片",
                reason: "下飯神器，能快速消耗肉類食材",
                time: 20,
                difficulty: .medium,
                mockIngredients: [
                    Ingredient(name: "豬肉片", amount: "200g", optional: false, substitutes: ["牛肉片", "雞肉片"]),
                    Ingredient(name: "蔥", amount: "3根", optional: false, substitutes: []),
                    Ingredient(name: "醬油", amount: "2大匙", optional: false, substitutes: []),
                    Ingredient(name: "米酒", amount: "1大匙", optional: true, substitutes: []),
                    Ingredient(name: "太白粉", amount: "1小匙", optional: false, substitutes: ["玉米粉"])
                ],
                steps: [
                    "肉片加醬油、米酒、太白粉醃10分鐘",
                    "蔥切段，蔥白蔥綠分開",
                    "熱鍋下油，先炒蔥白爆香",
                    "加入肉片大火快炒至變色",
                    "加入蔥綠翻炒均勻即可"
                ],
                tips: [
                    "肉片要醃過才會嫩",
                    "蔥綠最後再加才能保持翠綠"
                ]
            ),
            (
                title: "醬燒豆腐",
                reason: "素食友善，口感滑嫩又入味",
                time: 25,
                difficulty: .easy,
                mockIngredients: [
                    Ingredient(name: "板豆腐", amount: "1塊", optional: false, substitutes: ["嫩豆腐"]),
                    Ingredient(name: "醬油", amount: "2大匙", optional: false, substitutes: []),
                    Ingredient(name: "糖", amount: "1小匙", optional: false, substitutes: []),
                    Ingredient(name: "蒜頭", amount: "2瓣", optional: true, substitutes: []),
                    Ingredient(name: "蔥", amount: "1根", optional: true, substitutes: [])
                ],
                steps: [
                    "豆腐切塊，用廚房紙巾吸乾水分",
                    "熱鍋下油，豆腐煎至兩面金黃",
                    "加入蒜末爆香",
                    "加醬油、糖、少許水燒至收汁",
                    "撒蔥花即可起鍋"
                ],
                tips: [
                    "豆腐要先吸乾水分才不會油爆",
                    "煎豆腐時不要頻繁翻動"
                ]
            )
        ]

        var result: [Recipe] = []
        for i in 0..<count {
            let template = dishTemplates[i % dishTemplates.count]
            result.append(Recipe(
                id: UUID().uuidString,
                type: .dish,
                title: template.title,
                reason: template.reason,
                timeMinutes: template.time,
                difficulty: template.difficulty,
                servings: servings,
                ingredients: template.mockIngredients,
                steps: template.steps,
                tips: template.tips
            ))
        }
        return result
    }

    private func generateMockSoups(count: Int, servings: Int, ingredients: [UserIngredient]) -> [Recipe] {
        let soupTemplates: [(title: String, reason: String, time: Int, difficulty: Difficulty, mockIngredients: [Ingredient], steps: [String], tips: [String])] = [
            (
                title: "番茄蛋花湯",
                reason: "清爽開胃，製作簡單快速",
                time: 15,
                difficulty: .easy,
                mockIngredients: [
                    Ingredient(name: "番茄", amount: "2顆", optional: false, substitutes: []),
                    Ingredient(name: "雞蛋", amount: "2顆", optional: false, substitutes: []),
                    Ingredient(name: "蔥", amount: "1根", optional: true, substitutes: []),
                    Ingredient(name: "鹽", amount: "適量", optional: false, substitutes: []),
                    Ingredient(name: "香油", amount: "少許", optional: true, substitutes: [])
                ],
                steps: [
                    "番茄切塊，蔥切花",
                    "鍋中加水煮沸，放入番茄",
                    "番茄煮軟後，打入蛋花",
                    "加鹽調味，淋香油",
                    "撒蔥花即可"
                ],
                tips: [
                    "蛋花要順著一個方向攪",
                    "番茄可以先用熱水燙過去皮"
                ]
            ),
            (
                title: "味噌豆腐湯",
                reason: "日式風味，溫暖養胃",
                time: 20,
                difficulty: .easy,
                mockIngredients: [
                    Ingredient(name: "味噌", amount: "2大匙", optional: false, substitutes: []),
                    Ingredient(name: "嫩豆腐", amount: "1盒", optional: false, substitutes: []),
                    Ingredient(name: "海帶芽", amount: "適量", optional: true, substitutes: []),
                    Ingredient(name: "蔥", amount: "1根", optional: true, substitutes: []),
                    Ingredient(name: "柴魚片", amount: "適量", optional: true, substitutes: [])
                ],
                steps: [
                    "水煮沸後轉小火",
                    "味噌用少許熱水調開",
                    "加入豆腐塊和海帶芽",
                    "倒入味噌水拌勻（不要再煮沸）",
                    "撒蔥花即可"
                ],
                tips: [
                    "味噌不能煮沸，否則會失去香氣",
                    "可加柴魚片增添風味"
                ]
            ),
            (
                title: "紫菜蛋花湯",
                reason: "最快速的湯品，5分鐘上桌",
                time: 5,
                difficulty: .easy,
                mockIngredients: [
                    Ingredient(name: "紫菜", amount: "1片", optional: false, substitutes: ["海苔"]),
                    Ingredient(name: "雞蛋", amount: "1顆", optional: false, substitutes: []),
                    Ingredient(name: "鹽", amount: "適量", optional: false, substitutes: []),
                    Ingredient(name: "香油", amount: "少許", optional: true, substitutes: []),
                    Ingredient(name: "蔥", amount: "少許", optional: true, substitutes: [])
                ],
                steps: [
                    "水煮沸後加鹽調味",
                    "紫菜撕碎放入",
                    "打入蛋花",
                    "淋香油，撒蔥花即可"
                ],
                tips: [
                    "紫菜不要煮太久",
                    "可加點蝦皮增添鮮味"
                ]
            )
        ]

        var result: [Recipe] = []
        for i in 0..<count {
            let template = soupTemplates[i % soupTemplates.count]
            result.append(Recipe(
                id: UUID().uuidString,
                type: .soup,
                title: template.title,
                reason: template.reason,
                timeMinutes: template.time,
                difficulty: template.difficulty,
                servings: servings,
                ingredients: template.mockIngredients,
                steps: template.steps,
                tips: template.tips
            ))
        }
        return result
    }
}
