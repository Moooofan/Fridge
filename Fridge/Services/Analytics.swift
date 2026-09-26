import Foundation
import MetricKit
import Supabase
import UIKit

/// PII-free 分析事件。事件名稱／欄位需與 `supabase/functions/track/index.ts` 的
/// `EVENT_PROP_ALLOWLIST` 保持一致——新增或修改事件時兩邊都要改，伺服器端會拒絕
/// 不在允許清單裡的事件名稱，並剔除允許清單以外的欄位。
///
/// 絕不可放進 `props`：食材名稱、食譜文字、email、使用者 id（user id 由伺服器依登入
/// JWT 附加，不由 App 傳送）。
enum AnalyticsEvent {
    enum IngredientSource: String { case text, photo }
    enum RecipeSource: String {
        case ai
        case localFallback = "local_fallback"
        case local
    }

    case onboardingComplete
    case login(method: String)
    case loginSkipGuest
    case ingredientsAdded(count: Int, source: IngredientSource)
    case recipesGenerated(dishes: Int, soups: Int, source: RecipeSource)
    case recipeViewed(fromCurated: Bool)
    case recipeFavorited
    case photoRecognition(success: Bool, count: Int)
    case accountDeleted
    /// 非致命錯誤（`Analytics.record(error:)`），只帶 NSError 的 domain/code，不含訊息文字。
    case appError(domain: String, code: Int)

    var name: String {
        switch self {
        case .onboardingComplete: return "onboarding_complete"
        case .login: return "login"
        case .loginSkipGuest: return "login_skip_guest"
        case .ingredientsAdded: return "ingredients_added"
        case .recipesGenerated: return "recipes_generated"
        case .recipeViewed: return "recipe_viewed"
        case .recipeFavorited: return "recipe_favorited"
        case .photoRecognition: return "photo_recognition"
        case .accountDeleted: return "account_deleted"
        case .appError: return "app_error"
        }
    }

    var props: [String: Any] {
        switch self {
        case .onboardingComplete, .loginSkipGuest, .recipeFavorited, .accountDeleted:
            return [:]
        case .login(let method):
            return ["method": method]
        case .ingredientsAdded(let count, let source):
            return ["count": count, "source": source.rawValue]
        case .recipesGenerated(let dishes, let soups, let source):
            return ["dishes": dishes, "soups": soups, "source": source.rawValue]
        case .recipeViewed(let fromCurated):
            return ["from_curated": fromCurated]
        case .photoRecognition(let success, let count):
            return ["success": success, "count": count]
        case .appError(let domain, let code):
            return ["domain": domain, "code": code]
        }
    }
}

/// Analytics + crash reporting facade。後端不是 Firebase/GA4，而是自家 Supabase
/// Edge Function `track`（`supabase/functions/track/index.ts` 寫入
/// `analytics_events` / `crash_reports`，見 `supabase/migrations/20260926102642_analytics.sql`）。
///
/// 事件先進記憶體佇列並同步寫一份到本機 JSON 檔（`QueueStore`），滿 20 筆、App 進背景
/// （`FridgeApp` 的 `scenePhase`）、或啟動時各觸發一次批次上傳；送出失敗的事件留在佇列裡
/// 下次再試（上限 500 筆，超過就丟最舊的）。沒設定 `SUPABASE_URL`/`SUPABASE_ANON_KEY`，或
/// 使用者關掉 `Analytics.isEnabled`（Settings 的分析開關，預設 true）時整支都是 no-op。
enum Analytics {
    private static let enabledKey = "analyticsEnabled"
    private static let installIDKey = "analyticsInstallID"
    private static let flushBatchSize = 20

    private static let metricKitSubscriber = MetricKitSubscriber()
    private static let flushGate = FlushGate()

