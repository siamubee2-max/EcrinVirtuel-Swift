import CryptoKit
import Foundation
import Security

/// Cryptographically bound nonce for Sign in with Apple, per Apple's + Supabase's
/// documented replay-protection pattern: the raw value is sent to Supabase for
/// `signInWithIdToken`, and its SHA-256 hash is set on `ASAuthorizationAppleIDRequest.nonce`
/// so the identity token Apple returns is tied to this specific request.
enum AppleSignInNonce {

    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed with OSStatus \(status)")

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
