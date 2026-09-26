import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

/// Sign in with Apple 共用的小工具：nonce 產生（Apple 官方範例的標準作法：隨機字串 +
/// SHA256）以及找目前 key window，給 `LoginView` 的 `SignInWithAppleButton` 與
/// `ASWebAuthenticationSession`（LINE web OAuth）共用。
///
/// 實際的 `ASAuthorizationController` 流程改由 SwiftUI 內建的 `SignInWithAppleButton`
/// 自己驅動（見 `LoginView`）——它會自己管理 delegate／presentation anchor，這裡就不用
/// 再包一份 continuation-based 的 controller 了，也避免跟按鈕自己的授權流程重複觸發。
enum AppleSignInCoordinator {
    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        precondition(status == errSecSuccess, "Unable to generate nonce, SecRandomCopyBytes failed with OSStatus \(status)")

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { byte in charset[Int(byte) % charset.count] })
    }

    static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

    static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

/// 刪除帳號前重新跑一次 Sign in with Apple，只為了拿一個新的 `authorizationCode`
/// 交給 `delete-account` Edge Function 撤銷 Apple 授權（Apple 要求撤銷 token，
/// 而 code 是一次性、5 分鐘內有效，所以必須在刪除當下重新取得）。
@MainActor
final class AppleReauthorizer: NSObject, ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<String, Error>?
    /// 流程進行中保留自己，避免 delegate 在回呼前被釋放。
    private static var inFlight: AppleReauthorizer?

    static func requestAuthorizationCode() async throws -> String {
        let reauthorizer = AppleReauthorizer()
        inFlight = reauthorizer
        defer { inFlight = nil }
        return try await withCheckedThrowingContinuation { continuation in
            reauthorizer.continuation = continuation
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = []
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = reauthorizer
            controller.presentationContextProvider = reauthorizer
            controller.performRequests()
        }
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let codeData = credential.authorizationCode,
              let code = String(data: codeData, encoding: .utf8) else {
            finish(.failure(AuthError.missingIdentityToken))
            return
        }
        finish(.success(code))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            finish(.failure(AuthError.cancelled))
        } else {
            finish(.failure(AuthError.unknown(error)))
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        AppleSignInCoordinator.keyWindow() ?? ASPresentationAnchor()
    }

    private func finish(_ result: Result<String, Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }
}
