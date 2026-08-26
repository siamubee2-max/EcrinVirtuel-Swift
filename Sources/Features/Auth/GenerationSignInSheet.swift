import SwiftUI
import AuthenticationServices

// MARK: - Auth gate avant génération IA
// Une session anonyme silencieuse honore « 3 essais offerts · Aucune carte
// requise » ; le sheet Apple Sign-In n'apparaît qu'en dernier recours.

@MainActor
enum GenerationAuthGate {
    static func hasSession() async -> Bool {
        await SupabaseService.shared.hasValidSession()
    }

    /// Session existante, sinon tentative de session anonyme silencieuse.
    /// Retourne false uniquement si les deux échouent (hors-ligne, etc.) —
    /// dans ce cas l'appelant affiche GenerationSignInSheet.
    static func ensureSession() async -> Bool {
        if await SupabaseService.shared.hasValidSession() { return true }
        return await SupabaseService.shared.signInAnonymously()
    }
}

/// Sheet compacte affichée quand l'utilisateur tente une génération sans session Supabase.
struct GenerationSignInSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let onAuthenticated: () -> Void

    @State private var loginError: String?
    @State private var isSigningIn = false
    @State private var currentAppleNonce: String?

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            VStack(spacing: EcrinSpacing.xl) {
                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 32))
                        .foregroundStyle(EcrinColor.gold)
                    Text(L10n.AuthUI.signInRequired)
                        .font(EcrinFont.sectionHead)
                        .foregroundStyle(EcrinColor.textPrimary)
                    Text(L10n.AuthUI.signInWithApplePrompt)
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, EcrinSpacing.lg)
                }

                Spacer()

                VStack(spacing: EcrinSpacing.md) {
                    SignInWithAppleButton(.signIn) { request in
                        let nonce = AppleSignInNonce.randomNonceString()
                        currentAppleNonce = nonce
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = AppleSignInNonce.sha256(nonce)
                    } onCompletion: { result in
                        handleAppleSignIn(result)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 52)
                    .clipShape(Capsule())
                    .disabled(isSigningIn)

                    if let loginError {
                        Text(loginError)
                            .font(EcrinFont.caption)
                            .foregroundStyle(.red.opacity(0.85))
                            .multilineTextAlignment(.center)
                    }

                    Button(L10n.CommunityUI.later) { dismiss() }
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textMuted)
                }
                .padding(.horizontal, EcrinSpacing.lg)
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        guard case .success(let auth) = result,
              let creds = auth.credential as? ASAuthorizationAppleIDCredential,
              let idTokenData = creds.identityToken,
              let idToken = String(data: idTokenData, encoding: .utf8),
              let nonce = currentAppleNonce else {
            loginError = L10n.AuthUI.appleSignInCancelled
            return
        }

        isSigningIn = true
        loginError = nil

        Task {
            defer { isSigningIn = false }
            do {
                let user = try await SupabaseService.shared.signInWithApple(idToken: idToken, nonce: nonce)
                appState.signIn(user: user)
                await CreditsManager.shared.sync()
                dismiss()
                onAuthenticated()
            } catch {
                loginError = L10n.AuthUI.appleSignInFailed
            }
        }
    }
}
