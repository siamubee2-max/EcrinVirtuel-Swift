import Security
import SwiftUI

/// Les deux chemins de l'app qui envoient des données personnelles à un tiers IA.
/// Chacun a son propre consentement : refuser le styliste ne bloque pas l'essayage,
/// et refuser l'essayage ne bloque pas le styliste.
enum AIConsentPurpose: String, CaseIterable, Sendable {
    /// Envoi de la photo aux modèles d'image (fal.ai → Gemini → OpenAI).
    case tryOn    = "ai_consent_v1"
    /// Envoi du contexte personnel (garde-robe, météo, budget) au LLM du styliste.
    case styliste = "ai_consent_styliste_v1"
}

private struct AIConsentStorage {

    static func grant(_ purpose: AIConsentPurpose) {
        let payload = Data("\(Date().timeIntervalSince1970)".utf8)
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrAccount:      purpose.rawValue as CFString,
            kSecValueData:        payload,
            kSecAttrAccessible:   kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func revoke(_ purpose: AIConsentPurpose) {
        let query: [CFString: Any] = [
            kSecClass:        kSecClassGenericPassword,
            kSecAttrAccount:  purpose.rawValue as CFString
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func isGranted(_ purpose: AIConsentPurpose) -> Bool {
        let query: [CFString: Any] = [
            kSecClass:        kSecClassGenericPassword,
            kSecAttrAccount:  purpose.rawValue as CFString,
            kSecReturnData:   false
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }
}

/// Textes du modal, par chemin. Rien ici ne doit affirmer ce que nous ne pouvons
/// pas vérifier : ni promesse de non-entraînement, ni promesse de non-rétention
/// chez les tiers. On dit ce qui part, à qui, pourquoi, ce que NOUS supprimons,
/// et on renvoie à la politique de confidentialité pour le reste.
private struct AIConsentContent {
    let title: String
    let intro: String
    let rows: [(icon: String, text: String)]
    let acceptTitle: String
    let declineTitle: String

    static func of(_ purpose: AIConsentPurpose) -> AIConsentContent {
        switch purpose {
        case .tryOn:
            AIConsentContent(
                title: L10n.TryOnUI.aiPoweredTryOn,
                intro: L10n.TryOnUI.consentIntro,
                rows: [
                    ("photo.badge.arrow.down", L10n.TryOnUI.consentRecipients),
                    ("trash",                  L10n.TryOnUI.consentDeletion),
                    ("lock.shield",            L10n.TryOnUI.consentProviderPolicies),
                    ("globe",                  L10n.TryOnUI.consentTransfer),
                ],
                acceptTitle: L10n.TryOnUI.acceptAndTry,
                declineTitle: L10n.TryOnUI.decline
            )
        case .styliste:
            AIConsentContent(
                title: L10n.StylisteUI.consentTitle,
                intro: L10n.StylisteUI.consentIntro,
                rows: [
                    ("tshirt",      L10n.StylisteUI.consentData),
                    ("paperplane",  L10n.StylisteUI.consentRecipients),
                ],
                acceptTitle: L10n.StylisteUI.consentAccept,
                declineTitle: L10n.StylisteUI.consentDecline
            )
        }
    }
}

struct AIConsentModal: View {
    @Binding var isPresented: Bool
    var purpose: AIConsentPurpose = .tryOn
    let onAccept: () -> Void
    let onDecline: () -> Void

    private var content: AIConsentContent { .of(purpose) }

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
                        Text(content.title)
                            .font(EcrinFont.sectionHead)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(EcrinColor.textPrimary)

                        // Explication claire — Apple 5.1.1(i)/5.1.2(i) : quelles données,
                        // à qui elles sont envoyées, AVANT l'envoi. Cascade réelle de
                        // supabase/functions/tryon-generate : fal.ai → Gemini → OpenAI.
                        Text(content.intro)
                            .font(EcrinFont.caption)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(EcrinColor.textSecondary)
                            .padding(.horizontal, EcrinSpacing.md)

                        VStack(alignment: .leading, spacing: EcrinSpacing.md) {
                            ForEach(content.rows, id: \.icon) { row in
                                ConsentRow(icon: row.icon, text: row.text)
                            }
                        }
                        .padding(.horizontal, EcrinSpacing.md)

                        // Lien politique de confidentialité
                        Link(L10n.TryOnUI.consentPrivacyLink,
                             destination: URL(string: "https://inferencevision.store/ecrin/privacy.html")!)
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.gold.opacity(0.7))

                        // Actions
                        VStack(spacing: EcrinSpacing.sm) {
                            GoldButton(title: content.acceptTitle) {
                                AIConsentStorage.grant(purpose)
                                // Trace RGPD côté serveur (best-effort, non bloquant).
                                // La colonne serveur ne traque que l'envoi de photos.
                                if purpose == .tryOn {
                                    Task { await SupabaseService.shared.setAIConsent(granted: true) }
                                }
                                withAnimation(EcrinAnimation.springSnap) {
                                    isPresented = false
                                }
                                onAccept()
                            }

                            Button(content.declineTitle) {
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
    static func isGranted(_ purpose: AIConsentPurpose) -> Bool { AIConsentStorage.isGranted(purpose) }

    /// `true` si l'un au moins des consentements IA est actif — pilote l'affichage
    /// du bouton « retirer mon consentement » dans ProfileView.
    static var isGranted: Bool { AIConsentPurpose.allCases.contains(where: AIConsentStorage.isGranted) }

    /// Révoque TOUS les consentements IA (appel depuis ProfileView) : un retrait
    /// partiel serait incompréhensible depuis un unique bouton de profil.
    static func revoke() {
        AIConsentPurpose.allCases.forEach(AIConsentStorage.revoke)
        Task { await SupabaseService.shared.setAIConsent(granted: false) }
    }
}

private struct ConsentRow: View {
    let icon: String
    let text: String

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
