import SwiftUI
import PhotosUI

// MARK: - SkinTone Advisor Main View

struct SkinToneAdvisorView: View {
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var pickedImage: UIImage?
    @State private var profile: SkinToneProfile?
    @State private var isAnalyzing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showResult = false
    @State private var headerVisible = false

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            // Ambient glow
            EcrinColor.gold.opacity(0.04)
                .clipShape(Ellipse())
                .frame(width: 400, height: 200)
                .blur(radius: 60)
                .offset(y: -200)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection
                        .padding(.top, 8)

                    if let profile, showResult {
                        resultSection(profile)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        analysisPromptSection
                    }

                    Spacer(minLength: EcrinSpacing.xxl)
                }
                .padding(.horizontal, EcrinSpacing.lg)
            }
        }
        .photosPicker(
            isPresented: Binding(
                get: { false },
                set: { _ in }
            ),
            selection: $selectedPhoto,
            matching: .images
        )
        .onChange(of: selectedPhoto) { _, item in
            Task { await loadAndAnalyze(item) }
        }
        .alert("Analyse impossible", isPresented: $showError) {
            Button(L10n.SkinToneUI.okay) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear { headerVisible = true }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.SkinToneUI.advisor)
                        .font(EcrinFont.label)
                        .kerning(3)
                        .foregroundStyle(EcrinColor.gold)
                        .opacity(headerVisible ? 1 : 0)
                        .offset(x: headerVisible ? 0 : -12)
                        .animation(EcrinAnimation.easeSlide, value: headerVisible)

                    Text(L10n.SkinToneUI.skinAndMetals)
                        .font(EcrinFont.sectionHead)
                        .foregroundStyle(EcrinColor.textPrimary)
                        .opacity(headerVisible ? 1 : 0)
                        .offset(x: headerVisible ? 0 : -12)
                        .animation(EcrinAnimation.easeSlide.delay(0.07), value: headerVisible)
                }
                Spacer()
                Image(systemName: "wand.and.sparkles")
                    .font(.system(size: 22, weight: .thin))
                    .foregroundStyle(EcrinColor.gold.opacity(0.6))
            }
            .padding(.bottom, EcrinSpacing.lg)
        }
    }

    // MARK: - Prompt Section (before analysis)

    private var analysisPromptSection: some View {
        VStack(spacing: EcrinSpacing.xl) {
            // Hero illustration zone
            GlassCard(cornerRadius: 24) {
                VStack(spacing: EcrinSpacing.lg) {
                    // Decorative rings
                    ZStack {
                        ForEach(0..<3) { i in
                            Circle()
                                .strokeBorder(EcrinColor.gold.opacity(0.12 - Double(i) * 0.03), lineWidth: 1)
                                .frame(width: CGFloat(80 + i * 36), height: CGFloat(80 + i * 36))
                        }
                        Image(systemName: "person.and.arrow.left.and.arrow.right")
                            .font(.system(size: 32, weight: .thin))
                            .foregroundStyle(EcrinColor.gold.opacity(0.6))
                    }
                    .frame(height: 160)

                    VStack(spacing: EcrinSpacing.sm) {
                        Text(L10n.SkinToneUI.discoverPerfectMetal)
                            .font(EcrinFont.serif(26, weight: .light))
                            .foregroundStyle(EcrinColor.textPrimary)
                            .multilineTextAlignment(.center)

                        Text(L10n.SkinToneUI.aiAnalysisIntro)
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(5)
                            .padding(.horizontal, EcrinSpacing.md)
                    }

                    PhotosPicker(
                        selection: $selectedPhoto,
                        matching: .images
                    ) {
                        HStack(spacing: EcrinSpacing.sm) {
                            if isAnalyzing {
                                ProgressView()
                                    .tint(EcrinColor.background)
                                    .scaleEffect(0.8)
                                Text(L10n.JewelryDetectionUI.analyzing)
                                    .font(EcrinFont.cta)
                                    .kerning(1.5)
                                    .foregroundStyle(EcrinColor.background)
                            } else {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(EcrinColor.background)
                                Text(L10n.SkinToneUI.analyzeMyPhoto)
                                    .font(EcrinFont.cta)
                                    .kerning(2)
                                    .foregroundStyle(EcrinColor.background)
                            }
                        }
                        .padding(.horizontal, EcrinSpacing.xl)
                        .padding(.vertical, EcrinSpacing.md)
                        .background(isAnalyzing ? EcrinColor.gold.opacity(0.6) : EcrinColor.gold)
                        .clipShape(Capsule())
                    }
                    .disabled(isAnalyzing)
                    .padding(.bottom, EcrinSpacing.lg)
                }
                .padding(EcrinSpacing.xl)
            }

            // Feature highlights
            HStack(spacing: EcrinSpacing.md) {
                FeatureChip(icon: "eye.fill", text: "Analyse IA")
                FeatureChip(icon: "sparkles", text: "Personnalisé")
                FeatureChip(icon: "lock.shield.fill", text: "Privé")
            }
        }
        .padding(.top, EcrinSpacing.sm)
    }

    // MARK: - Result Section

    private func resultSection(_ profile: SkinToneProfile) -> some View {
        VStack(spacing: EcrinSpacing.xl) {

            // Undertone Badge + photo preview
            undertoneHeroCard(profile)

            // Depth description
            depthCard(profile)

            // Metal podium
            VStack(alignment: .leading, spacing: EcrinSpacing.md) {
                SectionDivider(label: "VOS MÉTAUX PARFAITS")
                MetalPodium(recommendations: profile.recommendedMetals)
            }

            // Avoid metals (if any)
            if !profile.avoidMetals.isEmpty {
                avoidSection(profile.avoidMetals)
            }

            // Power stones
            powerStonesSection(profile.powerStones)

            // CTA
            ctaSection

            // Re-analyze button
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                    Text(L10n.SkinToneUI.newPhoto)
                        .font(EcrinFont.caption)
                        .kerning(1)
                }
                .foregroundStyle(EcrinColor.textSecondary)
                .padding(.vertical, EcrinSpacing.sm)
            }
            .padding(.bottom, EcrinSpacing.xl)
        }
        .padding(.top, EcrinSpacing.sm)
    }

    // MARK: - Result Sub-sections

    private func undertoneHeroCard(_ profile: SkinToneProfile) -> some View {
        GlassCard(cornerRadius: 24) {
            VStack(spacing: EcrinSpacing.md) {
                HStack(spacing: EcrinSpacing.md) {
                    // Photo thumbnail
                    if let img = pickedImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 72, height: 72)
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(EcrinColor.gold.opacity(0.4), lineWidth: 1.5))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            // Color dot
                            Circle()
                                .fill(Color(hex: profile.undertoneColor))
                                .frame(width: 10, height: 10)
                            Text("TEINT \(profile.undertoneLabel.uppercased())")
                                .font(EcrinFont.label)
                                .kerning(2)
                                .foregroundStyle(Color(hex: profile.undertoneColor))
                        }

                        Text(profile.depth.rawValue)
                            .font(EcrinFont.cardTitle)
                            .foregroundStyle(EcrinColor.textPrimary)

                        Text(profile.depth.poeticDescription)
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.textSecondary)
                            .lineSpacing(4)
                    }
                }

                Divider().background(EcrinColor.glassStroke)

                // Undertone description
                Text(profile.undertoneDescription)
                    .font(EcrinFont.serif(15, weight: .light))
                    .italic()
                    .foregroundStyle(EcrinColor.ivory.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
            }
            .padding(EcrinSpacing.lg)
        }
    }

    private func depthCard(_ profile: SkinToneProfile) -> some View {
        EmptyView() // depth info is embedded in undertoneHeroCard
    }

    private func avoidSection(_ metals: [String]) -> some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.md) {
            SectionDivider(label: "À ÉVITER")

            GlassCard(cornerRadius: 16) {
                VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.red.opacity(0.6))
                        Text(L10n.SkinToneUI.metalsToAvoid)
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.textSecondary)
                    }
                    FlowLayout(spacing: EcrinSpacing.sm) {
                        ForEach(metals, id: \.self) { metal in
                            Text(metal)
                                .font(EcrinFont.caption)
                                .foregroundStyle(Color.red.opacity(0.7))
                                .padding(.horizontal, EcrinSpacing.md)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.06))
                                .clipShape(Capsule())
                                .overlay(Capsule().strokeBorder(Color.red.opacity(0.15), lineWidth: 0.5))
                        }
                    }
                }
                .padding(EcrinSpacing.md)
            }
        }
    }

    private func powerStonesSection(_ stones: [String]) -> some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.md) {
            SectionDivider(label: "PIERRES QUI VOUS SUBLIMENT")

            FlowLayout(spacing: EcrinSpacing.sm) {
                ForEach(stones, id: \.self) { stone in
                    StoneChip(name: stone)
                }
            }
        }
    }

    private var ctaSection: some View {
        VStack(spacing: EcrinSpacing.md) {
            GoldButton(title: L10n.SkinToneUI.discoverPerfectJewels) {
                // Navigate to boutique filtered by top metal
            }

            Text(L10n.SkinToneUI.filteredByProfile)
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textMuted)
        }
    }

    // MARK: - Data Loading

    private func loadAndAnalyze(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        isAnalyzing = true
        showResult = false

        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                pickedImage = image
                let result = try await SkinToneAnalyzer.analyze(image)
                withAnimation(EcrinAnimation.glassReveal) {
                    profile    = result
                    showResult = true
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            showError    = true
        }

        isAnalyzing = false
    }
}

