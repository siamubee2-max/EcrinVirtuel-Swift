import SwiftUI

// MARK: - ProportionGuideView — Guide de cadrage photo affiché la première fois

struct ProportionGuideView: View {

    let onDismiss: () -> Void

    @State private var currentTip: Int = 0

    private static let hasSeenKey = "ecrin.hasSeenProportionGuide.v1"

    // MARK: - Données des conseils

    private let tips: [PhotoTip] = [
        PhotoTip(
            icon: "person.crop.rectangle",
            color: .blue,
            title: "Cadrage complet",
            description: "Pour un essayage vêtement complet, photographiez-vous en pied : de la tête aux chevilles. Gardez au moins 10 cm de marge en bas.",
            goodExample: PhotoExample(icon: "checkmark.circle.fill", color: .green, label: "Tête + pieds visibles, fond neutre"),
            badExample: PhotoExample(icon: "xmark.circle.fill", color: .red, label: "Image trop serrée ou coupée aux genoux")
        ),
        PhotoTip(
            icon: "sun.max.fill",
            color: .yellow,
            title: "Lumière naturelle",
            description: "Placez-vous face à une fenêtre pour un éclairage uniforme. Evitez le contre-jour, les plafonniers uniques et les pièces très sombres.",
            goodExample: PhotoExample(icon: "checkmark.circle.fill", color: .green, label: "Lumière douce et uniforme, ombres légères"),
            badExample: PhotoExample(icon: "xmark.circle.fill", color: .red, label: "Contre-jour ou lumière très dure")
        ),
        PhotoTip(
            icon: "rectangle.dashed",
            color: .purple,
            title: "Fond simple",
            description: "Un mur blanc, beige ou gris permet à l'IA de mieux isoler votre silhouette. Les fonds chargés (plantes, meubles) réduisent la précision.",
            goodExample: PhotoExample(icon: "checkmark.circle.fill", color: .green, label: "Fond uni, mur ou porte"),
            badExample: PhotoExample(icon: "xmark.circle.fill", color: .red, label: "Fond avec beaucoup d'éléments")
        ),
        PhotoTip(
            icon: "arrow.up.and.down.and.sparkles",
            color: .orange,
            title: "Distance et angle",
            description: "Idéalement, placez le téléphone sur un support à hauteur de poitrine, à 2-3 mètres de vous, en orientation portrait. Evitez les angles plongeants.",
            goodExample: PhotoExample(icon: "checkmark.circle.fill", color: .green, label: "Hauteur de poitrine, portrait, 2-3m"),
            badExample: PhotoExample(icon: "xmark.circle.fill", color: .red, label: "Angle trop bas ou trop haut")
        ),
        PhotoTip(
            icon: "figure.stand",
            color: .teal,
            title: "Posture naturelle",
            description: "Tenez-vous droit, bras légèrement écartés du corps. Evitez de croiser les bras — l'IA a besoin de voir la silhouette complète pour un résultat précis.",
            goodExample: PhotoExample(icon: "checkmark.circle.fill", color: .green, label: "Posture droite, bras visibles"),
            badExample: PhotoExample(icon: "xmark.circle.fill", color: .red, label: "Bras croisés, posture penchée")
        )
    ]

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // Header
                headerView

                // Carrousel de conseils
                TabView(selection: $currentTip) {
                    ForEach(tips.indices, id: \.self) { index in
                        TipCard(tip: tips[index])
                            .tag(index)
                            .padding(.horizontal, 20)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 340)

                // Indicateurs de page
                pageIndicators

                // Boutons de navigation
                navigationButtons

            }
            .padding(.bottom, 30)
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.trailing, 20)
                .padding(.top, 16)
            }

            Image(systemName: "camera.viewfinder")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(
                    LinearGradient(colors: [.white, Color(hex: "#CA8A04")],
                                   startPoint: .top, endPoint: .bottom)
                )
                .padding(.bottom, 4)

            Text(L10n.QuickTryOnUI.photoTips)
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text(L10n.QuickTryOnUI.forPreciseTryOn)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.bottom, 12)
        }
    }

    private var pageIndicators: some View {
        HStack(spacing: 8) {
            ForEach(tips.indices, id: \.self) { index in
                Capsule()
                    .fill(index == currentTip ? Color(hex: "#CA8A04") : .white.opacity(0.35))
                    .frame(width: index == currentTip ? 20 : 6, height: 6)
                    .animation(.spring(response: 0.3), value: currentTip)
            }
        }
        .padding(.top, 12)
    }

    private var navigationButtons: some View {
        HStack(spacing: 16) {
            if currentTip > 0 {
                Button {
                    withAnimation(.spring(response: 0.35)) {
                        currentTip -= 1
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Précédent")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.white.opacity(0.12), in: Capsule())
                }
            }

            Spacer()

            if currentTip < tips.count - 1 {
                Button {
                    withAnimation(.spring(response: 0.35)) {
                        currentTip += 1
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(L10n.Common.next)
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#CA8A04"), in: Capsule())
                }
            } else {
                // Dernier conseil → bouton "Compris"
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                        Text(L10n.QuickTryOnUI.gotIt)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#CA8A04"), in: Capsule())
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    // MARK: - Actions

    private func dismiss() {
        UserDefaults.standard.set(true, forKey: Self.hasSeenKey)
        onDismiss()
    }

    // MARK: - Static helper

    /// Retourne true si le guide doit être affiché (première utilisation)
    static var shouldShow: Bool {
        !UserDefaults.standard.bool(forKey: hasSeenKey)
    }

    /// Force l'affichage (reset — utile pour les tests ou depuis les Réglages)
    static func resetDisplayState() {
        UserDefaults.standard.removeObject(forKey: hasSeenKey)
    }
}

// MARK: - TipCard

private struct TipCard: View {
    let tip: PhotoTip

    var body: some View {
        VStack(spacing: 0) {
            // Icône + titre
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(tip.color.opacity(0.18))
                        .frame(width: 64, height: 64)
                    Image(systemName: tip.icon)
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(tip.color)
                }

                Text(tip.title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(tip.description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)

            Divider()
                .background(.white.opacity(0.15))
                .padding(.vertical, 14)

            // Exemples bon/mauvais
            HStack(spacing: 12) {
                ExampleBadge(example: tip.goodExample)
                ExampleBadge(example: tip.badExample)
            }
        }
        .padding(20)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - ExampleBadge

private struct ExampleBadge: View {
    let example: PhotoExample

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: example.icon)
                .font(.callout.weight(.semibold))
                .foregroundStyle(example.color)
                .frame(width: 20)
            Text(example.label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(example.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Data models

private struct PhotoTip {
    let icon: String
    let color: Color
    let title: String
    let description: String
    let goodExample: PhotoExample
    let badExample: PhotoExample
}

private struct PhotoExample {
    let icon: String
    let color: Color
    let label: String
}

// MARK: - Preview

#if DEBUG
#Preview {
    ProportionGuideView(onDismiss: {})
}
#endif
