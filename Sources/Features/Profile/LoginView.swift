import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(AppState.self) private var appState
    @State private var email = ""
    @State private var otpCode = ""
    @State private var isLoading = false
    @State private var codeSent = false       // true après envoi du code → affiche le champ code
    @State private var loginError: String?
    @State private var currentAppleNonce: String?
    @FocusState private var codeFieldFocused: Bool

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            VStack(spacing: EcrinSpacing.xl) {
                Spacer()

                // Logo
                VStack(spacing: 8) {
                    Text("✦")
                        .font(.system(size: 28))
                        .foregroundStyle(EcrinColor.gold)
                    Text(L10n.OnboardingUI.brandName)
                        .font(EcrinFont.label)
                        .kerning(5)
                        .foregroundStyle(EcrinColor.textPrimary)
                    Text(L10n.ProfileUI.virtualJewelry)
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textMuted)
                        .kerning(2)
                }

                Spacer()

                // Auth options
                VStack(spacing: EcrinSpacing.md) {
                    // Sign in with Apple
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

                    // Divider
                    HStack {
                        Rectangle().fill(EcrinColor.glassStroke).frame(height: 0.5)
                        Text("ou")
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.textMuted)
                        Rectangle().fill(EcrinColor.glassStroke).frame(height: 0.5)
                    }

                    // Email — désactivé une fois le code envoyé
                    GlassCard(cornerRadius: 14) {
                        HStack {
                            Image(systemName: "envelope")
                                .font(.system(size: 14))
                                .foregroundStyle(EcrinColor.textMuted)
                            TextField("", text: $email, prompt: Text(L10n.ProfileUI.emailPlaceholder).foregroundStyle(EcrinColor.textMuted))
                                .foregroundStyle(EcrinColor.textPrimary)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .disabled(codeSent)
                        }
                        .padding(EcrinSpacing.md)
                    }
                    .opacity(codeSent ? 0.6 : 1)

                    // Étape 2 : champ code à 6 chiffres (après envoi)
                    if codeSent {
                        GlassCard(cornerRadius: 14) {
                            HStack {
                                Image(systemName: "key")
                                    .font(.system(size: 14))
                                    .foregroundStyle(EcrinColor.gold)
                                TextField("", text: $otpCode, prompt: Text(L10n.ProfileUI.sixDigitCode).foregroundStyle(EcrinColor.textMuted))
                                    .foregroundStyle(EcrinColor.textPrimary)
                                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                                    .kerning(4)
                                    .keyboardType(.numberPad)
                                    .textContentType(.oneTimeCode)
                                    .focused($codeFieldFocused)
                                    .onChange(of: otpCode) { _, newValue in
                                        // Garde 6 chiffres max ; auto-vérifie quand complet
                                        let digits = newValue.filter(\.isNumber)
                                        if digits.count > 6 { otpCode = String(digits.prefix(6)) }
                                        else if digits != newValue { otpCode = digits }
                                        if otpCode.count == 6 { Task { await verifyCode() } }
                                    }
                            }
                            .padding(EcrinSpacing.md)
                        }

                        HStack(spacing: 8) {
                            Image(systemName: "envelope.badge.checkmark")
                                .foregroundStyle(EcrinColor.gold)
                            Text("Code envoyé à \(email)")
                                .font(EcrinFont.caption)
                                .foregroundStyle(EcrinColor.textSecondary)
                        }
                    }

                    if let error = loginError {
                        Text(error)
                            .font(EcrinFont.caption)
                            .foregroundStyle(.red.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }

                    if !codeSent {
                        GoldButton(title: isLoading ? "Envoi…" : "Recevoir un code") {
                            Task { await signInWithEmail() }
                        }
                        .disabled(email.isEmpty || isLoading)
                        .opacity(email.isEmpty ? 0.5 : 1)

                        // Permet de saisir un code déjà reçu sans redéclencher d'envoi
                        // (utile si l'envoi est limité, ou pour un code fourni manuellement).
                        Button(L10n.ProfileUI.alreadyHaveCode) {
                            withAnimation { codeSent = true }
                            codeFieldFocused = true
                        }
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textMuted)
                        .disabled(email.isEmpty)
                    } else {
                        GoldButton(title: isLoading ? "Connexion…" : "Se connecter") {
                            Task { await verifyCode() }
                        }
                        .disabled(otpCode.count != 6 || isLoading)
                        .opacity(otpCode.count != 6 ? 0.5 : 1)

                        Button(L10n.ProfileUI.resendCodeChangeEmail) {
                            withAnimation {
                                codeSent = false
                                otpCode = ""
                                loginError = nil
                            }
                        }
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textMuted)
                    }
                }
                .padding(.horizontal, EcrinSpacing.lg)

                // Privacy
                VStack(spacing: 4) {
                    Text(L10n.ProfileUI.byContinuingYouAccept)
                        .font(.system(size: 10))
                        .foregroundStyle(EcrinColor.textMuted)
                    HStack(spacing: 4) {
                        Link("CGU", destination: URL(string: "https://inferencevision.store/ecrin/terms")!)
                        Text("·")
                        Link("Confidentialité", destination: URL(string: "https://inferencevision.store/ecrin/privacy")!)
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(EcrinColor.gold.opacity(0.7))
                }
                .padding(.bottom, 40)

                #if DEBUG
                // MARK: - Dev bypass (simulator only)
                // Permet de naviguer l'UI sans configurer un compte Apple ID dans le sim.
                // Les appels Supabase échoueront (pas de vraie session) — utiliser un
                // device réel pour tester le backend.
                Button {
                    let devUser = User(
                        id: UUID(uuidString: "DEADBEEF-0000-4000-8000-000000000DEV") ?? UUID(),
                        email: "dev@local.test",
                        displayName: "Dev User"
                    )
                    appState.signIn(user: devUser)
                } label: {
                    Text(L10n.ProfileUI.devSkipLogin)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(EcrinColor.textMuted.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(EcrinColor.textMuted.opacity(0.3), style: StrokeStyle(lineWidth: 0.5, dash: [3]))
                        )
                }
                .buttonStyle(.plain)
                .padding(.bottom, 12)
                #endif
            }
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        guard case .success(let auth) = result,
              let creds = auth.credential as? ASAuthorizationAppleIDCredential,
              let idTokenData = creds.identityToken,
              let idToken = String(data: idTokenData, encoding: .utf8),
              let nonce = currentAppleNonce else {
            loginError = "Connexion Apple échouée. Réessayez."
            return
        }

        Task {
            do {
                let user = try await SupabaseService.shared.signInWithApple(idToken: idToken, nonce: nonce)
                appState.signIn(user: user)
            } catch {
                loginError = "Connexion Apple échouée. Réessayez."
            }
        }
    }

    private func signInWithEmail() async {
        guard email.contains("@"), email.contains(".") else {
            loginError = "Adresse email invalide."
            return
        }
        isLoading = true
        loginError = nil
        defer { isLoading = false }
        do {
            try await SupabaseService.shared.signInWithEmail(email)
            withAnimation { codeSent = true }
            codeFieldFocused = true
        } catch {
            loginError = "Impossible d'envoyer le code. Vérifiez votre email."
        }
    }

    private func verifyCode() async {
        let code = otpCode.filter(\.isNumber)
        guard code.count == 6 else { return }
        guard !isLoading else { return }
        isLoading = true
        loginError = nil
        defer { isLoading = false }
        do {
            let user = try await SupabaseService.shared.verifyEmailOTP(email: email, code: code)
            appState.signIn(user: user)
        } catch {
            loginError = "Code invalide ou expiré. Réessayez."
            otpCode = ""
        }
    }
}
