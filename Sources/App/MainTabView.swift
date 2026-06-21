import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showQuickTryOn = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {

                // Tab 0 — Essayage bijoux IA
                TryOnView()
                    .accessibilityIdentifier("screen.essayage")
                    .tabItem { Label("Essayage", systemImage: "sparkles") }
                    .tag(0)

                // Tab 1 — Garde-robe (mes vêtements) + Catalogue H/F
                NavigationStack {
                    WardrobeView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                NavigationLink(destination: CatalogBrowserView()) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "rectangle.grid.2x2")
                                        Text("Catalogue")
                                            .font(EcrinFont.caption)
                                    }
                                    .foregroundStyle(EcrinColor.gold)
                                }
                                .accessibilityLabel("Catalogue")
                            }
                        }
                }
                .accessibilityIdentifier("screen.garderobe")
                .tabItem { Label("Garde-robe", systemImage: "tshirt.fill") }
                .tag(1)

                // Tab 2 — Boutique partenaires
                PartnerStoreView()
                    .accessibilityIdentifier("screen.boutique")
                    .tabItem { Label("Boutique", systemImage: "bag") }
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
                                .accessibilityLabel("Tableau de bord")
                            }
                        }
                }
                .accessibilityIdentifier("screen.communaute")
                .tabItem { Label("Communauté", systemImage: "person.2") }
                .tag(3)

                // Tab 4 — Profil
                ProfileView()
                    .accessibilityIdentifier("screen.profil")
                    .tabItem { Label("Profil", systemImage: "person.circle") }
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
            .accessibilityLabel("Essayage rapide")
            .accessibilityHint("Ouvre l'essayage virtuel")
            .accessibilityIdentifier("fab.quicktryon")
            .offset(y: -28)
            .sheet(isPresented: $showQuickTryOn) {
                QuickTryOnView()
                    .environment(ClothingCatalogService.shared)
            }
        }
        .task {
            await ClothingCatalogService.shared.fetchAll(force: true)
        }
    }
}
