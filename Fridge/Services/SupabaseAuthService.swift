import AuthenticationServices
import CryptoKit
import Foundation
import GoogleSignIn
import LineSDK
import Supabase
import UIKit

/// 有設定 Supabase（`AuthConfig.isSupabaseConfigured`）時使用的登入服務。
///
/// - Apple／Google：走 supabase-swift 內建的 `auth.signInWithIdToken`
///   （`OpenIDConnectCredentials(provider: .apple/.google, idToken:...)`）。
/// - LINE：**驗證過** supabase-swift 2.55.2 這個版本裡，`OpenIDConnectCredentials.Provider`
///   仍是封閉的 enum `{google, apple, azure, facebook}`，`signInWithOAuth`／
///   `getOAuthSignInURL` 用的頂層 `Provider` enum 也是封閉的 String enum（GitHub tag
///   v2.55.2, `Sources/Auth/Types.swift:416-442`；沒有 LINE 或任何自訂字串的逃生門 ——
///   `Provider(rawValue:)` 對不存在的 case 會回傳 `nil`，不能塞 `"custom:line"`）。
///   所以 LINE 走 Supabase 的「Custom OAuth/OIDC provider」機制，網址上用
///   `provider=custom:<slug>`（預設 `custom:line`，見
///   https://supabase.com/docs/guides/auth/custom-oauth-providers ，可用
///   Secrets.plist 的 `LINE_SUPABASE_PROVIDER` 覆寫），開一次
///   `ASWebAuthenticationSession` 網頁登入。
///
///   **PKCE 是手動做的，不能借用 SDK 的 `session(from:)`**：`session(from:)` 在
///   PKCE flow 下呼叫的 `handlePKCEFlow`（`AuthClient.swift:1030`）會去讀
///   `codeVerifierStorage`（`AuthClient.swift:738,1574`），但這個 storage 只有
///   SDK 自己的 `signInWithOAuth`/`getOAuthSignInURL` 內部呼叫的私有
///   `prepareForPKCE()`（`AuthClient.swift:1566`）才會寫入，這裡完全沒機會呼叫到
///   它們（因為 `custom:line` 不是型別化 `Provider`），所以 `codeVerifierStorage`
///   永遠是空的，`session(from:)` 一定會失敗。改成自己產生 code_verifier／
///   code_challenge、自己組 authorize URL、自己解析回呼網址的 `code`、自己 POST
///   `{SUPABASE_URL}/auth/v1/token?grant_type=pkce` 換 token（body 欄位
///   `auth_code`／`code_verifier`，**驗證過**與 SDK 內部
///   `exchangeCodeForSession(authCode:)` 送出的完全一樣，`AuthClient.swift:748-758`），
///   最後用 supabase-swift **驗證存在**的 `auth.setSession(accessToken:refreshToken:)`
///   （`AuthClient.swift:1059`）把拿到的 token 交回 SDK 管理。
final class SupabaseAuthService: NSObject, AuthService {
    private let client: SupabaseClient
    private let sessionStore = UserSessionStore.shared

    /// 保留住目前執行中的 web auth session，避免它在 flow 跑到一半時被釋放掉。
    private var webAuthSession: ASWebAuthenticationSession?

    /// LINE web OAuth 流程用的回呼 URL scheme（見 project.yml 的 CFBundleURLTypes）。
    private static let lineCallbackURL = URL(string: "fridge://auth-callback")!

    override init() {
        guard let url = SecretsManager.shared.supabaseURL,
              let key = SecretsManager.shared.supabaseAnonKey else {
            // AuthServiceFactory 只有在 AuthConfig.isSupabaseConfigured 時才會建立這個類別，
            // 所以照設計不會走到這裡；保留 fatalError 讓設定錯誤在開發期就能立刻被發現。
            fatalError("SupabaseAuthService 在 Supabase 尚未設定時被建立 — 請透過 AuthServiceFactory 建立")
        }
        client = SupabaseClient(supabaseURL: url, supabaseKey: key)
        super.init()
    }

    var currentUser: UserProfile? {
        sessionStore.currentUser
    }

