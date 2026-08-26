import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @ObservedObject private var gaming = GamingService.shared
    @State private var selectedTab = 0
    @State private var showQuickTryOn = false

    var body: some View {
        @Bindable var appState = appState
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {

                // Tab 0 — Essayage bijoux IA
                TryOnView()
                    .accessibilityIdentifier("screen.essayage")
                    .tabItem { Label(L10n.TryOn.title, systemImage: "sparkles") }
                    .tag(0)

                // Tab 1 — Garde-robe (mes vêtements) + Catalogue H/F
                NavigationStack {
                    WardrobeView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                NavigationLink(destination: CatalogBrowserView()) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "rectangle.grid.2x2")
                                        Text(L10n.LookOfDay.catalogButton)
                                            .font(EcrinFont.caption)
                                    }
                                    .foregroundStyle(EcrinColor.gold)
                                }
                                .accessibilityLabel(L10n.LookOfDay.catalogButton)
                            }
                        }
                }
                .accessibilityIdentifier("screen.garderobe")
                .tabItem { Label(L10n.AppUI.wardrobe, systemImage: "tshirt.fill") }
                .tag(1)

                // Tab 2 — Boutique partenaires
                PartnerStoreView()
                    .accessibilityIdentifier("screen.boutique")
                    .tabItem { Label(L10n.Home.boutique, systemImage: "bag") }
                    .tag(2)

                // Tab 3 — Communauté + Gaming
                NavigationStack {
                    CommunityView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                NavigationLink(destination: GamingDashboardView()) {
                                    Image(systemName: "trophy.fill")
                                        .foregroundStyle(EcrinColor.gold)
                                }
                                .accessibilityLabel(L10n.AppUI.dashboard)
                            }
                        }
                }
                .accessibilityIdentifier("screen.communaute")
                .tabItem { Label(L10n.AppUI.community, systemImage: "person.2") }
                .tag(3)

                // Tab 4 — Profil
                ProfileView()
                    .accessibilityIdentifier("screen.profil")
                    .tabItem { Label(L10n.AppUI.profile, systemImage: "person.circle") }
                    .tag(4)
            }
            .tint(EcrinColor.gold)
            .preferredColorScheme(.dark)

            // FAB "Essayage rapide" centré au-dessus de la tab bar
            Button {
                showQuickTryOn = true
            } label: {
                ZStack {
                    Circle()
                        .fill(EcrinColor.gold)
                        .frame(width: 56, height: 56)
                        .shadow(color: EcrinColor.gold.opacity(0.5), radius: 12, y: 4)
                    Image(systemName: "tshirt")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(EcrinColor.background)
                }
            }
            .accessibilityLabel(L10n.AppUI.quickTryOn)
            .accessibilityHint("Ouvre l'essayage virtuel")
            .accessibilityIdentifier("fab.quicktryon")
            .offset(y: -28)
            .sheet(isPresented: $showQuickTryOn) {
                QuickTryOnView()
                    .environment(ClothingCatalogService.shared)
            }

            // Toasts XP — l'overlay n'était monté nulle part : les récompenses
            // s'accumulaient dans pendingRewards sans jamais s'afficher.
            XPToastQueueOverlay(gaming: gaming)

            // Célébration de passage de niveau
            if gaming.showLevelUp, let newLevel = gaming.levelUpTo {
                LevelUpCelebrationView(newLevel: newLevel) {
                    gaming.showLevelUp = false
                    gaming.levelUpTo = nil
                }
                .zIndex(10)
                .transition(.opacity)
            }
        }
        // Cadeau reçu via ecrin://gift/<uuid>
        .fullScreenCover(item: $appState.pendingGift) { pending in
            GiftRevealView(giftID: pending.id)
                .environment(appState)
                .environment(ClothingCatalogService.shared)
        }
        .task {
            // force: false — the app boot sequence already calls fetchAll(force: true).
            // Forcing here triggers a duplicate 3-gender network fetch on every tab switch.
            await ClothingCatalogService.shared.fetchAll(force: false)
        }
    }
}