    /// 使用者是否開啟分析（Settings 的「分析與診斷」開關；由另一個 agent 的 SettingsView
    /// 綁定這個屬性即可，見任務報告的建議程式碼）。預設 true（尚未設定過視為開啟）。
    static var isEnabled: Bool {
        get {
            let defaults = UserDefaults.standard
            if defaults.object(forKey: enabledKey) == nil { return true }
            return defaults.bool(forKey: enabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    /// 與 `EdgeAIClient.isConfigured` 判斷條件相同：有 `SUPABASE_URL` + `SUPABASE_ANON_KEY`。
    static var isConfigured: Bool {
        SecretsManager.shared.supabaseURL != nil && SecretsManager.shared.supabaseAnonKey != nil
    }

    /// 每次 App 啟動呼叫一次（`FridgeApp.init()`）：註冊 MetricKit 訂閱者、補送上次留在
    /// 佇列裡沒送出的事件。
    static func configure() {
        MXMetricManager.shared.add(metricKitSubscriber)
        guard isEnabled, isConfigured else { return }
        Task.detached { await flush() }
    }

    /// 記錄一個分析事件；未開啟或未設定 Supabase 時直接忽略。
    static func log(_ event: AnalyticsEvent) {
        guard isEnabled, isConfigured else { return }
        let entry: [String: Any] = [
            "event": event.name,
            "props": event.props,
            "ts": ISO8601DateFormatter().string(from: Date())
        ]
        guard JSONSerialization.isValidJSONObject(entry) else { return }

        let queueDepth = QueueStore.shared.append(entry)
        #if DEBUG
        print("📊 Analytics: \(event.name) \(event.props)")
        #endif
        if queueDepth >= flushBatchSize {
            Task.detached { await flush() }
        }
    }

    /// 記錄一個非致命錯誤（只送 NSError 的 domain/code，不含可能含 PII 的錯誤訊息文字）。
    static func record(error: Error) {
        let nsError = error as NSError
        log(.appError(domain: nsError.domain, code: nsError.code))
    }

    /// 觸發一次佇列批次上傳（每批最多 `flushBatchSize` 筆，一路送到佇列清空或某批失敗為止）。
    /// App 進背景時（`FridgeApp` 的 `scenePhase` 變化）與啟動時都會呼叫這個。
    static func flush() async {
        guard isEnabled, isConfigured else { return }
        guard await flushGate.begin() else { return }
        while true {
            let batch = QueueStore.shared.peekBatch(flushBatchSize)
            if batch.isEmpty { break }
            guard await postEvents(batch) else { break }
            QueueStore.shared.removeFirst(batch.count)
        }
        await flushGate.end()
    }

    // MARK: - Network

    private static func postEvents(_ events: [[String: Any]]) async -> Bool {
        var body: [String: Any] = [
            "install_id": installID,
            "events": events
        ]
        if let appVersion { body["app_version"] = appVersion }
        if let osVersion { body["os_version"] = osVersion }
        if let deviceModel { body["device_model"] = deviceModel }
        return await postTrack(body)
    }

    /// 由 `MetricKitSubscriber` 呼叫：把一次 crash/diagnostic payload 送去 `crash_reports`。
    fileprivate static func sendCrashPayload(_ data: Data) {
        guard isEnabled, isConfigured else { return }
        Task.detached {
            let payload = Self.cappedCrashPayload(data)
            var body: [String: Any] = [
                "kind": "crash",
                "install_id": installID,
                "payload": payload
            ]
            if let appVersion { body["app_version"] = appVersion }
            if let osVersion { body["os_version"] = osVersion }
            _ = await postTrack(body)
        }
    }

    private static let maxCrashPayloadBytes = 64 * 1024

    /// `payload` 欄位在 DB 端有 64 KB 的 `pg_column_size` 限制；MetricKit 的
    /// diagnostic payload 偶爾會超過，超過就整包換成截斷後的文字摘要，而不是硬塞一個
    /// 可能無效的巨大 JSON。
    private static func cappedCrashPayload(_ data: Data) -> [String: Any] {
        if data.count <= maxCrashPayloadBytes,
           let object = try? JSONSerialization.jsonObject(with: data),
           JSONSerialization.isValidJSONObject(object as? [String: Any] ?? ["value": object]) {
            return (object as? [String: Any]) ?? ["value": object]
        }
        let excerptByteCount = max(maxCrashPayloadBytes - 256, 0)
        let excerpt = String(decoding: data.prefix(excerptByteCount), as: UTF8.self)
        return ["truncated": true, "excerpt": excerpt]
    }

    private static func postTrack(_ body: [String: Any]) async -> Bool {
        guard let baseURL = SecretsManager.shared.supabaseURL,
              let anonKey = SecretsManager.shared.supabaseAnonKey,
              JSONSerialization.isValidJSONObject(body),
              let requestData = try? JSONSerialization.data(withJSONObject: body) else {
            return false
        }

        let url = baseURL.appendingPathComponent("functions/v1/track")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.addValue(anonKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(await bearerToken(baseURL: baseURL, anonKey: anonKey))", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestData

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return (200..<300).contains(httpResponse.statusCode)
        } catch {
            return false
        }
    }

    /// 已登入時帶使用者的 access token（讓伺服器附加 user_id），訪客退回 anon/publishable
    /// key——與 `EdgeAIClient.bearerToken` 同一套做法，見該檔案註解。這裡另開一個
    /// `SupabaseClient` 讀 Keychain 裡同一份 session，不需要共用 `SupabaseAuthService`
    /// 的內部實例。
    private static func bearerToken(baseURL: URL, anonKey: String) async -> String {
        let client = SupabaseClient(supabaseURL: baseURL, supabaseKey: anonKey)
        if let token = try? await client.auth.session.accessToken {
            return token
        }
        return anonKey
    }

    // MARK: - Install ID / device info

    private static var installID: String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: installIDKey) { return existing }
        let generated = UUID().uuidString.lowercased()
        defaults.set(generated, forKey: installIDKey)
        return generated
    }

    private static var appVersion: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    private static var osVersion: String? {
        "iOS \(UIDevice.current.systemVersion)"
    }

    private static var deviceModel: String? {
        var systemInfo = utsname()
        uname(&systemInfo)
        let identifier = withUnsafePointer(to: &systemInfo.machine) { pointer -> String in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        return identifier.isEmpty ? nil : identifier
    }
}

/// 序列化一次只能有一個 `flush()` 在跑，避免（例如批次上傳中途又滿 20 筆）同時觸發兩個
/// 迴圈重複送同一批事件。
private actor FlushGate {
    private var isFlushing = false

    func begin() -> Bool {
        guard !isFlushing else { return false }
        isFlushing = true
        return true
    }

    func end() {
        isFlushing = false
    }
}

/// 記憶體佇列 + 落地 JSON 檔（`Caches/fridge_analytics_queue.json`），讓 App 被系統砍掉時
/// 還沒送出的事件下次啟動能補送。所有存取都在專用序列 queue 上執行，避免多執行緒同時
/// append／flush 弄壞陣列或檔案。
private final class QueueStore {
    static let shared = QueueStore()

    private static let maxQueueSize = 500

    private let ioQueue = DispatchQueue(label: "com.moooofan.fridge.analytics.queue")
    private var events: [[String: Any]]
    private let fileURL: URL

    private init() {
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        fileURL = (cachesDir ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("fridge_analytics_queue.json")
        if let data = try? Data(contentsOf: fileURL),
           let loaded = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            events = loaded
        } else {
            events = []
        }
    }

    /// 加入一筆事件，回傳目前佇列長度。
    func append(_ event: [String: Any]) -> Int {
        ioQueue.sync {
            events.append(event)
            if events.count > Self.maxQueueSize {
                events.removeFirst(events.count - Self.maxQueueSize)
            }
            persist()
            return events.count
        }
    }

    func peekBatch(_ limit: Int) -> [[String: Any]] {
        ioQueue.sync { Array(events.prefix(limit)) }
    }

    func removeFirst(_ count: Int) {
        ioQueue.sync {
            events.removeFirst(min(count, events.count))
            persist()
        }
    }

    private func persist() {
        guard JSONSerialization.isValidJSONObject(events),
              let data = try? JSONSerialization.data(withJSONObject: events) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

/// MetricKit 的訂閱者需要是 class（`MXMetricManagerSubscriber` 是 class-bound protocol），
/// 所以拆出這個私有型別，讓 `Analytics` 本身維持 enum facade。`MXMetricManager` 只會弱參照
/// 訂閱者，實際的存活靠 `Analytics.metricKitSubscriber` 這個 static let 保留一份強參照。
private final class MetricKitSubscriber: NSObject, MXMetricManagerSubscriber {
    /// 效能指標（電量、記憶體等）目前不需要，只要診斷／當機報告。
    func didReceive(_ payloads: [MXMetricPayload]) {}

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            Analytics.sendCrashPayload(payload.jsonRepresentation())
        }
    }
}
