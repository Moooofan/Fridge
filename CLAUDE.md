# Fridge - iOS App

## Project Overview
Fridge 是一個 iOS App，幫助使用者「清冰箱」- 輸入現有食材，AI 會推薦適合的食譜。

## Tech Stack
- **Language**: Swift 5.9
- **UI Framework**: SwiftUI
- **Target**: iOS 17.0+
- **Project Management**: xcodegen (project.yml)
- **Architecture**: MVVM

## Project Structure
```
Fridge/
├── Models/          # 資料模型 (Recipe, Ingredient, MealHistory, etc.)
├── ViewModels/      # 業務邏輯 (IngredientVM, RecipeVM, FavoritesVM, HistoryVM)
├── Views/           # UI 元件
│   ├── Home/        # 首頁
│   ├── Input/       # 食材輸入流程
│   ├── Recipe/      # 食譜顯示
│   ├── History/     # 歷史紀錄
│   ├── Favorites/   # 收藏
│   ├── Settings/    # 設定
│   └── Components/  # 共用元件
├── Services/        # AI 服務 (OpenAI, Mock)
├── Persistence/     # 本地儲存 (UserDefaults)
└── Resources/       # 資源檔案 (Secrets.plist)
```

## Key Commands
```bash
# 重新生成 Xcode 專案
xcodegen generate

# 建置
xcodebuild -project Fridge.xcodeproj -scheme Fridge -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# 安裝到模擬器
xcrun simctl install booted [app_path]

# 執行 App
xcrun simctl launch booted com.moooofan.fridge
```

## API Configuration
- OpenAI API Key 存放在 `Fridge/Resources/Secrets.plist`
- Key name: `OPENAI_API_KEY`

## Important Files
- `project.yml` - xcodegen 設定檔
- `Fridge/Services/OpenAIService.swift` - OpenAI API 整合
- `Fridge/Models/AIResponse.swift` - AI 回應格式定義

## Coding Guidelines
- 使用繁體中文 (zh_TW) 作為 UI 語言
- 遵循 SwiftUI 最佳實踐
- 使用 @Published 和 ObservableObject 做狀態管理
- EnvironmentObject 用於跨 View 共享狀態
- 所有 ViewModel 標記為 @MainActor

## Current Features
1. 食材輸入 (文字/照片)
2. 用餐條件設定 (日期、餐次、人數、菜數、湯數)
3. AI 食譜推薦
4. 食譜詳情 (可勾選步驟)
5. 收藏功能
6. 歷史紀錄

## Recipe Grounding & Vision (added 2026-09-04)
- `Fridge/Resources/CuratedRecipes.json` — 146 道專業廚師家常菜（阿基師／詹姆士／楊桃美食網／食譜自由配等），schema 見 `Fridge/Models/CuratedRecipe.swift`。新增食譜請沿用同一 schema，`mainIngredients.name` 必須用 `RecipeDatabase.synonymTable` 的標準名。
- `Fridge/Services/RecipeDatabase.swift` — 載入 JSON、同義詞正規化、依冰箱食材評分比對（主食材 ×3、配料 ×1、調味 ×0.25），支援 `excluding:`（過敏原／不喜歡）與 `preferFast`。
- `Fridge/Services/OpenAIService.swift` — 模型 `gpt-5.6-luna`（GPT-5 系列：用 `reasoning_effort` + `max_completion_tokens`，不可送 `temperature`/`max_tokens`）。Prompt 會附上最相關 10 道參考食譜，要求 AI 以其為基礎；解碼失敗自動重試一次；回傳後再過濾過敏原。
- `Fridge/Services/LocalRecipeService.swift` — 沒有 API Key 時的離線配菜（份量會依人數等比例換算）。
- `Fridge/Services/VisionIngredientService.swift` — 拍照辨識食材（同模型、圖片縮到 1024px JPEG 0.7）。
- 建置需要 Xcode 對應版本的 iOS 平台（Xcode 26.6 → iOS 26.5）；缺少時執行 `xcodebuild -downloadPlatform iOS`。
- 純邏輯驗證不必開模擬器：`xcrun swiftc -typecheck -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -target arm64-apple-ios17.0-simulator $(find Fridge -name '*.swift')`。
- AI 呼叫失敗（金鑰無效／沒網路／額度不足）時 `RecipeViewModel` 會自動改用 `LocalRecipeService` 並在清單頂端顯示提示（`fallbackNotice`）。
- DEBUG 專用示範模式（`Fridge/Services/DemoLaunch.swift`）：`xcrun simctl launch <udid> com.moooofan.fridge -demo list|detail|nokey` 可直接跳到食譜清單／詳情／真實服務路徑，配合 `simctl io <udid> screenshot` 做無互動的畫面驗證。Release 不含此程式碼。

