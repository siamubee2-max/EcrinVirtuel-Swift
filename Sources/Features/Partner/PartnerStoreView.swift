import SwiftUI

// MARK: - PartnerStoreView

struct PartnerStoreView: View {

    @State private var viewModel = PartnerViewModel()
    @State private var selectedBrand: PartnerBrand? = nil
    @State private var showApplication = false

    var body: some View {
        NavigationStack {
            ZStack {
                EcrinColor.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        storeHeader
                            .padding(.horizontal, EcrinSpacing.lg)
                            .padding(.top, EcrinSpacing.md)

                        searchBar
                            .padding(.horizontal, EcrinSpacing.lg)
                            .padding(.top, EcrinSpacing.lg)

                        categoryFilter
                            .padding(.top, EcrinSpacing.md)

                        partnerGrid
                            .padding(.horizontal, EcrinSpacing.lg)
                            .padding(.top, EcrinSpacing.xl)

                        // CTA candidature artisan
                        artisanCTA
                            .padding(.horizontal, EcrinSpacing.lg)
                            .padding(.top, EcrinSpacing.xl)
                            .padding(.bottom, EcrinSpacing.xxl)
                    }
                }
                .refreshable { await viewModel.refreshPartners() }

                if viewModel.isLoading && viewModel.partners.isEmpty {
                    loadingOverlay
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(item: $selectedBrand) { brand in
                PartnerDetailView(brand: brand)
            }
            .task { await viewModel.loadPartners() }
            .sheet(isPresented: $showApplication) {
                PartnerApplicationView()
            }
        }
    }

    // MARK: - Header

    private var storeHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: EcrinSpacing.xs) {
                Text("NOS PARTENAIRES")
                    .font(EcrinFont.label)
                    .kerning(3)
                    .foregroundStyle(EcrinColor.gold)

                Text("Boutiques\nSélectionnées")
                    .font(EcrinFont.sectionHead)
                    .foregroundStyle(EcrinColor.textPrimary)
                    .lineSpacing(4)
            }

            Spacer()

            // Partner count badge
            GlassCard(cornerRadius: 14) {
                VStack(spacing: 2) {
                    Text("\(viewModel.partners.count)")
                        .font(EcrinFont.serif(32, weight: .light))
                        .foregroundStyle(EcrinColor.gold)
                    Text("marques")
                        .font(EcrinFont.caption)
                        .kerning(1)
                        .foregroundStyle(EcrinColor.textMuted)
                }
                .padding(.horizontal, EcrinSpacing.lg)
                .padding(.vertical, EcrinSpacing.md)
            }
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        GlassCard(cornerRadius: 14) {
            HStack(spacing: EcrinSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(EcrinColor.textMuted)

                TextField("", text: $viewModel.searchText, prompt:
                    Text("Rechercher une boutique…")
                        .foregroundStyle(EcrinColor.textMuted)
                        .font(EcrinFont.body)
                )
                .font(EcrinFont.body)
                .foregroundStyle(EcrinColor.textPrimary)
                .tint(EcrinColor.gold)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(EcrinColor.textMuted)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, EcrinSpacing.md)
            .padding(.vertical, EcrinSpacing.md)
        }
        .animation(EcrinAnimation.springSnap, value: viewModel.searchText.isEmpty)
    }

    // MARK: - Category filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: EcrinSpacing.sm) {
                // "Toutes" pill
                CategoryPill(
                    label: "Toutes",
                    icon: "square.grid.2x2",
                    isSelected: viewModel.selectedCategory == nil
                ) {
                    viewModel.selectCategory(nil)
                }

                ForEach(PartnerBrand.BrandCategory.allCases) { category in
                    CategoryPill(
                        label: category.rawValue,
                        icon: category.icon,
                        isSelected: viewModel.selectedCategory == category
                    ) {
                        viewModel.selectCategory(category)
                    }
                }
            }
            .padding(.horizontal, EcrinSpacing.lg)
        }
    }

    // MARK: - Partner grid

    @ViewBuilder
    private var partnerGrid: some View {
        if viewModel.hasResults {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: EcrinSpacing.md), GridItem(.flexible(), spacing: EcrinSpacing.md)],
                spacing: EcrinSpacing.md
            ) {
                ForEach(viewModel.filteredPartners) { brand in
                    PartnerCard(brand: brand)
                        .onTapGesture {
                            withAnimation(EcrinAnimation.springSnap) {
                                selectedBrand = brand
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.92).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
            .animation(EcrinAnimation.springSnap, value: viewModel.filteredPartners.map { $0.id })
        } else if !viewModel.isLoading {
            emptyState
                .frame(maxWidth: .infinity)
                .padding(.top, EcrinSpacing.xxl)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: EcrinSpacing.lg) {
            Image(systemName: "storefront")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(EcrinColor.textMuted)
            Text("Aucune boutique trouvée")
                .font(EcrinFont.cardTitle)
                .foregroundStyle(EcrinColor.textSecondary)
            if !viewModel.searchText.isEmpty {
                Text("Essayez un autre mot-clé")
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textMuted)
            }
        }
    }

    // MARK: - Loading overlay

    private var loadingOverlay: some View {
        VStack(spacing: EcrinSpacing.md) {
            ProgressView()
                .tint(EcrinColor.gold)
                .scaleEffect(1.4)
            Text(L10n.Common.loading)
                .font(EcrinFont.caption)
                .kerning(1.5)
                .foregroundStyle(EcrinColor.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(EcrinColor.background.opacity(0.8))
        .transition(.opacity)
    }

    // MARK: - Artisan CTA

    private var artisanCTA: some View {
        GlassCard(cornerRadius: 24) {
            VStack(spacing: EcrinSpacing.lg) {
                // Icône décorative
                ZStack {
                    Circle()
                        .fill(EcrinColor.gold.opacity(0.10))
                        .frame(width: 64, height: 64)
                    Image(systemName: "hands.and.sparkles.fill")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(EcrinColor.gold)
                }

                // Texte
                VStack(spacing: EcrinSpacing.sm) {
                    Text("Vous êtes créateur·trice ?")
                        .font(EcrinFont.cardTitle)
                        .foregroundStyle(EcrinColor.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Rejoignez L'Écrin Virtuel et faites découvrir vos bijoux artisanaux à des milliers de passionné·es. Candidature gratuite, réponse sous 72 h.")
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                // Tags catégories
                HStack(spacing: EcrinSpacing.sm) {
                    ForEach(["Artisanal", "Créateur", "Vintage"], id: \.self) { tag in
                        Text(tag)
                            .font(EcrinFont.label)
                            .kerning(0.5)
                            .foregroundStyle(EcrinColor.gold.opacity(0.85))
                            .padding(.horizontal, EcrinSpacing.sm)
                            .padding(.vertical, 5)
                            .background(EcrinColor.gold.opacity(0.10))
                            .clipShape(Capsule())
                    }
                }

                // Bouton
                Button {
                    showApplication = true
                } label: {
                    HStack(spacing: EcrinSpacing.sm) {
                        Image(systemName: "paperplane")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Postuler comme partenaire")
                            .font(EcrinFont.cta)
                            .kerning(1.5)
                    }
                    .foregroundStyle(EcrinColor.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, EcrinSpacing.md)
                    .background(EcrinColor.gold)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(EcrinSpacing.lg)
        }
    }
}

// MARK: - CategoryPill

private struct CategoryPill: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: EcrinSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .regular))
                Text(label)
                    .font(EcrinFont.cta)
                    .kerning(1)
            }
            .foregroundStyle(isSelected ? EcrinColor.background : EcrinColor.gold)
            .padding(.horizontal, EcrinSpacing.md)
            .padding(.vertical, EcrinSpacing.sm)
            .background {
                Capsule()
                    .fill(isSelected ? EcrinColor.gold : EcrinColor.glassFill)
                    .overlay {
                        if !isSelected {
                            Capsule().strokeBorder(EcrinColor.gold.opacity(0.35), lineWidth: 1)
                        }
                    }
            }
        }
        .buttonStyle(.plain)
        .animation(EcrinAnimation.springSnap, value: isSelected)
    }
}

