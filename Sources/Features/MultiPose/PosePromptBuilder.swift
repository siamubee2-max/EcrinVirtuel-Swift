import Foundation

// MARK: - PosePromptBuilder
// Combine le prompt enrichi d'un item avec les instructions de pose et de lumière.

final class PosePromptBuilder {

    /// Construit le prompt final en injectant la pose dans le prompt enrichi de base.
    ///
    /// - Parameters:
    ///   - basePrompt: Prompt construit par EnrichedPromptBuilder (sujet + item + transitions + lumière + qualité)
    ///   - pose: PoseVariant sélectionné
    ///   - bodyContext: Contexte corporel extrait de la photo utilisateur
    /// - Returns: Prompt final prêt à être envoyé à ImageGenerationService
    static func build(
        basePrompt: String,
        pose: PoseVariant,
        bodyContext: BodyContext
    ) -> String {
        let poseBlock = buildPoseBlock(pose: pose, bodyContext: bodyContext)
        // Pose EN TÊTE : noyée en fin de prompt, la directive de pose était
        // ignorée par le modèle (3 rendus identiques de face).
        return [poseBlock, basePrompt]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    /// Construit un prompt complet depuis un QuickTryOnItem + pose (sans basePrompt pré-construit).
    static func buildFromItem(
        item: QuickTryOnItem,
        mode: QuickTryOnMode,
        pose: PoseVariant,
        bodyContext: BodyContext
    ) -> String {
        let base = EnrichedPromptBuilder.build(for: item, mode: mode, bodyContext: bodyContext)
        return build(basePrompt: base, pose: pose, bodyContext: bodyContext)
    }

    /// Construit un prompt complet depuis une liste d'articles (look complet) + pose.
    /// Utilise EnrichedPromptBuilder.buildItems pour intégrer tous les vêtements du look.
    static func buildFromItems(
        items: [QuickTryOnItem],
        mode: QuickTryOnMode,
        pose: PoseVariant,
        bodyContext: BodyContext
    ) -> String {
        let base = EnrichedPromptBuilder.buildItems(items, mode: mode, bodyContext: bodyContext)
        return build(basePrompt: base, pose: pose, bodyContext: bodyContext)
    }

    // MARK: - Private helpers

    private static func buildPoseBlock(pose: PoseVariant, bodyContext: BodyContext) -> String {
        var lines: [String] = []

        lines.append("POSE DIRECTIVE (HIGHEST PRIORITY — follow this exactly): \(pose.promptSuffix).")
        // Full-body uniquement si la pose le demande — forcer « head to toe »
        // sur un gros plan bijou faisait dézoomer le modèle en pied.
        let wantsFullBody = pose.promptSuffix.lowercased().contains("full body")
        if wantsFullBody {
            lines.append("FRAMING: Vertical \(GenerationAspectRatio.tryOn) portrait. FULL-BODY shot — the entire person from the top of the head down to the feet must be fully visible and centered, with comfortable empty margin above the head and below the feet. Never crop or cut off the head, hands, or feet at the frame edges.")
        } else {
            lines.append("FRAMING: Vertical \(GenerationAspectRatio.tryOn) portrait. Frame the shot exactly as the POSE DIRECTIVE describes — a close-up stays a close-up.")
        }

        // Instruction identité — critique pour la cohérence multi-vue
        lines.append("Maintain exact identity from reference: skin tone \(bodyContext.skinHex), same face, same hair, same body proportions.")

        // Éclairage cohérent avec la source
        let lightingMatch = "LIGHTING CONSISTENCY: Match the \(bodyContext.lightingType.rawValue) \(bodyContext.lightingDirection.description) detected in the reference photo."
        lines.append(lightingMatch)

        // Indication mouvement si pose dynamique
        if pose.isMotion {
            lines.append("Motion energy is present — capture the decisive mid-action moment. Avoid blur. Preserve garment drape and detail clarity.")
        }

        return lines.joined(separator: " ")
    }
}