## Onboarding & Login (added 2026-09-11)
- 啟動流程由 `Fridge/Models/AppFlow.swift` 的 `AppFlowState.stage` 控制：`onboarding`（首次）→ `login` → `main`。`hasCompletedOnboarding` 存 UserDefaults；設定頁有「重看新手導覽」。
- 登入：`Fridge/Views/Auth/LoginView.swift` 提供 Apple／Google／LINE 與「先逛逛」訪客模式（App Store 5.1.1 要求不得強制登入）。`AuthServiceFactory` 依 Secrets.plist 是否有 `SUPABASE_URL`+`SUPABASE_ANON_KEY` 決定用 `SupabaseAuthService`（雲端帳號）或 `LocalAuthService`（Apple 本機登入；Google／LINE 另需 `GOOGLE_CLIENT_ID`／`LINE_CHANNEL_ID`，缺少時顯示「尚未設定」）。
- SPM 套件（project.yml `packages:`）：supabase-swift 2.55.2、GoogleSignIn-iOS 10.0.0、LineSDK 5.17.0。Sign in with Apple 能力在 `Fridge/Fridge.entitlements`。
- LINE 在 Supabase 端是自訂 OIDC 提供者，iOS 走 `ASWebAuthenticationSession` 到 `/auth/v1/authorize?provider=custom:line`（slug 可用 `LINE_SUPABASE_PROVIDER` 覆寫），自行做 PKCE，回呼 `fridge://auth-callback` 拿 `code` 後 POST `/auth/v1/token?grant_type=pkce` 再 `auth.setSession`。supabase-swift 2.55.2 的 Provider enum 是封閉的，不能用 SDK 的 signInWithOAuth。
- 模擬器跑登入相關功能要用 ad-hoc 簽署（`CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO`），否則 supabase-swift 無法寫 Keychain。DEBUG 示範：`-demo onboarding` / `-demo login`。
- Apple Developer Team ID：P9Z76UZ829（個人帳號）。TestFlight 上傳腳本在 `Distribution/testflight.sh`。

## Backend (Supabase `fridge`, added 2026-09-11)
- 專案 ref `sqninmyidhgfjyvulayr`（Tokyo）。App 用 `SUPABASE_URL` + `SUPABASE_ANON_KEY`（新版 `sb_publishable_…`）。金鑰與 DB 密碼在 `~/.config/fridge/.env`（chmod 600，不進 repo）。
- **OpenAI 金鑰不再放在 App**：`Fridge/Services/EdgeAIClient.swift` 打 Edge Functions `openai-chat` / `openai-vision`（`supabase/functions/`，共用 `_shared/aiProxy.ts`），模型固定 `gpt-5.6-luna`，每呼叫者 10 分鐘 20 次（`rate_limits` 表，migration 在 `supabase/migrations/`）。部署：`supabase functions deploy <fn> --use-api --project-ref sqninmyidhgfjyvulayr`；金鑰：`supabase secrets set --project-ref … --env-file <file>`。
- Auth 設定用 `supabase/config.toml` + `supabase config push --project-ref …`：Apple（bundle id）、Google（web client id + iOS client id，secret 由環境變數 `SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET` 注入，值在 ~/.config/fridge/.env）。LINE 為自訂 OIDC 提供者 `custom:line`（已用 `POST /auth/v1/admin/custom-providers` 註冊，issuer access.line.me，scopes openid+profile）。LINE channel 2011558204 目前為 Developing，公開前要在 LINE Developers 按 Publish。
- Google Cloud 專案 `fridge-508306`（ray860408@gmail.com）；OAuth 同意畫面為「測試中」，只有測試使用者名單能用 Google 登入，正式上線前要在 Google Auth Platform > 目標對象按「發布應用程式」。
- 若 AI 回傳的 `difficulty` 是中文，`Recipe.Difficulty` 的寬鬆解碼會接受（2026-09-11 實測模型偶爾這樣回）。
- 官網／隱私權／服務條款靜態頁在 `Website/`，部署於 Vercel 專案 `fridge-site`（https://fridge-site.vercel.app ，`cd Website && vercel deploy --prod --yes`）。Google OAuth 已於 2026-09-11 發布為正式（外部），只用 openid/profile/email 不需驗證；勿上傳 Logo，否則會觸發 Google 驗證流程。
