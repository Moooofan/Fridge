# Fridge - 清冰箱好幫手

Fridge 是一款 iOS App，幫助使用者利用冰箱現有食材，透過 AI 推薦適合的料理與食譜。

## 功能特色

- **文字輸入**：直接輸入食材名稱
- **拍照識別**：拍攝或選擇食材照片（MVP 版本需手動補充）
- **用餐設定**：設定人數、菜數、湯數（可選）
- **AI 推薦**：根據食材和偏好生成料理組合
- **完整食譜**：包含步驟、時間、份量、小技巧
- **步驟勾選**：料理時可勾選已完成步驟
- **收藏功能**：保存喜愛的食譜
- **偏好設定**：料理風格、過敏食材、不喜歡的食材

## 系統需求

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## 開發環境設定

### 1. 安裝 xcodegen

```bash
brew install xcodegen
```

### 2. 生成 Xcode 專案

```bash
cd /Users/moooofan/Fridge
xcodegen generate
```

這會根據 `project.yml` 生成 `Fridge.xcodeproj`。

### 3. 開啟專案

```bash
open Fridge.xcodeproj
```

或使用 VSCode + Swift extension 編輯程式碼。

### 4. 設定 API Key（選擇一種方式）

#### 方式 A：使用 Secrets.plist（推薦）

編輯 `Fridge/Resources/Secrets.plist`，將 `YOUR_OPENAI_API_KEY` 替換為你的 OpenAI API Key：

```xml
<key>OPENAI_API_KEY</key>
<string>sk-xxxxxxxxxxxxxxxxxxxxxxxx</string>
```

> 注意：請勿將包含真實 API Key 的檔案提交到版本控制系統！

#### 方式 B：使用環境變數

在 Xcode 中設定 Scheme 環境變數：

1. Product → Scheme → Edit Scheme...
2. Run → Arguments → Environment Variables
3. 新增 `OPENAI_API_KEY` = `sk-xxxxxxxxxxxxxxxxxxxxxxxx`

### 5. Mock 模式

如果沒有設定 API Key，App 會自動使用 Mock 模式，可正常 Demo 所有功能。

## 專案結構

```
Fridge/
├── project.yml              # xcodegen 配置
├── README.md
└── Fridge/
    ├── FridgeApp.swift      # App 入口
    ├── ContentView.swift    # 主要 TabView
    ├── Info.plist
    ├── Resources/
    │   └── Secrets.plist    # API Key 配置
    ├── Models/
    │   ├── Ingredient.swift
    │   ├── MealConstraints.swift
    │   ├── Recipe.swift
    │   ├── AIResponse.swift
    │   └── UserPreferences.swift
    ├── Services/
    │   ├── SecretsManager.swift
    │   ├── AIService.swift
    │   ├── OpenAIService.swift
    │   └── MockAIService.swift
    ├── ViewModels/
    │   ├── HomeViewModel.swift
    │   ├── IngredientViewModel.swift
    │   ├── RecipeViewModel.swift
    │   ├── FavoritesViewModel.swift
    │   └── SettingsViewModel.swift
    ├── Views/
    │   ├── Home/
    │   │   └── HomeView.swift
    │   ├── Input/
    │   │   ├── MealConstraintsView.swift
    │   │   ├── TextInputView.swift
    │   │   ├── PhotoInputView.swift
    │   │   └── IngredientReviewView.swift
    │   ├── Recipe/
    │   │   ├── RecipeListView.swift
    │   │   └── RecipeDetailView.swift
    │   ├── Favorites/
    │   │   └── FavoritesView.swift
    │   ├── Settings/
    │   │   └── SettingsView.swift
    │   └── Components/
    │       ├── RecipeCard.swift
    │       └── LoadingView.swift
    └── Persistence/
        └── FavoritesStore.swift
```

## 使用流程

1. **首頁**：選擇「文字輸入」或「拍照識別」
2. **用餐設定**：設定人數、菜數、湯數（可略過）
3. **食材輸入**：輸入或補充食材
4. **確認食材**：檢視、新增、刪除、編輯食材
5. **生成推薦**：AI 產出菜單組合
6. **查看食譜**：點擊查看詳細步驟
7. **收藏**：保存喜愛的食譜

## 設計風格

- 簡潔、線條感
- 黑白灰為主要配色
- 適量留白
- 圓角元件

## AI Prompt 說明

App 會將使用者的食材清單、用餐條件、偏好設定組合成 prompt，要求 AI 回傳嚴格的 JSON 格式：

```json
{
  "menu": {
    "servings": 2,
    "dishesCount": 2,
    "soupsCount": 1
  },
  "recipes": [
    {
      "id": "uuid-string",
      "type": "dish",
      "title": "料理名稱",
      "reason": "推薦原因",
      "timeMinutes": 15,
      "difficulty": "easy",
      "servings": 2,
      "ingredients": [...],
      "steps": [...],
      "tips": [...]
    }
  ]
}
```

## 注意事項

- 首次使用相機功能需授權
- 收藏資料存於本地 UserDefaults
- 沒有 API Key 時自動使用 Mock 模式

## License

MIT License
