import AuthenticationServices
import GoogleSignIn
import LineSDK
import UIKit

/// 沒有設定 Supabase 時使用的本機登入服務。
///
/// - Apple：完全走本機（`ASAuthorizationController` → 把 `userIdentifier`／姓名／
///   email 存在本機），不需要任何後端，App Store 5.1.1 也允許這樣的「本機帳號」。
/// - Google／LINE：需要對應的 SDK client id／channel id 才能運作（會實際呼叫
///   GIDSignIn／LineSDK 取得真實身分），沒設定就丟 `.notConfigured`。
/// - 訪客：一律可用，不需要任何設定。
final class LocalAuthService: AuthService {
    private let sessionStore = UserSessionStore.shared

    var currentUser: UserProfile? {
        sessionStore.currentUser
    }

    @discardableResult
    func restoreSession() async -> UserProfile? {
        sessionStore.currentUser
    }

    // MARK: - Apple（本機）

    func signInWithApple(authorization: ASAuthorization, rawNonce: String) async throws -> UserProfile {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthError.missingIdentityToken
        }

        // Apple 只有在使用者「第一次」對這個 App 授權時才會回傳姓名／email，
        // 之後重新登入 credential.fullName / email 會是 nil —— 這時沿用上次存的值。
        let previous = sessionStore.currentUser
        let displayName = Self.formattedName(credential.fullName) ?? previous?.displayName
        let email = credential.email ?? previous?.email

        let profile = UserProfile(
            id: credential.user,
            provider: .apple,
            displayName: displayName,
            email: email
        )
        sessionStore.currentUser = profile
        return profile
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
                        // kGIDSignInErrorCodeCanceled == -5 (GoogleSignIn-iOS, kGIDSignInErrorDomain).
                        if nsError.domain == kGIDSignInErrorDomain, nsError.code == -5 {
                            continuation.resume(throwing: AuthError.cancelled)
                        } else {
                            continuation.resume(throwing: AuthError.unknown(error))
                        }
                        return
                    }
                    guard let result else {
                        continuation.resume(throwing: AuthError.unknown(
                            NSError(domain: "LocalAuthService", code: -1)
                        ))
                        return
                    }
                    continuation.resume(returning: result)
                }
            }

            let user = result.user
            let profile = UserProfile(
                id: user.userID ?? UUID().uuidString,
                provider: .google,
                displayName: user.profile?.name,
                email: user.profile?.email,
                avatarURL: user.profile?.imageURL(withDimension: 200)?.absoluteString
            )
            sessionStore.currentUser = profile
            return profile
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.unknown(error)
        }
    }

    // MARK: - LINE

    func signInWithLine() async throws -> UserProfile {
        guard AuthConfig.isLineConfigured else {
            throw AuthError.notConfigured("尚未設定 LINE 登入，請先完成後台設定")
        }

        do {
            let result: LoginResult = try await withCheckedThrowingContinuation { continuation in
                Task { @MainActor in
                    LoginManager.shared.login(permissions: [.profile, .openID], in: nil) { result in
                        switch result {
                        case .success(let loginResult):
                            continuation.resume(returning: loginResult)
                        case .failure(let error):
                            if error.isUserCancelled {
                                continuation.resume(throwing: AuthError.cancelled)
                            } else {
                                continuation.resume(throwing: AuthError.unknown(error))
                            }
                        }
                    }
                }
            }

            guard let lineProfile = result.userProfile else {
                throw AuthError.missingIdentityToken
            }
            let profile = UserProfile(
                id: lineProfile.userID,
                provider: .line,
                displayName: lineProfile.displayName,
                avatarURL: lineProfile.pictureURL?.absoluteString
            )
            sessionStore.currentUser = profile
            return profile
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.unknown(error)
        }
    }

    // MARK: - Sign out

    func signOut() async {
        if AuthConfig.isGoogleConfigured {
            GIDSignIn.sharedInstance.signOut()
        }
        if AuthConfig.isLineConfigured {
            LoginManager.shared.logout { _ in }
        }
        sessionStore.clear()
    }

    private static func formattedName(_ components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let formatter = PersonNameComponentsFormatter()
        let name = formatter.string(from: components)
        return name.isEmpty ? nil : name
    }
}
