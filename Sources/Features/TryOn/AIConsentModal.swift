import Security
import SwiftUI

private struct AIConsentStorage {
    private static let account = "ai_consent_v1"

    static func grant() {
        let payload = Data("\(Date().timeIntervalSince1970)".utf8)
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrAccount:      account as CFString,
            kSecValueData:        payload,
            kSecAttrAccessible:   kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func revoke() {
        let query: [CFString: Any] = [
            kSecClass:        kSecClassGenericPassword,
            kSecAttrAccount:  account as CFString
        ]
        SecItemDelete(query as CFDictionary)
    }

    static var isGranted: Bool {
        let query: [CFString: Any] = [
            kSecClass:        kSecClassGenericPassword,
            kSecAttrAccount:  account as CFString,
            kSecReturnData:   false
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }
}

struct AIConsentModal: View {
    @Binding var isPresented: Bool
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
                .onTapGesture { } // bloque les taps derrière

            VStack(spacing: 0) {
                Spacer()

                GlassCard(cornerRadius: 28) {
                    VStack(spacing: EcrinSpacing.lg) {

                        // Icône
                        ZStack {
                            Circle()
                                .fill(EcrinColor.gold.opacity(0.1))
                                .frame(width: 64, height: 64)
                            Image(systemName: "sparkles")
                                .font(.system(size: 28, weight: .light))
                                .foregroundStyle(EcrinColor.gold)
                        }
                        .padding(.top, EcrinSpacing.lg)

                        // Titre
                        Text(L10n.TryOnUI.aiPoweredTryOn)
                            .font(EcrinFont.sectionHead)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(EcrinColor.textPrimary)

                        // Explication claire (RGPD — tous les sous-traitants doivent être nommés)
                        VStack(alignment: .leading, spacing: EcrinSpacing.md) {
                            ConsentRow(
                                icon: "photo.badge.arrow.down",
                                text: "Votre photo est envoyée à **Google** (primaire) ou **OpenAI** (secours) pour l'essayage virtuel"
                            )
                            ConsentRow(
                                icon: "trash",
                                text: "Google et OpenAI ne conservent **pas** votre photo après le traitement"
                            )
                            ConsentRow(
                                icon: "lock.shield",
                                text: "Votre photo n'est **jamais** utilisée pour entraîner des modèles IA"
                            )
                            ConsentRow(
                                icon: "globe",
                                text: "Les données transitent vers les serveurs de Google et OpenAI (États-Unis)"
                            )
                        }
                        .padding(.horizontal, EcrinSpacing.md)

                        // Lien politique de confidentialité
                        Link("Lire notre politique de confidentialité →",
                             destination: URL(string: "https://inferencevision.store/ecrin/privacy")!)
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.gold.opacity(0.7))

                        // Actions
                        VStack(spacing: EcrinSpacing.sm) {
                            GoldButton(title: L10n.TryOnUI.acceptAndTry) {
                                AIConsentStorage.grant()
                                withAnimation(EcrinAnimation.springSnap) {
                                    isPresented = false
                                }
                                onAccept()
                            }

                            Button(L10n.TryOnUI.decline) {
                                withAnimation(EcrinAnimation.springSnap) {
                                    isPresented = false
                                }
                                onDecline()
                            }
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.textMuted)
                        }
                        .padding(.bottom, EcrinSpacing.lg)
                    }
                    .padding(.horizontal, EcrinSpacing.lg)
                }
                .padding(.horizontal, EcrinSpacing.lg)
                .padding(.bottom, 40)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    /// Vérifie si le consentement a déjà été accordé
    static var isGranted: Bool { AIConsentStorage.isGranted }

    /// Révoque le consentement RGPD (appel depuis ProfileView)
    static func revoke() { AIConsentStorage.revoke() }
}

private struct ConsentRow: View {
    let icon: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: EcrinSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(EcrinColor.gold)
                .frame(width: 20)
                .padding(.top, 2)

            Text(text)
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
