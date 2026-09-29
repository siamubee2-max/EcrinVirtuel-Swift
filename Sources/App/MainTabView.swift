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
                    .quickTryOnFAB { showQuickTryOn = true }
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
                .quickTryOnFAB { showQuickTryOn = true }
                .tabItem { Label(L10n.AppUI.wardrobe, systemImage: "tshirt.fill") }
                .tag(1)

                // Tab 2 — Boutique partenaires
                PartnerStoreView()
                    .accessibilityIdentifier("screen.boutique")
                    .quickTryOnFAB { showQuickTryOn = true }
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
                .quickTryOnFAB { showQuickTryOn = true }
                .tabItem { Label(L10n.AppUI.community, systemImage: "person.2") }
                .tag(3)

                // Tab 4 — Profil
                ProfileView()
                    .accessibilityIdentifier("screen.profil")
                    .quickTryOnFAB { showQuickTryOn = true }
                    .tabItem { Label(L10n.AppUI.profile, systemImage: "person.circle") }
                    .tag(4)
            }
            .tint(EcrinColor.gold)
            .preferredColorScheme(.dark)
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

// MARK: - Quick try-on FAB

private extension View {
    /// Pins the "Essayage rapide" button to the bottom-leading corner of a tab.
    /// Attached per tab (not over the TabView) so it sits inside the tab's safe
    /// area — above the tab bar on every device — instead of on top of a tab item
    /// (App Review 4.0, iPad: it used to cover "Boutique"). Leading, because
    /// Wardrobe and Mood Board already own the trailing corner.
    func quickTryOnFAB(action: @escaping () -> Void) -> some View {
        overlay(alignment: .bottomLeading) {
            Button(action: action) {
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
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.AppUI.quickTryOn)
            .accessibilityHint("Ouvre l'essayage virtuel")
            .accessibilityIdentifier("fab.quicktryon")
            .padding(.leading, EcrinSpacing.lg)
            .padding(.bottom, EcrinSpacing.xl)
        }
    }
}