// MARK: - PartnerCard

struct PartnerCard: View {
    let brand: PartnerBrand

    var body: some View {
        GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 0) {
                // Logo zone
                ZStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [EcrinColor.gold.opacity(0.08), EcrinColor.gold.opacity(0.02)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Logo placeholder — replace with AsyncImage when logoURL is non-nil
                    ZStack {
                        Circle()
                            .fill(EcrinColor.gold.opacity(0.12))
                            .frame(width: 52, height: 52)
                        Text(String(brand.name.prefix(2)).uppercased())
                            .font(EcrinFont.serif(20, weight: .semibold))
                            .foregroundStyle(EcrinColor.gold)
                    }
                }
                .frame(height: 90)

                // Content
                VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
                    HStack(alignment: .top) {
                        Text(brand.name)
                            .font(EcrinFont.cardTitle)
                            .foregroundStyle(EcrinColor.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Spacer(minLength: EcrinSpacing.xs)

                        if brand.isVerified {
                            VerifiedBadge()
                        }
                    }

                    Text(brand.description)
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textSecondary)
                        .lineLimit(3)
                        .lineSpacing(2)

                    Spacer(minLength: EcrinSpacing.sm)

                    HStack(spacing: EcrinSpacing.sm) {
                        // Category chip
                        Label(brand.category.rawValue, systemImage: brand.category.icon)
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.gold.opacity(0.8))
                            .lineLimit(1)

                        Spacer()

                        // Country
                        Text(brand.country)
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.textMuted)
                    }
                }
                .padding(EcrinSpacing.md)
            }
        }
    }
}

// MARK: - VerifiedBadge

struct VerifiedBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 9))
            Text("VÉRIFIÉ")
                .font(EcrinFont.label)
                .kerning(0.5)
        }
        .foregroundStyle(EcrinColor.background)
        .padding(.horizontal, EcrinSpacing.sm)
        .padding(.vertical, 3)
        .background(EcrinColor.gold)
        .clipShape(Capsule())
    }
}
