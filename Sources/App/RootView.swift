import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            switch appState.phase {
            case .onboarding:
                CinematicOnboardingView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .authenticated:
                MainTabView()
                    .transition(.opacity)
            case .unauthenticated:
                LoginView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: appState.phase)
        // Résultat d'un lien de parrainage (ecrin://ref/…)
        .alert(
            "Parrainage",
            isPresented: Binding(
                get: { appState.referralMessage != nil },
                set: { if !$0 { appState.referralMessage = nil } }
            )
        ) {
            Button("OK") { appState.referralMessage = nil }
        } message: {
            Text(appState.referralMessage ?? "")
        }
        .task {
            // Restaure une session Supabase existante (anonyme ou Apple) au
            // lancement, pour ne pas réafficher l'écran de connexion à chaque
            // démarrage alors qu'une session valide est en keychain.
            guard appState.phase == .unauthenticated,
                  let session = try? await SupabaseService.shared.auth.session else { return }
            appState.signIn(user: User(
                id: session.user.id,
                email: session.user.email ?? "invitee@anonyme.ecrin.local",
                displayName: session.user.email == nil ? "Invitée" : nil
            ))
        }
    }
}
