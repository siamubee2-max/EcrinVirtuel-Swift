import SwiftUI
import AuthenticationServices

// MARK: - Auth gate avant génération IA (Option B — Apple Sign-In obligatoire)

@MainActor
enum GenerationAuthGate {
    static func hasSession() async -> Bool {
        await SupabaseService.shared.hasValidSession()
    }
}

/// Sheet compacte affichée quand l'utilisateur tente une génération sans session Supabase.
struct GenerationSignInSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let onAuthenticated: () -> Void

    @State private var loginError: String?
    @State private var isSigningIn = false

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            VStack(spacing: EcrinSpacing.xl) {
                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 32))
                        .foregroundStyle(EcrinColor.gold)
                    Text("Connexion requise")
                        .font(EcrinFont.sectionHead)
                        .foregroundStyle(EcrinColor.textPrimary)
                    Text("Connectez-vous avec Apple pour lancer votre essayage virtuel et synchroniser vos crédits.")
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, EcrinSpacing.lg)
                }

                Spacer()

                VStack(spacing: EcrinSpacing.md) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
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

                    Button("Plus tard") { dismiss() }
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
              let idToken = String(data: idTokenData, encoding: .utf8) else {
            loginError = "Connexion Apple annulée."
            return
        }

        isSigningIn = true
        loginError = nil

        Task {
            defer { isSigningIn = false }
            do {
                let nonce = UUID().uuidString
                let user = try await SupabaseService.shared.signInWithApple(idToken: idToken, nonce: nonce)
                appState.signIn(user: user)
                await CreditsManager.shared.sync()
                dismiss()
                onAuthenticated()
            } catch {
                loginError = "Connexion Apple échouée. Réessayez."
            }
        }
    }
}
