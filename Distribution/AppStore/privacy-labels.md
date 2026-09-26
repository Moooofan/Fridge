# App Store Connect — App Privacy

Exact answers for the "App Privacy" questionnaire (App Store Connect → App
Privacy → Get Started / Edit). Checklist form: tick each box as you enter it.
No Firebase / Google Analytics anywhere in this app — analytics and crash
reporting are both self-hosted on Supabase (project `fridge`,
ref `sqninmyidhgfjyvulayr`).

Top-level question: **"Does this app collect data from this app?"** → Yes.

These answers mirror `Fridge/PrivacyInfo.xcprivacy` (NSPrivacyCollectedDataTypes):
Name, EmailAddress, UserID (linked, App Functionality); PhotosorVideos,
OtherUserContent (not linked, App Functionality); ProductInteraction (linked,
Analytics); CrashData, PerformanceData (linked, App Functionality).
Tracking: none.

---

## 1. Contact Info — Name, Email Address

- [ ] Collected: Yes
- **Source**: Apple / Google / LINE sign-in (`Fridge/Views/Auth/LoginView.swift`,
  `SupabaseAuthService`). Stored in Supabase `auth.users`.
- **Linked to the user's identity?** Yes.
- **Used for tracking?** No.
- **Purpose(s)**: App Functionality (account creation, sign-in, showing the
  signed-in identity in Settings, account deletion). Favorites/history stay
  on the device; there is no cross-device sync.
- Justification: needed to create and restore the user's account; never sold
  or used for advertising.

## 2. User ID

- [ ] Collected: Yes
- **Source**: Supabase `auth.users.id`, used as the foreign key on
  `analytics_events.user_id` / `crash_reports.user_id` and as the
  `user:<id>` rate-limit key.
- **Linked to the user's identity?** Yes.
- **Used for tracking?** No.
- **Purpose(s)**: App Functionality.
- Justification: needed to identify "this signed-in user's" data across
  requests; never shared with third parties or used to track the user across
  other companies' apps/sites.

## 3. User Content — Photos, Other User Content (ingredient text)

- [ ] Collected: Yes
- **Source**: fridge/ingredient photos (`VisionIngredientService`) and
  free-text ingredient input, sent to the `openai-chat` / `openai-vision`
  Supabase Edge Functions, which forward them to OpenAI (`gpt-5.6-luna`) to
  generate recipes or recognize ingredients. Not stored server-side beyond
  the request (no photo/ingredient-text table in `supabase/migrations/`).
- **Linked to the user's identity?** No — the Edge Function does not persist
  the content, and rate-limiting stores only `user:<id>`/`ip:<ip>` plus a
  timestamp in the `rate_limits` ledger, never the content itself.
- **Used for tracking?** No.
- **Purpose(s)**: App Functionality (this is the app's core feature — turning
  ingredients into recipes).
- Justification: content leaves the device only to generate the recipe/ID
  result the user asked for; OpenAI is a data processor for this single
  request, not a data controller of retained user content.

## 4. Product Interaction (Analytics)

- [ ] Collected: Yes
- **Source**: `Fridge/Services/Analytics.swift` → Supabase Edge Function
  `track` (`supabase/functions/track/index.ts`) → `public.analytics_events`.
  Events: `onboarding_complete`, `login`, `login_skip_guest`,
  `ingredients_added`, `recipes_generated`, `recipe_viewed`,
  `recipe_favorited`, `photo_recognition`, `account_deleted`, `app_error`.
  Every event carries only counts/booleans/fixed enum strings — never
  ingredient names, recipe text, or free text of any kind.
- **Linked to the user's identity?** Yes — when signed in, the Edge Function
  attaches `user_id` from the caller's Supabase session JWT to every event
  (`ctx.userClaims.id` in `track/index.ts`); guests are identified only by a
  random per-install UUID generated on-device (no IDFV/IDFA collected).
- **Used for tracking?** No — data is never linked with data from other
  companies' apps/websites, never used for advertising, and there is no
  cross-app device identifier (`NSPrivacyTracking` stays `false` in
  `Fridge/PrivacyInfo.xcprivacy`).
- **Purpose(s)**: Analytics (understanding feature usage/funnel — see
  `supabase/sql/analytics_dashboard.sql`).
- Justification: first-party product analytics on infrastructure we run;
  never shared with or sold to a third-party analytics/ad network — there is
  no Firebase/GA4/ad SDK in the app.
- User control: `Analytics.isEnabled` (UserDefaults `analyticsEnabled`,
  default on) — Settings toggle "分析與診斷" lets the user opt out; disabling
  it makes `Analytics.log`/`flush` a no-op immediately (queued events are not
  sent while off).

## 5. Crash Data & Performance Data

- [ ] Collected: Yes
- **Source**: `MXMetricManager` (Apple's on-device MetricKit) →
  `Fridge/Services/Analytics.swift` → same `track` function, `kind: "crash"`
  → `public.crash_reports`. Payload is Apple's own
  `MXDiagnosticPayload.jsonRepresentation()` (crash/hang diagnostics),
  truncated to 64 KB.
- **Linked to the user's identity?** Yes — same `user_id` attachment as
  Product Interaction above, for the same reason (signed-in caller's JWT is
  visible to the server).
- **Used for tracking?** No.
- **Purpose(s)**: App Functionality (fixing crashes/hangs;
  `supabase/sql/analytics_dashboard.sql` query 5 counts crashes per
  `app_version`).
- Justification: standard crash/diagnostic collection to keep the app
  working; MetricKit data never leaves the device except to our own backend.

## Not collected

- **Precise/Coarse Location** — not requested, not collected.
- **Identifiers — Device ID (IDFV/IDFA)** — deliberately not collected. We
  generate our own random installation UUID (`Analytics` `installID`,
  UserDefaults-only, not derived from any Apple device identifier) instead of
  reading `identifierForVendor`, specifically so this app never needs the
  Advertising/AdSupport framework or an ATT prompt.
- **Financial Info, Health & Fitness, Browsing History, Search History,
  Purchases** — not collected.

## Tracking question ("Do you use data to track users...")

- **Answer: No.** No data collected by this app is linked with third-party
  data for advertising, shared with data brokers, or used across other
  developers' apps/websites. `NSPrivacyTracking` is `false` in
  `Fridge/PrivacyInfo.xcprivacy` and there is no AdSupport/IDFA usage
  anywhere in the app.
