import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "sparkle",
            title: "Essayez avant\nd'acheter",
            subtitle: "Visualisez chaque bijou sur vous\ngrâce à l'intelligence artificielle",
            accent: EcrinColor.gold
        ),
        OnboardingPage(
            icon: "wand.and.stars",
            title: "Votre styliste\npersonnel",
            subtitle: "L'IA analyse votre style et\nvous propose les bijoux parfaits",
            accent: Color.purple.opacity(0.8)
        ),
        OnboardingPage(
            icon: "heart.fill",
            title: "Votre dressing\nvirtuel",
            subtitle: "Sauvegardez vos looks favoris\net partagez-les avec la communauté",
            accent: EcrinColor.goldLight
        )
    ]

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            // Ambient glow
            Circle()
                .fill(EcrinColor.gold.opacity(0.08))
                .frame(width: 400)
                .blur(radius: 80)
                .offset(x: 100, y: -200)
                .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: currentPage)

            VStack(spacing: 0) {
                // Logo
                VStack(spacing: 4) {
                    Text("L'ÉCRIN VIRTUEL")
                        .font(EcrinFont.label)
                        .kerning(4)
                        .foregroundStyle(EcrinColor.gold)
                }
                .padding(.top, 60)

                Spacer()

                // Pages
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { i in
                        OnboardingPageView(page: pages[i])
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 380)

                // Page indicator
                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == currentPage ? EcrinColor.gold : EcrinColor.textMuted)
                            .frame(width: i == currentPage ? 20 : 6, height: 6)
                            .animation(EcrinAnimation.springSnap, value: currentPage)
                    }
                }
                .padding(.top, 32)

                Spacer()

                // CTA
                VStack(spacing: 16) {
                    if currentPage == pages.count - 1 {
                        GoldButton(title: "Commencer") {
                            withAnimation(EcrinAnimation.easeSlide) {
                                appState.markOnboardingComplete()
                            }
                        }
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        GoldButton(title: L10n.Common.next) {
                            withAnimation(EcrinAnimation.springSnap) {
                                currentPage += 1
                            }
                        }
                    }

                    Button("Passer") {
                        withAnimation(EcrinAnimation.easeSlide) {
                            appState.markOnboardingComplete()
                        }
                    }
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textMuted)
                }
                .animation(EcrinAnimation.springSnap, value: currentPage)
                .padding(.bottom, 50)
            }
            .padding(.horizontal, EcrinSpacing.lg)
        }
    }
}

struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
    let accent: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: EcrinSpacing.xl) {
            // Icon glass
            ZStack {
                Circle()
                    .fill(page.accent.opacity(0.12))
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)

                Image(systemName: page.icon)
                    .font(.system(size: 52, weight: .thin))
                    .foregroundStyle(page.accent)
                    .symbolEffect(.pulse)
            }

            VStack(spacing: 12) {
                Text(page.title)
                    .font(EcrinFont.sectionHead)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(EcrinColor.textPrimary)

                Text(page.subtitle)
                    .font(EcrinFont.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(EcrinColor.textSecondary)
                    .lineSpacing(4)
            }
        }
        .padding(.horizontal, EcrinSpacing.lg)
    }
}