// MARK: - Supporting Views

private struct SectionDivider: View {
    let label: String

    var body: some View {
        HStack(spacing: EcrinSpacing.sm) {
            Rectangle()
                .fill(EcrinColor.glassStroke)
                .frame(height: 0.5)
            Text(label)
                .font(EcrinFont.label)
                .kerning(2)
                .foregroundStyle(EcrinColor.textMuted)
                .fixedSize()
            Rectangle()
                .fill(EcrinColor.glassStroke)
                .frame(height: 0.5)
        }
    }
}

private struct StoneChip: View {
    let name: String
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(stoneColor)
                .frame(width: 7, height: 7)
            Text(name)
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textPrimary)
        }
        .padding(.horizontal, EcrinSpacing.md)
        .padding(.vertical, 7)
        .background(stoneColor.opacity(0.08))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(stoneColor.opacity(0.2), lineWidth: 0.5))
        .scaleEffect(appeared ? 1 : 0.7)
        .opacity(appeared ? 1 : 0)
        .animation(EcrinAnimation.springBounce, value: appeared)
        .onAppear { appeared = true }
    }

    private var stoneColor: Color {
        switch name {
        case "Diamant":           return .white
        case "Rubis":             return Color(hex: "#E11D48")
        case "Saphir", "Saphir clair", "Lapis-lazuli": return Color(hex: "#1D4ED8")
        case "Émeraude":          return Color(hex: "#16A34A")
        case "Ambre":             return Color(hex: "#D97706")
        case "Citrine", "Topaze fumée": return Color(hex: "#CA8A04")
        case "Corail":            return Color(hex: "#F97316")
        case "Aigue-marine":      return Color(hex: "#06B6D4")
        case "Améthyste", "Tanzanite": return Color(hex: "#7C3AED")
        case "Perle", "Opale blanche", "Opale de feu": return Color(hex: "#F1F5F9")
        case "Grenat":            return Color(hex: "#9F1239")
        case "Tourmaline rose":   return Color(hex: "#EC4899")
        default:                  return EcrinColor.gold
        }
    }
}

private struct FeatureChip: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(EcrinColor.gold.opacity(0.7))
            Text(text)
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, EcrinSpacing.md)
        .background(EcrinColor.glassFill)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
        )
    }
}

// FlowLayout is defined in Sources/Core/Design/FlowLayout.swift

#Preview {
    NavigationStack {
        SkinToneAdvisorView()
    }
}
