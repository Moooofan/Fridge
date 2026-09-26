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
