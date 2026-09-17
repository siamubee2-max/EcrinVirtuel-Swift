import SwiftUI
import UIKit

/// Porte de consentement IA — Apple Guidelines 5.1.1(i) / 5.1.2(i).
///
/// Point de passage UNIQUE : `ImageGenerationService.sendRequest` l'interroge avant
/// tout envoi de photo. Aucun écran appelant n'a à la présenter lui-même, donc un
/// nouvel appelant ne peut pas la contourner par omission.
///
/// La présentation se fait dans une `UIWindow` dédiée au niveau `.alert` : les
/// essayages sont déclenchés depuis des `sheet` / `fullScreenCover` empilés
/// au-dessus de `RootView`, où un simple overlay racine serait masqué.
@MainActor
enum AIConsentGate {

    /// Filet de sécurité contre un re-prompt immédiat après un refus (deux écrans
    /// qui déclenchent une génération coup sur coup). Ce n'est PAS ce qui protège
    /// la boucle multi-poses : celle-ci s'interrompt au premier refus.
    private static let declineGraceWindow: TimeInterval = 15

    private static var window: UIWindow?
    private static var continuation: CheckedContinuation<Bool, Never>?
    private static var lastDeclineDates: [AIConsentPurpose: Date] = [:]

    /// `true` si les données de ce chemin peuvent partir. Présente le modal et suspend
    /// l'appelant tant que l'utilisatrice n'a pas répondu. Relit le keychain à chaque
    /// appel : après une révocation depuis le profil, le consentement est redemandé.
    static func requireConsent(for purpose: AIConsentPurpose = .tryOn) async -> Bool {
        if AIConsentModal.isGranted(purpose) { return true }
        // Un modal est déjà à l'écran (deux générations concurrentes) : on refuse la
        // seconde plutôt que d'empiler deux fenêtres.
        guard continuation == nil else { return false }
        if let last = lastDeclineDates[purpose], Date().timeIntervalSince(last) < declineGraceWindow {
            return false
        }

        return await withCheckedContinuation { cont in
            continuation = cont
            present(purpose)
        }
    }

    private static func present(_ purpose: AIConsentPurpose) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else {
            finish(purpose, granted: false)
            return
        }

        let modal = AIConsentModal(
            isPresented: .constant(true),
            purpose:   purpose,
            onAccept:  { finish(purpose, granted: true) },
            onDecline: { finish(purpose, granted: false) }
        )
        let host = UIHostingController(rootView: modal.preferredColorScheme(.dark))
        host.view.backgroundColor = .clear

        let consentWindow = UIWindow(windowScene: scene)
        consentWindow.rootViewController = host
        consentWindow.backgroundColor = .clear
        consentWindow.windowLevel = .alert + 1
        consentWindow.makeKeyAndVisible()
        window = consentWindow
    }

    private static func finish(_ purpose: AIConsentPurpose, granted: Bool) {
        lastDeclineDates[purpose] = granted ? nil : Date()
        window?.isHidden = true
        window = nil
        let pending = continuation
        continuation = nil
        pending?.resume(returning: granted)
    }
}
