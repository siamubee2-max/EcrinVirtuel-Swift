import SwiftUI
import AuthenticationServices
import Supabase

// MARK: - Auth gate avant génération IA
// Une session anonyme silencieuse honore « 3 essais offerts · Aucune carte
// requise » ; le sheet Apple Sign-In n'apparaît qu'en dernier recours.

@MainActor
enum GenerationAuthGate {
    static func hasSession() async -> Bool {
        await SupabaseService.shared.hasValidSession()
    }

    /// Session existante, sinon session anonyme fraîchement créée.
    ///
    /// Renvoie la session elle-même : un appelant qui a besoin de l'utilisateur
    /// ne doit PAS relire `auth.session` juste après, car le SDK peut encore
    /// renvoyer `nil` le temps de la persister — c'est ce qui renvoyait
    /// l'onboarding sur l'écran de connexion alors que la session était créée.
    static func currentOrAnonymousSession() async -> Session? {
        if let existing = try? await SupabaseService.shared.auth.session { return existing }
        return await SupabaseService.shared.signInAnonymously()
    }

    /// Variante booléenne pour les appelants qui n'ont besoin que du feu vert.
    /// Retourne false uniquement si les deux échouent (hors-ligne, etc.) —
    /// dans ce cas l'appelant affiche GenerationSignInSheet.
    static func ensureSession() async -> Bool {
        await currentOrAnonymousSession() != nil
    }

    /// Identité EXIGÉE avant tout achat — aucune session n'est créée ici.
    ///
    /// Les connexions anonymes sont désactivées côté projet (`signup` renvoie
    /// 422 `anonymous_provider_disabled`) : tenter d'en ouvrir une échouait
    /// silencieusement et l'achat partait sous un `$RCAnonymousID:…` que le
    /// webhook ignore (`non_uuid_app_user_id`) — encaissé, jamais crédité.
    /// L'appelant DOIT présenter `GenerationSignInSheet` quand ceci renvoie
    /// `false`, et ne relancer le paiement qu'ensuite.
    ///
    /// Une session anonyme résiduelle (build antérieur) est traitée comme une
    /// absence de session : les crédits payés y seraient orphelins.
    static func requirePurchaseIdentity() async -> Bool {
        guard let user = try? await SupabaseService.shared.auth.session.user,
              !user.isAnonymous
        else { return false }
        await RevenueCatService.logIn(userId: user.id.uuidString)
        return true
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