    @discardableResult
    func restoreSession() async -> UserProfile? {
        do {
            let session = try await client.auth.session
            let profile = Self.profile(from: session.user)
            sessionStore.currentUser = profile
            return profile
        } catch {
            // 沒有 session（AuthError.sessionMissing）或 refresh 失敗都視為「未登入」。
            sessionStore.clear()
            return nil
        }
    }

    // MARK: - Apple

    func signInWithApple(authorization: ASAuthorization, rawNonce: String) async throws -> UserProfile {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthError.missingIdentityToken
        }
        guard let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw AuthError.missingIdentityToken
        }

        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: idToken,
                    nonce: rawNonce
                )
            )

            var profile = Self.profile(from: session.user)
            // Apple 只有第一次授權才會給姓名；Supabase user_metadata 若還沒補上就用 credential 的。
            if profile.displayName == nil,
               let name = Self.formattedName(credential.fullName) {
                profile.displayName = name
            }
            sessionStore.currentUser = profile
            return profile
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.unknown(error)
        }
    }

    // MARK: - Google

    @MainActor
    func signInWithGoogle(presenting: UIViewController) async throws -> UserProfile {
        guard let clientID = SecretsManager.shared.googleClientID else {
            throw AuthError.notConfigured("尚未設定 Google 登入，請先完成後台設定")
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        do {
            let result: GIDSignInResult = try await withCheckedThrowingContinuation { continuation in
                GIDSignIn.sharedInstance.signIn(withPresenting: presenting) { result, error in
                    if let error {
                        let nsError = error as NSError
                        // kGIDSignInErrorCodeCanceled == -5（GoogleSignIn-iOS, kGIDSignInErrorDomain）。
                        if nsError.domain == kGIDSignInErrorDomain, nsError.code == -5 {
                            continuation.resume(throwing: AuthError.cancelled)
                        } else {
                            continuation.resume(throwing: AuthError.unknown(error))
                        }
                        return
                    }
                    guard let result else {
                        continuation.resume(throwing: AuthError.unknown(
                            NSError(domain: "SupabaseAuthService", code: -1)
                        ))
                        return
                    }
                    continuation.resume(returning: result)
                }
            }

            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.missingIdentityToken
            }
            let session = try await client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .google,
                    idToken: idToken,
                    accessToken: result.user.accessToken.tokenString
                )
            )
            let profile = Self.profile(from: session.user)
            sessionStore.currentUser = profile
            return profile
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.unknown(error)
        }
    }

    // MARK: - LINE（Supabase custom OAuth provider + 手動 PKCE — 見上方類別註解）

    @MainActor
    func signInWithLine() async throws -> UserProfile {
        guard let supabaseURL = SecretsManager.shared.supabaseURL,
              let anonKey = SecretsManager.shared.supabaseAnonKey else {
            throw AuthError.notConfigured("尚未設定 LINE 登入，請先完成後台設定")
        }

        // 自己做 PKCE：SDK 的 codeVerifierStorage 只有它自己的
        // signInWithOAuth/getOAuthSignInURL 會寫入，這裡用不到（見上方類別註解）。
        let codeVerifier = Self.generatePKCECodeVerifier()
        let codeChallenge = Self.pkceCodeChallenge(for: codeVerifier)

        var components = URLComponents(
            url: supabaseURL.appendingPathComponent("auth/v1/authorize"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "provider", value: SecretsManager.shared.lineSupabaseProvider),
            URLQueryItem(name: "redirect_to", value: Self.lineCallbackURL.absoluteString),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            // 小寫 "s256"：驗證過 supabase-swift 2.55.2 自己送出的值就是小寫
            // （`AuthClient.swift:1576` prepareForPKCE() 裡 `codeChallengeMethod = "s256"`），
            // 照官方 SDK 實際會打到 GoTrue 的值走，不用 RFC 7636 慣例的大寫 "S256"。
            URLQueryItem(name: "code_challenge_method", value: "s256"),
        ]
        guard let authorizeURL = components?.url else {
            throw AuthError.unknown(NSError(domain: "SupabaseAuthService", code: -2))
        }

        do {
            let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
                let authSession = ASWebAuthenticationSession(
                    url: authorizeURL,
                    callbackURLScheme: Self.lineCallbackURL.scheme
                ) { [weak self] url, error in
                    self?.webAuthSession = nil
                    if let url {
                        continuation.resume(returning: url)
                    } else if let error {
                        let nsError = error as NSError
                        if nsError.domain == ASWebAuthenticationSessionErrorDomain,
                           nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                            continuation.resume(throwing: AuthError.cancelled)
                        } else {
                            continuation.resume(throwing: AuthError.unknown(error))
                        }
                    } else {
                        continuation.resume(throwing: AuthError.unknown(
                            NSError(domain: "SupabaseAuthService", code: -3)
                        ))
                    }
                }
                authSession.presentationContextProvider = self
                authSession.prefersEphemeralWebBrowserSession = true
                webAuthSession = authSession
                authSession.start()
            }

            let code = try Self.authorizationCode(fromCallback: callbackURL)
            let tokens = try await Self.exchangeCodeForTokens(
                code: code,
                codeVerifier: codeVerifier,
                supabaseURL: supabaseURL,
                anonKey: anonKey
            )
            let session = try await client.auth.setSession(
                accessToken: tokens.accessToken,
                refreshToken: tokens.refreshToken
            )
            let profile = Self.profile(from: session.user, providerOverride: .line)
            sessionStore.currentUser = profile
            return profile
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.unknown(error)
        }
    }

    /// 從 `ASWebAuthenticationSession` 回呼網址解析 PKCE 的 `code`；
    /// 若 GoTrue 回傳 `error`/`error_description` 則轉成 `AuthError` 丟出。
    /// 絕不印出 code 本身。
    private static func authorizationCode(fromCallback url: URL) throws -> String {
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if let description = queryItems.first(where: { $0.name == "error_description" })?.value
            ?? queryItems.first(where: { $0.name == "error" })?.value {
            throw AuthError.notConfigured(description)
        }
        guard let code = queryItems.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw AuthError.unknown(NSError(domain: "SupabaseAuthService", code: -4))
        }
        return code
    }

    /// GoTrue PKCE token 交換：`POST {SUPABASE_URL}/auth/v1/token?grant_type=pkce`，
    /// body `{"auth_code": code, "code_verifier": verifier}` —— **驗證過**與
    /// supabase-swift 2.55.2 `AuthClient.exchangeCodeForSession(authCode:)`
    /// 內部送出的 request 完全一樣（`AuthClient.swift:744-758`）；這裡等於是自己
    /// 重做那個方法，因為它讀的 `codeVerifierStorage` 我們用不到。
    /// 絕不印出 code、verifier 或回傳的 token。
    private static func exchangeCodeForTokens(
        code: String,
        codeVerifier: String,
        supabaseURL: URL,
        anonKey: String
    ) async throws -> (accessToken: String, refreshToken: String) {
        var urlComponents = URLComponents(
            url: supabaseURL.appendingPathComponent("auth/v1/token"),
            resolvingAgainstBaseURL: false
        )
        urlComponents?.queryItems = [URLQueryItem(name: "grant_type", value: "pkce")]
        guard let tokenURL = urlComponents?.url else {
            throw AuthError.unknown(NSError(domain: "SupabaseAuthService", code: -5))
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode([
            "auth_code": code,
            "code_verifier": codeVerifier,
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.unknown(NSError(domain: "SupabaseAuthService", code: -6))
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            struct GoTrueErrorBody: Decodable {
                let errorDescription: String?
                let msg: String?
                let error: String?

                enum CodingKeys: String, CodingKey {
                    case errorDescription = "error_description"
                    case msg
                    case error
                }
            }
            let body = try? JSONDecoder().decode(GoTrueErrorBody.self, from: data)
            let message = body?.errorDescription ?? body?.msg ?? body?.error
                ?? "LINE 登入失敗（HTTP \(httpResponse.statusCode)）"
            throw AuthError.notConfigured(message)
        }

        struct PKCETokenResponse: Decodable {
            let accessToken: String
            let refreshToken: String

            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"
                case refreshToken = "refresh_token"
            }
        }
        let decoded = try JSONDecoder().decode(PKCETokenResponse.self, from: data)
        return (decoded.accessToken, decoded.refreshToken)
    }

    /// RFC 7636 code_verifier：43–128 字元、unreserved charset。用
    /// `SecRandomCopyBytes` 產生 32 bytes 再 base64url（無 padding）編碼，
    /// 長度落在 43 字元，符合規範且與 supabase-swift 自己的實作
    /// （`Internal/PKCE.swift`）同一套演算法。
    private static func generatePKCECodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed with OSStatus \(status)")
        return Self.base64URLEncode(Data(bytes))
    }

    /// code_challenge = base64url(SHA256(code_verifier))，no padding。
    private static func pkceCodeChallenge(for verifier: String) -> String {
        let hashed = SHA256.hash(data: Data(verifier.utf8))
        return Self.base64URLEncode(Data(hashed))
    }

    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Sign out

    func signOut() async {
        try? await client.auth.signOut()
        if AuthConfig.isGoogleConfigured {
            GIDSignIn.sharedInstance.signOut()
        }
        if AuthConfig.isLineConfigured {
            LoginManager.shared.logout { _ in }
        }
        sessionStore.clear()
    }

    // MARK: - Delete account

    /// 呼叫 Edge Function `delete-account`（`supabase/functions/delete-account/`）
    /// 刪除雲端帳號。Apple 使用者先重新跑一次 Sign in with Apple 取得新的
    /// `authorizationCode`（一次性、5 分鐘有效），交給伺服器換 refresh token 後撤銷。
    /// 成功後登出並清除本機資料。絕不印出 token／code。
    @MainActor
    func deleteAccount() async throws {
        guard let supabaseURL = SecretsManager.shared.supabaseURL,
              let anonKey = SecretsManager.shared.supabaseAnonKey else {
            throw AuthError.notConfigured("尚未設定雲端帳號服務")
        }

        let session: Supabase.Session
        do {
            session = try await client.auth.session
        } catch {
            throw AuthError.deletionFailed("登入狀態已失效，請重新登入後再試")
        }

        var body: [String: String] = [:]
        let provider = sessionStore.currentUser?.provider
            ?? AuthProvider(rawValue: session.user.appMetadata["provider"]?.stringValue ?? "")
        if provider == .apple {
            // 使用者取消重新授權 → 丟 .cancelled，整個刪除流程中止（什麼都不刪）。
            body["apple_authorization_code"] = try await AppleReauthorizer.requestAuthorizationCode()
        }

        var request = URLRequest(url: supabaseURL.appendingPathComponent("functions/v1/delete-account"))
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AuthError.deletionFailed(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            struct ErrorBody: Decodable {
                struct Inner: Decodable { let message: String? }
                let error: Inner?
                let message: String?
            }
            let decoded = try? JSONDecoder().decode(ErrorBody.self, from: data)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw AuthError.deletionFailed(decoded?.error?.message ?? decoded?.message ?? "HTTP \(status)")
        }

        #if DEBUG
        struct DeleteResult: Decodable { let deleted: Bool; let appleRevoked: Bool?; let reason: String? }
        if let result = try? JSONDecoder().decode(DeleteResult.self, from: data) {
            print("🗑️ delete-account: deleted=\(result.deleted) appleRevoked=\(result.appleRevoked ?? false) reason=\(result.reason ?? "-")")
        }
        #endif

        // 使用者已經在伺服器端刪除，signOut 的 API 呼叫可能失敗 —— signOut() 內部用 try?，
        // 仍會清掉本機 Keychain session 與 Google／LINE SDK 狀態。
        await signOut()
        LocalUserData.clearAll()
    }

    // MARK: - Helpers

    private static func profile(from user: Supabase.User, providerOverride: AuthProvider? = nil) -> UserProfile {
        let metadata = user.userMetadata
        let name = metadata["full_name"]?.stringValue ?? metadata["name"]?.stringValue
        let avatar = metadata["avatar_url"]?.stringValue ?? metadata["picture"]?.stringValue
        let providerRaw = user.appMetadata["provider"]?.stringValue
        let provider = providerOverride ?? AuthProvider(rawValue: providerRaw ?? "") ?? .guest
        return UserProfile(
            id: user.id.uuidString,
            provider: provider,
            displayName: name,
            email: user.email,
            avatarURL: avatar
        )
    }

    private static func formattedName(_ components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let formatter = PersonNameComponentsFormatter()
        let name = formatter.string(from: components)
        return name.isEmpty ? nil : name
    }
}

extension SupabaseAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        AppleSignInCoordinator.keyWindow() ?? ASPresentationAnchor()
    }
}
