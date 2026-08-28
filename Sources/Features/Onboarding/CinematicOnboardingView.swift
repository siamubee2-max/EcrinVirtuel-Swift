import SwiftUI

// MARK: - Cinematic Onboarding (4 screens)

struct CinematicOnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var currentPage: Int = 0
    @State private var sliderInteracted = false

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            TabView(selection: $currentPage) {
                SplashScreen()
                    .tag(0)
                BeforeAfterScreen(interacted: $sliderInteracted, onNext: advance)
                    .tag(1)
                CategoryGridScreen(onNext: advance)
                    .tag(2)
                CTAScreen()
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(EcrinAnimation.easeSlide, value: currentPage)
            .task(id: currentPage) {
                guard currentPage == 0 else { return }
                try? await Task.sleep(for: .seconds(1.5))
                withAnimation(EcrinAnimation.easeSlide) {
                    currentPage = 1
                }
            }

            // Page dots (screens 1–3 only)
            if currentPage > 0 {
                VStack {
                    Spacer()
                    pageDots
                        .padding(.bottom, 36)
                }
            }

            // Skip button (screens 1 and 2)
            if currentPage == 1 || currentPage == 2 {
                VStack {
                    HStack {
                        Spacer()
                        Button(L10n.OnboardingUI.dismiss) {
                            withAnimation(EcrinAnimation.easeSlide) {
                                currentPage = 3
                            }
                        }
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textMuted)
                        .padding(.top, 60)
                        .padding(.trailing, EcrinSpacing.md)
                    }
                    Spacer()
                }
            }
        }
    }

    private func advance() {
        withAnimation(EcrinAnimation.easeSlide) {
            currentPage = min(currentPage + 1, 3)
        }
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(1..<4) { i in
                if i == currentPage {
                    Capsule()
                        .fill(EcrinColor.gold)
                        .frame(width: 20, height: 6)
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .animation(EcrinAnimation.springSnap, value: currentPage)
    }
}

// MARK: - Screen 0: Splash

private struct SplashScreen: View {
    @State private var progressWidth: CGFloat = 0
    @State private var visible = false

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            // Radial gold glow
            RadialGradient(
                colors: [EcrinColor.gold.opacity(0.18), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 280
            )
            .ignoresSafeArea()

            // Particles
            WeddingParticlesCanvas()
                .ignoresSafeArea()

            VStack(spacing: EcrinSpacing.md) {
                Text("✦")
                    .font(EcrinFont.serif(24))
                    .foregroundStyle(EcrinColor.gold)

                Text(L10n.OnboardingUI.brandName)
                    .font(EcrinFont.label)
                    .kerning(4)
                    .foregroundStyle(EcrinColor.gold)
            }
            .opacity(visible ? 1 : 0)
            .scaleEffect(visible ? 1 : 0.92)
            .animation(EcrinAnimation.glassReveal.delay(0.15), value: visible)

            // Progress bar at bottom
            VStack {
                Spacer()
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(EcrinColor.gold.opacity(0.15))
                            .frame(height: 1.5)
                        Rectangle()
                            .fill(EcrinColor.gold)
                            .frame(width: progressWidth * geo.size.width, height: 1.5)
                    }
                }
                .frame(height: 1.5)
                .padding(.horizontal, EcrinSpacing.xxl)
                .padding(.bottom, 56)
            }
        }
        .onAppear {
            visible = true
            withAnimation(.linear(duration: 1.4)) {
                progressWidth = 1.0
            }
        }
    }
}

// MARK: - Screen 1: Before/After

private struct BeforeAfterScreen: View {
    @Binding var interacted: Bool
    let onNext: () -> Void
    @State private var showNextButton = false

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            VStack(spacing: EcrinSpacing.lg) {
                Spacer().frame(height: EcrinSpacing.xxl)

                BeforeAfterSliderView {
                    // BEFORE: person silhouette
                    ZStack {
                        LinearGradient(
                            colors: [Color(hex: "#1A1A1A"), Color(hex: "#111111")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        VStack(spacing: EcrinSpacing.sm) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 72))
                                .foregroundStyle(EcrinColor.textMuted)
                            Text(L10n.OnboardingUI.withoutJewel)
                                .font(EcrinFont.caption)
                                .foregroundStyle(EcrinColor.textMuted)
                        }
                    }
                } afterContent: {
                    // AFTER: jewelry sparkle
                    ZStack {
                        LinearGradient(
                            colors: [Color(hex: "#1A1200"), Color(hex: "#0D0D00")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        // Gold glow behind icon
                        Circle()
                            .fill(EcrinColor.gold.opacity(0.15))
                            .frame(width: 160, height: 160)
                            .blur(radius: 40)
                        VStack(spacing: EcrinSpacing.sm) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [EcrinColor.goldLight, EcrinColor.gold],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                Image(systemName: "diamond.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(EcrinColor.background)
                            }
                            Text(L10n.OnboardingUI.withAiJewel)
                                .font(EcrinFont.caption)
                                .foregroundStyle(EcrinColor.gold)
                        }
                    }
                    .onTapGesture { interacted = true }
                }
                .frame(height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, EcrinSpacing.md)
                .simultaneousGesture(DragGesture(minimumDistance: 1).onChanged { _ in interacted = true })

                VStack(spacing: EcrinSpacing.xs) {
                    Text(L10n.OnboardingUI.tryBeforeYouBuy)
                        .font(EcrinFont.cardTitle)
                        .foregroundStyle(EcrinColor.textPrimary)
                    Text(L10n.OnboardingUI.aiEightSecondsSwipe)
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textMuted)
                }
                .padding(.horizontal, EcrinSpacing.md)

