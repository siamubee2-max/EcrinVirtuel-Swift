import SwiftUI

// MARK: - PartnerDetailView

struct PartnerDetailView: View {

    let brand: PartnerBrand

    // Environment
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    // Local state
    @State private var catalog: [JewelryItem] = []
    @State private var isLoadingCatalog = true
    @State private var selectedJewelryForTryOn: JewelryItem? = nil

    private let service = PartnerService.shared

    var body: some View {
        ZStack(alignment: .top) {
            EcrinColor.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    immersiveHeader

                    contentBody
                        .padding(.top, EcrinSpacing.lg)
                        .padding(.bottom, EcrinSpacing.xxl)
                }
            }
            .ignoresSafeArea(edges: .top)

            // Custom back button
            backButton
        }
        .navigationBarHidden(true)
        .task {
            catalog = await service.fetchPartnerCatalog(id: brand.id)
            isLoadingCatalog = false
        }
        .sheet(item: $selectedJewelryForTryOn) { jewelry in
            // Pré-sélectionner le bijou tapé — TryOnView() nu ignorait
            // selectedJewelryForTryOn et ouvrait l'essayage à vide.
            QuickTryOnView(
                preselectedItem: .wardrobe(jewelry.asFashionItem),
                preselectedMode: .jewelsOnly
            )
            .environment(appState)
            .environment(ClothingCatalogService.shared)
            .presentationDetents([.large])
        }
    }

    // MARK: - Immersive header

    private var immersiveHeader: some View {
        ZStack(alignment: .bottomLeading) {
            // Background gradient
            Rectangle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: EcrinColor.gold.opacity(0.18), location: 0),
                            .init(color: EcrinColor.gold.opacity(0.04), location: 0.5),
                            .init(color: EcrinColor.background, location: 1),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 280)

            // Decorative circles
            Circle()
                .fill(EcrinColor.gold.opacity(0.06))
                .frame(width: 200, height: 200)
                .offset(x: -40, y: -20)
                .blur(radius: 30)

            Circle()
                .fill(EcrinColor.gold.opacity(0.10))
                .frame(width: 120, height: 120)
                .offset(x: UIScreen.main.bounds.width - 80, y: -60)
                .blur(radius: 20)

            // Large initials monogram
            Text(String(brand.name.prefix(1)).uppercased())
                .font(EcrinFont.serif(160, weight: .thin))
                .foregroundStyle(EcrinColor.gold.opacity(0.06))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, EcrinSpacing.xl)
                .padding(.bottom, EcrinSpacing.xl)

            // Brand info overlay
            VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
                // Category pill
                Label(brand.category.rawValue, systemImage: brand.category.icon)
                    .font(EcrinFont.caption)
                    .kerning(0.5)
                    .foregroundStyle(EcrinColor.gold)
                    .padding(.horizontal, EcrinSpacing.md)
                    .padding(.vertical, EcrinSpacing.xs)
                    .background(EcrinColor.gold.opacity(0.12))
                    .clipShape(Capsule())

                HStack(alignment: .bottom, spacing: EcrinSpacing.sm) {
                    Text(brand.name)
                        .font(EcrinFont.heroTitle)
                        .foregroundStyle(EcrinColor.textPrimary)
                        .lineLimit(2)

                    if brand.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(EcrinColor.gold)
                            .padding(.bottom, 6)
                    }
                }

                HStack(spacing: EcrinSpacing.md) {
                    Label(brand.country, systemImage: "mappin")
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textSecondary)

                    Label("\(brand.catalog.count) bijoux", systemImage: "sparkles")
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textSecondary)
                }
            }
            .padding(.horizontal, EcrinSpacing.lg)
            .padding(.bottom, EcrinSpacing.xl)
        }
    }

    // MARK: - Content body

    private var contentBody: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.xl) {
            // Catalogue en premier — articles visibles directement
            catalogSection

            // À propos
            aboutSection
                .padding(.horizontal, EcrinSpacing.lg)

            // CTA site web
            websiteCTA
                .padding(.horizontal, EcrinSpacing.lg)
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.md) {
            sectionTitle(L10n.PartnerUI.aboutCaps, icon: "doc.text")

            GlassCard(cornerRadius: 18) {
                Text(brand.description)
                    .font(EcrinFont.body)
                    .foregroundStyle(EcrinColor.textSecondary)
                    .lineSpacing(5)
                    .padding(EcrinSpacing.lg)
            }
        }
    }

    // MARK: - Catalog

    private var catalogSection: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.md) {
            sectionTitle(L10n.CatalogUI.catalogCaps, icon: "sparkles")
                .padding(.horizontal, EcrinSpacing.lg)

            if isLoadingCatalog {
                catalogSkeleton
            } else if catalog.isEmpty {
                Text(L10n.PartnerUI.catalogLoading)
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textMuted)
                    .padding(.horizontal, EcrinSpacing.lg)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: EcrinSpacing.md),
                        GridItem(.flexible(), spacing: EcrinSpacing.md),
                    ],
                    spacing: EcrinSpacing.md
                ) {
                    ForEach(catalog) { item in
                        JewelryCatalogCard(item: item, brand: brand) {
                            // Try-on : présélectionne le bijou → `.sheet(item:)` l'ouvre
                            service.trackClick(jewelry: item, partner: brand)
                            selectedJewelryForTryOn = item
                        } onBuy: {
                            service.trackClick(jewelry: item, partner: brand)
                            openBrandWebsite()
                        }
                    }
                }
                .padding(.horizontal, EcrinSpacing.lg)
                .animation(EcrinAnimation.springSnap, value: catalog.count)
            }
        }
    }

    // MARK: - Catalog skeleton

    private var catalogSkeleton: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: EcrinSpacing.md), GridItem(.flexible(), spacing: EcrinSpacing.md)],
            spacing: EcrinSpacing.md
        ) {
            ForEach(0..<4, id: \.self) { _ in
                GlassCard(cornerRadius: 18) {
                    VStack {
                        Rectangle()
                            .fill(EcrinColor.glassFill)
                            .frame(height: 90)
                        VStack(spacing: EcrinSpacing.sm) {
                            Capsule().fill(EcrinColor.glassFill).frame(height: 12)
                            Capsule().fill(EcrinColor.glassFill).frame(width: 80, height: 10)
                        }
                        .padding(EcrinSpacing.md)
                    }
                }
                .opacity(0.5)
                .shimmer()
            }
        }
        .padding(.horizontal, EcrinSpacing.lg)
    }

    // MARK: - Website CTA

    private var websiteCTA: some View {
        GlassCard(cornerRadius: 20) {
            HStack(spacing: EcrinSpacing.md) {
                VStack(alignment: .leading, spacing: EcrinSpacing.xs) {
                    Text(L10n.PartnerUI.discoverShop)
                        .font(EcrinFont.cardTitle)
                        .foregroundStyle(EcrinColor.textPrimary)
                    if let url = brand.websiteURL {
                        Text(url.host ?? "")
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.textMuted)
                    }
                }

                Spacer()

                Button {
                    openBrandWebsite()
                } label: {
                    HStack(spacing: EcrinSpacing.xs) {
                        Text(L10n.PartnerUI.visit)
                            .font(EcrinFont.cta)
                            .kerning(2)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(EcrinColor.background)
                    .padding(.horizontal, EcrinSpacing.lg)
                    .padding(.vertical, EcrinSpacing.sm)
                    .background(EcrinColor.gold)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(EcrinSpacing.lg)
        }
    }

    // MARK: - Back button

    private var backButton: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(EcrinColor.textPrimary)
                    .padding(EcrinSpacing.md)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.leading, EcrinSpacing.lg)
            .padding(.top, 52)

            Spacer()
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String, icon: String) -> some View {
        HStack(spacing: EcrinSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(EcrinColor.gold)
            Text(text)
                .font(EcrinFont.label)
                .kerning(2)
                .foregroundStyle(EcrinColor.textMuted)
        }
    }

    private func openBrandWebsite() {
        guard let url = brand.websiteURL else { return }
        UIApplication.shared.open(url)
    }

}

