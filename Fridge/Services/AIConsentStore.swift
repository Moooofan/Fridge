import Foundation

/// 使用者是否同意把資料（食材文字、用餐條件、要辨識的照片）送到第三方 AI（OpenAI）。
/// App Store Guideline 5.1.2(i)：送出前必須清楚揭露並取得明確同意。
///
/// 存在 UserDefaults：`aiConsentGranted`（Bool）、`aiConsentDate`（Date）、
/// `aiConsentVersion`（String）。揭露內容有實質變更時調高 `currentVersion`，
/// 舊版本的同意即視為失效，會再問一次。
enum AIConsentStore {
    static let currentVersion = "2026-09"

    private static let grantedKey = "aiConsentGranted"
    private static let dateKey = "aiConsentDate"
    private static let versionKey = "aiConsentVersion"

    private static var defaults: UserDefaults { .standard }

    /// 已同意「目前版本」的揭露內容。
    static var isGranted: Bool {
        defaults.bool(forKey: grantedKey) && defaults.string(forKey: versionKey) == currentVersion
    }

    /// 使用者曾經針對目前版本做過選擇（同意或不同意），用來避免每次都跳出詢問。
    static var hasAnswered: Bool {
        defaults.string(forKey: versionKey) == currentVersion
    }

    static var decisionDate: Date? {
        defaults.object(forKey: dateKey) as? Date
    }

    static func grant() {
        record(granted: true)
    }

    static func decline() {
        record(granted: false)
    }

    /// 清除紀錄（刪除帳號時使用），下次使用 AI 功能會重新詢問。
    static func reset() {
        defaults.removeObject(forKey: grantedKey)
        defaults.removeObject(forKey: dateKey)
        defaults.removeObject(forKey: versionKey)
    }

    private static func record(granted: Bool) {
        defaults.set(granted, forKey: grantedKey)
        defaults.set(Date(), forKey: dateKey)
        defaults.set(currentVersion, forKey: versionKey)
    }
}