                if showNextButton {
                    Button(L10n.OnboardingUI.nextCta) { onNext() }
                        .font(EcrinFont.cta)
                        .kerning(1.5)
                        .foregroundStyle(EcrinColor.gold)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer()
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(3))
            if !interacted {
                onNext()
            } else {
                withAnimation(EcrinAnimation.glassReveal) {
                    showNextButton = true
                }
            }
        }
    }
}

// MARK: - Screen 2: Category Grid

private struct CategoryGridScreen: View {
    let onNext: () -> Void

    private let categories: [(icon: String, label: String)] = [
        ("💍", "Bagues"),
        ("📿", "Colliers"),
        ("💎", "Boucles d'oreilles"),
        ("⌚", "Montres")
    ]

    @State private var appeared: [Bool] = [false, false, false, false]

    let columns = [GridItem(.flexible(), spacing: EcrinSpacing.md),
                   GridItem(.flexible(), spacing: EcrinSpacing.md)]

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            VStack(spacing: EcrinSpacing.lg) {
                Spacer().frame(height: EcrinSpacing.xxl + EcrinSpacing.md)

                Text(L10n.OnboardingUI.allJewelryOnYou)
                    .font(EcrinFont.sectionHead)
                    .foregroundStyle(EcrinColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, EcrinSpacing.md)

                LazyVGrid(columns: columns, spacing: EcrinSpacing.md) {
                    ForEach(categories.indices, id: \.self) { i in
                        let cat = categories[i]
                        RoundedRectangle(cornerRadius: 16)
                            .fill(EcrinColor.glassFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(EcrinColor.glassStroke, lineWidth: 1)
                            )
                            .overlay(
                                VStack(spacing: EcrinSpacing.sm) {
                                    Text(cat.icon)
                                        .font(.system(size: 32))
                                    Text(cat.label)
                                        .font(EcrinFont.caption)
                                        .foregroundStyle(EcrinColor.gold)
                                        .multilineTextAlignment(.center)
                                }
                            )
                            .frame(height: 110)
                            .opacity(appeared[i] ? 1 : 0)
                            .offset(y: appeared[i] ? 0 : 16)
                            .animation(EcrinAnimation.glassReveal.delay(Double(i) * 0.1), value: appeared[i])
                    }
                }
                .padding(.horizontal, EcrinSpacing.md)

                Spacer()
            }
        }
        .onAppear {
            for i in categories.indices {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                    appeared[i] = true
                }
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(2.5))
            onNext()
        }
    }
}

// MARK: - Screen 3: CTA

private struct CTAScreen: View {
    @Environment(AppState.self) private var appState
    @State private var visible = false
    @State private var isStartingGuest = false

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            // Radial gold glow
            RadialGradient(
                colors: [EcrinColor.gold.opacity(0.2), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 300
            )
            .ignoresSafeArea()

            // Particles
            WeddingParticlesCanvas()
                .ignoresSafeArea()

            VStack(spacing: EcrinSpacing.lg) {
                Spacer()

                Image(systemName: "sparkles")
                    .font(.system(size: 36))
                    .foregroundStyle(EcrinColor.gold)

                Text(L10n.OnboardingUI.readyToTry)
                    .font(EcrinFont.label)
                    .kerning(3)
                    .foregroundStyle(EcrinColor.gold)

                Text(L10n.OnboardingUI.freeTrialsNoCard)
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textMuted)

                Spacer().frame(height: EcrinSpacing.sm)

                GoldButton(title: L10n.OnboardingUI.tryNowCta) {
                    startGuestSession()
                }
                .disabled(isStartingGuest)
                .opacity(isStartingGuest ? 0.6 : 1)

                Button(L10n.OnboardingUI.signIn) {
                    appState.markOnboardingComplete()
                }
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textMuted)
                .padding(.top, EcrinSpacing.xs)

                // Accord CGU/Confidentialité — s'applique aussi au parcours invité
                // (guideline App Store 1.2 : accès à l'UGC = acceptation de l'EULA).
                VStack(spacing: 4) {
                    Text("En continuant, vous acceptez nos")
                        .font(.system(size: 10))
                        .foregroundStyle(EcrinColor.textMuted)
                    HStack(spacing: 4) {
                        Link("CGU", destination: URL(string: "https://inferencevision.store/ecrin/terms")!)
                        Text("·").foregroundStyle(EcrinColor.textMuted)
                        Link("Confidentialité", destination: URL(string: "https://inferencevision.store/ecrin/privacy")!)
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(EcrinColor.gold.opacity(0.7))
                }
                .padding(.top, EcrinSpacing.sm)

                Spacer()
            }
            .opacity(visible ? 1 : 0)
            .scaleEffect(visible ? 1 : 0.95)
            .animation(EcrinAnimation.glassReveal, value: visible)
        }
        .onAppear { visible = true }
    }

    /// « 3 essais offerts · Aucune carte requise » : session anonyme silencieuse
    /// et entrée directe dans l'app. En cas d'échec (hors-ligne…), on retombe
    /// sur l'écran de connexion classique.
    private func startGuestSession() {
        guard !isStartingGuest else { return }
        isStartingGuest = true
        Task {
            defer { isStartingGuest = false }
            if let session = await GenerationAuthGate.currentOrAnonymousSession() {
                appState.signInAsGuest(user: User(
                    id: session.user.id,
                    email: session.user.email ?? "invitee@anonyme.ecrin.local",
                    displayName: "Invitée"
                ))
            } else {
                appState.markOnboardingComplete()
            }
        }
    }
}


