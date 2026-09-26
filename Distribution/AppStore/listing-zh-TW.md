# Fridge — App Store Connect listing（繁體中文）

Localization: 繁體中文（zh-Hant, Taiwan）
Counts computed with Python `len()` (Unicode code points); App Store Connect
is believed to count characters the same way (UNVERIFIED — if the keyword field rejects CJK input, it is counting bytes; trim to ≤100 bytes). UTF-8 byte counts shown for reference.
Generated 2026-09-26.

## App name (≤30)
- **Primary**: `Fridge 清冰箱` — `10/30` OK (10 chars / 16 UTF-8 bytes)
- Fallback 1: `Fridge 清冰箱食譜` — `12/30` OK (12 chars / 22 UTF-8 bytes)
- Fallback 2: `清冰箱 Fridge－AI 家常菜` — `17/30` OK (17 chars / 31 UTF-8 bytes)

"Fridge" alone is very likely taken on the App Store — try the primary first,
then the fallbacks in order.

## Subtitle (≤30) — `15/30` OK (15 chars / 39 UTF-8 bytes)
```
冰箱有什麼，AI 幫你配一桌菜
```

## Promotional text (≤170) — `65/170` OK (65 chars / 179 UTF-8 bytes)
```
今晚煮什麼？輸入或拍下冰箱裡的食材，AI 以 146 道專業家常菜食譜為底，幫你配好幾菜幾湯，份量依人數換算。少買一點、少丟一點。
```

## Description (≤4000) — `611/4000` OK (611 chars / 1639 UTF-8 bytes)
```
把冰箱裡有的，變成今晚的菜。

Fridge 是清冰箱的好幫手：告訴它你手邊有什麼食材、幾個人吃，它就幫你配出一桌家常菜，每道菜都有清楚的份量和步驟。

■ 兩種輸入方式
・打字輸入食材，例如「雞蛋、番茄、高麗菜」
・或拍一張冰箱／食材照片，AI 會辨識出食材，你再確認增減

■ 告訴我們怎麼吃
・選擇日期、早餐／午餐／晚餐、人數
・決定要幾道菜、幾道湯
・在設定裡登記家裡常備的調味料，以及過敏或不吃的食材，推薦時會自動避開

■ 以專業食譜為底，不是憑空亂編
・內建 146 道由專業廚師與料理出版的家常菜食譜
・AI 以這些食譜為基礎來配菜，每道菜都標明參考來源
・份量依人數自動換算

■ 邊煮邊勾
・步驟可以逐一勾選，手忙腳亂也不會漏掉
・喜歡的菜一鍵收藏
・煮過的菜單留在歷史紀錄，下次不用再想

■ 沒網路也能用
・網路不穩或 AI 忙線時，會改用內建食譜幫你配菜，並清楚提示

■ 登入是選擇，不是必須
・可用 Apple、Google 或 LINE 登入，在多台裝置同步收藏
・也可以直接「先逛逛」，不登入就能使用
・可隨時在「設定」中刪除帳號

■ 關於 AI 與隱私
・使用 AI 功能前會先徵求你的同意
・你輸入的食材文字與照片只用來產生食譜，不用於廣告
・詳細說明請見隱私權政策

AI 產生的食譜僅供參考，烹調時請留意食材新鮮度、熟度與個人過敏狀況。

少買、少浪費，讓每一樣食材都有好去處。
```

## Keywords (≤100) — `84/100` OK (84 chars / 206 UTF-8 bytes)
```
食譜,料理,家常菜,煮什麼,晚餐,便當,剩食,惜食,食材,菜單,快速料理,拍照辨識,下廚,烹飪,減少浪費,一週菜單,食物浪費,煮飯,午餐,湯,早餐,省錢,備餐,懶人料理
```
Comma-separated, no spaces after commas, no words from the app name/subtitle
(Apple already indexes those), no competitor or celebrity names.

## What's New (first version) — `40/4000` OK (40 chars / 100 UTF-8 bytes)
```
首次推出 Fridge：輸入或拍照辨識食材，AI 以專業家常菜食譜為底幫你配菜。
```

## Categories
- Primary: 美食佳飲（Food & Drink）
- Secondary: 生活風格（Lifestyle）

## URLs
- Support URL: https://fridge-site.vercel.app
- Marketing URL (optional): https://fridge-site.vercel.app
- Privacy Policy URL: https://fridge-site.vercel.app/privacy.html

## Copyright
```
2026 Ruei-Cheng Wong
```

## Age rating questionnaire
| Question | Answer |
|---|---|
| Cartoon or Fantasy Violence | None |
| Realistic Violence | None |
| Prolonged Graphic or Sadistic Realistic Violence | None |
| Profanity or Crude Humor | None |
| Mature/Suggestive Themes | None |
| Horror/Fear Themes | None |
| Medical/Treatment Information | None |
| Alcohol, Tobacco, or Drug Use or References | None (see note) |
| Simulated Gambling | None |
| Sexual Content or Nudity | None |
| Graphic Sexual Content and Nudity | None |
| Contests | No |
| Unrestricted Web Access | No |
| User-Generated Content shared with others | No |
| Messaging / Chat between users | No |
| Advertising | No |
| Parental Controls | No |
| Age Assurance | No |
| Health or Wellness Topics | No |
| Loot boxes / In-app purchases | No |

**Expected rating: 4+.**

Note: some recipes use cooking wine (米酒／紹興酒) as a seasoning. This is an
ingredient, not a reference to alcohol consumption, so "None" is the usual answer;
if you prefer to be conservative, "Infrequent/Mild" still yields 12+ — decide
before submitting. (The exact questionnaire items change between App Store Connect
versions — UNVERIFIED against the current form; answer any extra item "None/No".)

## App Review notes — `546/4000` OK (546 chars / 1388 UTF-8 bytes)
```
1. 登入為選擇性：啟動後依序為新手導覽（可按「略過」）→ 登入畫面。請點選「先逛逛，之後再登入」即可以訪客身分使用全部核心功能，無需帳號。Apple／Google／LINE 登入僅用於跨裝置同步收藏。
2. 文字輸入測試：首頁「選擇輸入方式」→ 文字輸入，輸入例如「雞蛋、番茄、高麗菜、豬肉」→ 設定人數與菜數 → 產生食譜。
3. 拍照辨識測試：首頁「選擇輸入方式」→ 拍照輸入 → 「相簿」選一張含食材的照片（模擬器可用相簿內圖片），或以實機「拍照」。App 會顯示「AI 辨識中…」並列出辨識到的食材，可再手動補充後按「確認食材」。
4. AI 功能需同意：第一次使用 AI（產生食譜或照片辨識）前，App 會顯示說明並請使用者同意將食材文字／照片傳送至我們的伺服器轉交 AI 服務處理。若不同意，App 會改用內建離線食譜配菜，仍可正常使用。
5. AI 請求透過我們自己的後端（Supabase Edge Functions）轉發，App 內不含任何第三方 AI 金鑰。
6. 帳號刪除：登入後前往「設定 > 刪除帳號」，確認後會刪除帳號與雲端資料。
7. 內建 146 道食譜整理自專業廚師與料理出版的公開家常菜食譜，App 內每道菜標示參考來源；AI 以其為基礎重新組合配菜。
```
Sign-in required for review: **No** (guest mode). No demo account needed.
Before submitting, confirm items 4 and 6 match the shipped build (the AI
consent screen and 設定 > 刪除帳號 were being built in parallel on 2026-09-26).
