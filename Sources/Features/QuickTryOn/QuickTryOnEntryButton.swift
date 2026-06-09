import SwiftUI

// MARK: - QuickTryOnEntryButton
// Bouton d'entrée rapide réutilisable sur WardrobeView, CatalogBrowserView, BoutiqueView.
// Si `item` est fourni, la QuickTryOnView s'ouvre avec cet article pré-sélectionné.

struct QuickTryOnEntryButton: View {
    let item: QuickTryOnItem?
    var style: ButtonStyle = .gold

    @State private var showSheet = false

    enum ButtonStyle {
        case gold     // bouton plein or (principal)
        case ghost    // contour or (secondaire)
        case compact  // icône seule + label court (pour les cartes)
    }

    var body: some View {
        Button {
            showSheet = true
        } label: {
            buttonLabel
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showSheet) {
            QuickTryOnView(preselectedItem: item)
                .environment(ClothingCatalogService.shared)
        }
    }

    @ViewBuilder
    private var buttonLabel: some View {
        switch style {
        case .gold:
            HStack(spacing: EcrinSpacing.sm) {
                Image(systemName: "sparkle")
                    .font(.system(size: 13))
                Text(buttonTitle)
                    .font(EcrinFont.cta)
                    .kerning(2)
                    .textCase(.uppercase)
            }
            .foregroundStyle(EcrinColor.background)
            .padding(.horizontal, EcrinSpacing.xl)
            .padding(.vertical, EcrinSpacing.md)
            .background(EcrinColor.gold)
            .clipShape(Capsule())

        case .ghost:
            HStack(spacing: EcrinSpacing.sm) {
                Image(systemName: "sparkle")
                    .font(.system(size: 13))
                Text(buttonTitle)
                    .font(EcrinFont.cta)
                    .kerning(2)
                    .textCase(.uppercase)
            }
            .foregroundStyle(EcrinColor.gold)
            .padding(.horizontal, EcrinSpacing.xl)
            .padding(.vertical, EcrinSpacing.md)
            .overlay {
                Capsule().strokeBorder(EcrinColor.gold.opacity(0.5), lineWidth: 1)
            }

        case .compact:
            HStack(spacing: 5) {
                Image(systemName: "sparkle")
                    .font(.system(size: 11))
                Text("Essayer")
                    .font(EcrinFont.cta)
                    .kerning(1.5)
            }
            .foregroundStyle(EcrinColor.gold)
            .padding(.horizontal, EcrinSpacing.md)
            .padding(.vertical, 6)
            .background(EcrinColor.gold.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(EcrinColor.gold.opacity(0.3), lineWidth: 0.5))
        }
    }

    private var buttonTitle: String {
        if let item = item {
            return "Essayer \(item.name)"
        }
        return "Essayage Rapide"
    }
}

// MARK: - Convenience initializers

extension QuickTryOnEntryButton {
    // Depuis un FashionItem (garde-robe)
    init(fashionItem: FashionItem, style: ButtonStyle = .compact) {
        self.init(item: .wardrobe(fashionItem), style: style)
    }

    // Depuis un CatalogClothingItem (catalogue)
    init(catalogItem: CatalogClothingItem, style: ButtonStyle = .compact) {
        self.init(item: .catalog(catalogItem), style: style)
    }

    // Démarrer depuis zéro (aucun item pré-sélectionné)
    init(style: ButtonStyle = .gold) {
        self.init(item: nil, style: style)
    }
}

// MARK: - QuickTryOnFAB
// Floating Action Button pour lancer l'essayage rapide depuis n'importe quelle vue.

struct QuickTryOnFAB: View {
    @State private var showSheet = false
    @State private var glowPulse = false

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showSheet = true
        } label: {
            ZStack {
                // Pulsing glow ring
                Circle()
                    .fill(EcrinColor.gold.opacity(0.15))
                    .frame(width: 72, height: 72)
                    .scaleEffect(glowPulse ? 1.15 : 0.95)
                    .opacity(glowPulse ? 0 : 0.6)
                    .animation(
                        .easeInOut(duration: 2.0).repeatForever(autoreverses: false),
                        value: glowPulse
                    )

                Circle()
                    .fill(EcrinColor.gold)
                    .frame(width: 60, height: 60)
                    .shadow(color: EcrinColor.gold.opacity(0.45), radius: 14, y: 5)

                VStack(spacing: 1) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(EcrinColor.background)
                    Text("Essayer")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(EcrinColor.background.opacity(0.8))
                        .kerning(1)
                }
            }
        }
        .buttonStyle(.plain)
        .onAppear { glowPulse = true }
        .fullScreenCover(isPresented: $showSheet) {
            QuickTryOnView()
                .environment(ClothingCatalogService.shared)
        }
    }
}
