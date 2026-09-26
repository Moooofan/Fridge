import Foundation

/// 管理敏感資訊（如 API Keys）的讀取
/// 支援從 Secrets.plist 或環境變數讀取
final class SecretsManager {
    static let shared = SecretsManager()

    private var secrets: [String: String] = [:]

    private init() {
        loadFromPlist()
    }

    /// 從 Secrets.plist 載入
    private func loadFromPlist() {
        // 嘗試從 Bundle 中讀取 Secrets.plist
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] else {
            #if DEBUG
            print("⚠️ SecretsManager: 無法讀取 Secrets.plist，將使用環境變數或 Mock 模式")
            #endif
            return
        }
        secrets = plist
    }

    /// 取得指定 key 的值
    /// 優先順序：環境變數 > Secrets.plist
    func getValue(for key: String) -> String? {
        // 優先從環境變數讀取
        if let envValue = ProcessInfo.processInfo.environment[key], !envValue.isEmpty {
            return envValue
        }

        // 其次從 plist 讀取
        if let plistValue = secrets[key], !plistValue.isEmpty, plistValue != "YOUR_OPENAI_API_KEY" {
            return plistValue
        }

        return nil
    }

    /// 取得 OpenAI API Key
    var openAIAPIKey: String? {
        getValue(for: "OPENAI_API_KEY")
    }

    /// 是否有有效的 API Key
    var hasValidAPIKey: Bool {
        openAIAPIKey != nil
    }

    // MARK: - Auth（Supabase / Google / LINE）

    /// 依 key 讀取，若缺少或仍是預留的 "YOUR_..." 佔位字串則回傳 nil。
    private func trimmedValue(for key: String) -> String? {
        guard let value = getValue(for: key)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty,
              !value.hasPrefix("YOUR_") else {
            return nil
        }
        return value
    }

    /// Supabase 專案 URL（例如 https://xxxx.supabase.co）
    var supabaseURL: URL? {
        guard let raw = trimmedValue(for: "SUPABASE_URL") else { return nil }
        return URL(string: raw)
    }

    /// Supabase anon / publishable key
    var supabaseAnonKey: String? {
        trimmedValue(for: "SUPABASE_ANON_KEY")
    }

    /// Google Sign-In 的 iOS OAuth client id
    var googleClientID: String? {
        trimmedValue(for: "GOOGLE_CLIENT_ID")
    }

    /// LINE Login channel id
    var lineChannelID: String? {
        trimmedValue(for: "LINE_CHANNEL_ID")
    }

    /// Supabase 自訂 OIDC provider 的 slug（LINE 走 `custom:<slug>`，見
    /// https://supabase.com/docs/guides/auth/custom-oauth-providers ）。
    /// 沒有在 Secrets.plist／環境變數設定時預設 `"custom:line"`。
    var lineSupabaseProvider: String {
        trimmedValue(for: "LINE_SUPABASE_PROVIDER") ?? "custom:line"
    }
}
