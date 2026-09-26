# Fridge — App Store Connect listing (English)

Localization: English (U.S.) — optional localization
Counts computed with Python `len()` (Unicode code points); App Store Connect
is believed to count characters the same way (UNVERIFIED — if the keyword field rejects CJK input, it is counting bytes; trim to ≤100 bytes). UTF-8 byte counts shown for reference.
Generated 2026-09-26.

## App name (≤30)
- **Primary**: `Fridge: Cook What You Have` — `26/30` OK (26 chars / 26 UTF-8 bytes)
- Fallback 1: `Fridge – Leftover Recipes` — `25/30` OK (25 chars / 27 UTF-8 bytes)
- Fallback 2: `Fridge Cleanout Recipes` — `23/30` OK (23 chars / 23 UTF-8 bytes)

"Fridge" alone is very likely taken on the App Store — try the primary first,
then the fallbacks in order.

## Subtitle (≤30) — `25/30` OK (25 chars / 25 UTF-8 bytes)
```
AI meals from your fridge
```

## Promotional text (≤170) — `163/170` OK (163 chars / 163 UTF-8 bytes)
```
What's for dinner? Type or snap what's in your fridge and get a full home-style menu built on 146 professional recipes, scaled to your table. Buy less, waste less.
```

## Description (≤4000) — `1791/4000` OK (1791 chars / 1845 UTF-8 bytes)
```
Turn what's in your fridge into tonight's dinner.

Fridge helps you cook with what you already have. Tell it your ingredients and how many people are eating, and it plans a complete home-style Taiwanese meal with clear portions and step-by-step instructions.

■ Two ways to add ingredients
• Type them in, e.g. "eggs, tomatoes, cabbage"
• Or snap a photo of your fridge or groceries — AI recognizes the ingredients and you confirm or edit the list

■ Tell us how you eat
• Pick the date, meal (breakfast, lunch or dinner) and number of people
• Choose how many dishes and soups you want
• Save pantry staples and allergies or dislikes in Settings — recommendations avoid them automatically

■ Grounded in real recipes
• 146 built-in home-cooking recipes from professional chefs and cooking publishers
• AI builds your menu on top of these recipes; each dish shows its source, and AI-adapted dishes are labeled as such
• Portions scale automatically to your number of servings

■ Check off as you cook
• Tick off each step so nothing gets missed
• Save favorite dishes with one tap
• Past menus are kept in History

■ Works offline too
• If you're offline or the AI is busy, Fridge plans a menu from its built-in recipes and tells you so

■ Sign-in is optional
• Sign in with your Apple, Google or LINE account
• Or tap "Browse first" to use the app without an account
• Delete your account anytime in Settings

■ AI and your privacy
• Fridge asks for your consent before using AI features
• Ingredient text and photos are used only to generate recipes, never for ads
• See our Privacy Policy for details

AI-generated recipes are for reference only. Please check ingredient freshness, cooking temperatures and your own allergies.

Buy less, waste less, and give every ingredient a good home.
```

## Keywords (≤100) — `96/100` OK (96 chars / 96 UTF-8 bytes)
```
recipe,leftover,cooking,meal plan,dinner,ingredients,food waste,taiwanese,home cooking,lunch box
```
Comma-separated, no spaces after commas, no words from the app name/subtitle
(Apple already indexes those), no competitor or celebrity names.

## What's New (first version) — `126/4000` OK (126 chars / 126 UTF-8 bytes)
```
First release of Fridge: add ingredients by text or photo and get an AI-planned home-style menu built on professional recipes.
```

## Categories
- Primary: Food & Drink
- Secondary: Lifestyle

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

## App Review notes — `1935/4000` OK (1935 chars / 2131 UTF-8 bytes)
```
1. Sign-in is optional. After launch: onboarding (tap 略過 "Skip") → login screen. Tap 「先逛逛，之後再登入」 ("Browse first, sign in later") to use all core features as a guest. Favorites and history are stored on the device only.
2. Text input: Home → 選擇輸入方式 (choose input) → text input, enter e.g. 雞蛋、番茄、高麗菜 → set servings/dishes → 確認食材 (Confirm) → 生成推薦料理 (Generate).
3. Photo recognition: Home → 選擇輸入方式 → photo input → 相簿 (Photos) to pick a picture of food, or 拍照 (Camera) on a device (devices without a camera show Photos only). The app shows 「AI 辨識中…」 and lists detected ingredients, which can be edited.
4. AI data consent: before the first AI use (recipe generation or photo recognition) the app explains that ingredient text, meal settings and photos are sent through our server to OpenAI, and asks the user to agree or decline. If declined, recipe generation uses built-in offline recipes (a notice is shown at the top of the results) and photo recognition does not run. The choice can be changed anytime in 設定 > AI 資料使用 (Settings > AI data use).
5. All AI requests go through our own backend (Supabase Edge Functions); no third-party AI keys are embedded in the app.
6. Account deletion: after signing in with Apple, Google or LINE, go to 設定 > 刪除帳號 (Settings > Delete Account) and confirm with 刪除 (Delete). Sign in with Apple users are first asked by Apple to re-authenticate. The account and its server-side data are permanently removed, on-device favorites, history and settings are cleared, and the app returns to the login screen.
7. The 146 built-in recipes are compiled from publicly available home-cooking recipes by professional chefs and cooking publishers. Built-in recipes show 「參考來源：…」 (reference source); AI-adapted dishes show 「靈感來源：…（AI 改編）」 (inspired by …, AI-adapted). The listed chefs and sites are not affiliated with or endorsing the app (also stated in Settings > About).
8. The app is iPhone-only and portrait-only.
```
Sign-in required for review: **No** (guest mode). No demo account needed.
Items 4, 6 and 7 were checked against the build on 2026-09-26 (consent screen,
設定 > 刪除帳號, 參考來源／靈感來源 labels).
