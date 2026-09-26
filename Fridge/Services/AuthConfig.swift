import Foundation

/// 集中判斷目前有哪些登入後端／SDK 已經完成設定。
///
/// 整個登入功能被設計成：任何一組 key 沒設定，對應的登入方式就不能用（或改走純本機模式），
/// 但 App 本身永遠可以編譯、執行，訪客模式與 Apple 本機登入不需要任何 key。
enum AuthConfig {
    /// Supabase 是否已設定（URL + anon key 都存在）。
    static var isSupabaseConfigured: Bool {
        SecretsManager.shared.supabaseURL != nil && SecretsManager.shared.supabaseAnonKey != nil
    }

    static var isGoogleConfigured: Bool {
        SecretsManager.shared.googleClientID != nil
    }

    static var isLineConfigured: Bool {
        SecretsManager.shared.lineChannelID != nil
    }
}