// MARK: - JewelryCatalogCard

private struct JewelryCatalogCard: View {
    let item: JewelryItem
    let brand: PartnerBrand
    let onTryOn: () -> Void
    let onBuy: () -> Void

    @State private var isPressed = false

    private var iconFallback: some View {
        Image(systemName: item.icon)
            .font(.system(size: 36, weight: .thin))
            .foregroundStyle(EcrinColor.gold.opacity(0.7))
    }

    var body: some View {
        GlassCard(cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 0) {
                // Zone image — photo réelle si disponible, icône en fallback
                ZStack {
                    // Fond dégradé toujours présent
                    LinearGradient(
                        colors: [EcrinColor.gold.opacity(0.06), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    if let url = item.imageURL {
                        DownsampledAsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable()
                                    .scaledToFill()
                                    .clipped()
                            case .failure:
                                iconFallback
                            default:
                                ProgressView().tint(EcrinColor.gold)
                            }
                        }
                    } else {
                        iconFallback
                    }
                }
                .frame(height: 130)
                .clipped()

                // Info
                VStack(alignment: .leading, spacing: EcrinSpacing.xs) {
                    Text(item.name)
                        .font(EcrinFont.cardTitle)
                        .foregroundStyle(EcrinColor.textPrimary)
                        .lineLimit(1)

                    Text(item.material)
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textMuted)
                        .lineLimit(2)
                        .lineSpacing(2)

                    Spacer(minLength: EcrinSpacing.sm)

                    // Action row
                    HStack(spacing: EcrinSpacing.sm) {
                        // Try-on button (ghost)
                        Button(action: onTryOn) {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10))
                                Text(L10n.LookOfDay.tryButton)
                                    .font(EcrinFont.cta)
                                    .kerning(1)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .foregroundStyle(EcrinColor.gold)
                            .padding(.horizontal, EcrinSpacing.sm)
                            .padding(.vertical, EcrinSpacing.xs)
                            .overlay {
                                Capsule().strokeBorder(EcrinColor.gold.opacity(0.45), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)

                        // Buy button (gold)
                        Button(action: onBuy) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10, weight: .semibold))
                                Text(L10n.PartnerUI.buy)
                                    .font(EcrinFont.cta)
                                    .kerning(1)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .foregroundStyle(EcrinColor.background)
                            .padding(.horizontal, EcrinSpacing.sm)
                            .padding(.vertical, EcrinSpacing.xs)
                            .background(EcrinColor.gold)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(EcrinSpacing.md)
            }
        }
        .scaleEffect(isPressed ? 0.97 : 1)
        .animation(EcrinAnimation.springSnap, value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: 50) {} onPressingChanged: { pressing in
            isPressed = pressing
        }
    }
}

// MARK: - Shimmer modifier

private extension View {
    func shimmer() -> some View {
        self.modifier(ShimmerModifier())
    }
}

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, EcrinColor.gold.opacity(0.07), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: geo.size.width * phase)
                    .allowsHitTesting(false)
                }
                .clipped()
            )
            .onAppear {
                withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}
