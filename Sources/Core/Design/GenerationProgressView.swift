import SwiftUI

/// Overlay de progression pour les générations longues (jusqu'à ~143 s en pire cas).
///
/// Remplace le spinner nu : anneau de progression asymptotique + compteur de temps
/// écoulé + étape courante + estimation rassurante. La progression n'atteint jamais
/// 100 % avant la fin réelle (asymptote à 95 %) — on évite la fausse promesse
/// « terminé » alors que le serveur travaille encore.
struct GenerationProgressView: View {

    /// Estimation haute (secondes) affichée à l'utilisateur.
    var estimateSeconds: Int = 120

    /// Étapes affichées séquentiellement selon la fraction de temps écoulée.
    var stages: [String] = ["Analyse de la photo", "Génération du rendu", "Finalisation des détails"]

    @State private var start = Date()

    var body: some View {
        TimelineView(.periodic(from: start, by: 0.5)) { context in
            content(elapsed: max(0, context.date.timeIntervalSince(start)))
        }
    }

    @ViewBuilder
    private func content(elapsed: TimeInterval) -> some View {
        let fraction   = min(0.95, elapsed / Double(max(1, estimateSeconds)))
        let stageIndex = min(stages.count - 1, Int(fraction * Double(stages.count)))

        VStack(spacing: EcrinSpacing.md) {
            ZStack {
                Circle()
                    .stroke(EcrinColor.glassStroke, lineWidth: 3)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(EcrinColor.gold, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: fraction)
                Text("\(Int(elapsed))s")
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textPrimary)
                    .monospacedDigit()
            }
            .frame(width: 68, height: 68)

            Text(stages[stageIndex])
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textPrimary)
                .contentTransition(.opacity)
                .animation(.easeInOut, value: stageIndex)

            Text("Estimation ~\(estimateSeconds) s · gardez l'app ouverte")
                .font(EcrinFont.label)
                .foregroundStyle(EcrinColor.textMuted)
        }
        .padding(EcrinSpacing.lg)
        .multilineTextAlignment(.center)
    }
}
