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
    }
}
