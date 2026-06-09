import OSLog
import SwiftUI

// MARK: - MultiPoseViewModel

@Observable
@MainActor
final class MultiPoseViewModel {

    // MARK: - PoseResult

    struct PoseResult: Identifiable {
        let id: String
        let pose: PoseVariant
        var image: UIImage?
        var state: GenerationState

        enum GenerationState {
            case waiting
            case generating
            case done
            case failed
        }
    }

    // MARK: - State

    var selectedPoses: [PoseVariant] = []
    var results: [PoseResult] = []
    var isGenerating: Bool = false
    var generatingPoseId: String? = nil
    var progress: Double = 0.0
    var errorMessage: String? = nil

    /// Modèle utilisé par défaut pour l'affichage (1 pièce = NB2).
    /// Remplacé dynamiquement par generateAll() selon le nombre d'items.
    private(set) var modelInUse: GenerationModel = .standard

    var costPerGeneration: Double { modelInUse.costUSD }

    /// Choisit automatiquement le modèle selon la complexité du look.
    /// - 2+ pièces (haut + bas + chaussures...) : NB Pro (Gemini 3 Pro Image) — gère les tenues multi-pièces
    /// - 1 pièce ou bijou : NB2 (Gemini 3.1 Flash Image) — meilleur pour identity preservation
    static func model(for itemsCount: Int) -> GenerationModel {
        itemsCount >= 2 ? .premium : .standard
    }

    /// Coût total prévisionnel — utilisable par la vue avant génération.
    func costEstimate(itemsCount: Int) -> Double {
        Double(selectedPoses.count) * Self.model(for: itemsCount).costUSD
    }

    // MARK: - Constants

    static let maxPoses = 4

    // MARK: - Services

    private let imageService = ImageGenerationService.shared

    // MARK: - Computed

    var totalCostUSD: Double {
        Double(selectedPoses.count) * costPerGeneration
    }

    var trialCount: Int {
        selectedPoses.count
    }

    var canGenerate: Bool {
        !selectedPoses.isEmpty
    }

    var isDone: Bool {
        !results.isEmpty && results.allSatisfy { $0.state == .done || $0.state == .failed }
    }

    var doneResults: [PoseResult] {
        results.filter { $0.state == .done }
    }

    // MARK: - Pose management

    func canAddPose(_ pose: PoseVariant) -> Bool {
        selectedPoses.count < Self.maxPoses && !selectedPoses.contains(pose)
    }

    func togglePose(_ pose: PoseVariant) {
        if let index = selectedPoses.firstIndex(of: pose) {
            selectedPoses.remove(at: index)
        } else if canAddPose(pose) {
            selectedPoses.append(pose)
        }
    }

    func isSelected(_ pose: PoseVariant) -> Bool {
        selectedPoses.contains(pose)
    }

    func selectionIndex(of pose: PoseVariant) -> Int? {
        selectedPoses.firstIndex(of: pose)
    }

    func reorderPoses(from source: IndexSet, to destination: Int) {
        selectedPoses.move(fromOffsets: source, toOffset: destination)
    }

    func resetSelection() {
        selectedPoses = []
        results = []
        progress = 0.0
        errorMessage = nil
        generatingPoseId = nil
    }

    // MARK: - Generation

    /// Lance la génération de toutes les poses en parallèle via TaskGroup.
    /// Accepte plusieurs articles pour générer le look complet (haut + bas + chaussures).
    /// Sélectionne automatiquement NB Pro pour les looks 2+ pièces, NB2 sinon.
    func generateAll(
        photo: UIImage,
        items: [QuickTryOnItem],
        mode: QuickTryOnMode,
        bodyContext: BodyContext
    ) async {
        guard !selectedPoses.isEmpty else { return }

        isGenerating = true
        errorMessage = nil
        progress = 0.0

        // Routage automatique du modèle selon la complexité
        let chosenModel = Self.model(for: items.count)
        modelInUse = chosenModel
        Logger(subsystem: "com.ecrin.jewelry", category: "multi-pose").debug("MultiPose generation: \(items.count) item(s) → model=\(chosenModel.rawValue, privacy: .public) ($\(chosenModel.costUSD)/img)")

        // Initialiser les résultats en état "waiting"
        results = selectedPoses.map { pose in
            PoseResult(id: pose.id, pose: pose, image: nil, state: .waiting)
        }

        let posesToGenerate = selectedPoses
        var completed = 0

        let service = imageService
        // Image produit de référence (1 seul téléchargement, réutilisé pour toutes les poses).
        let referenceData = await service.referenceData(for: items.first?.referenceImageURL)

        // Génération SÉQUENTIELLE (une pose à la fois) — fiabilité maximale.
        // gpt-image-1 (/images/edits) est lent (~25s) et rate-limité : 3 appels
        // concurrents avec image de référence faisaient échouer 2 vues sur 3.
        for pose in posesToGenerate {
            updateResultState(poseId: pose.id, state: .generating)
            generatingPoseId = pose.id

            let posePrompt = PosePromptBuilder.buildFromItems(
                items: items,
                mode: mode,
                pose: pose,
                bodyContext: bodyContext
            )

            var poseResult = PoseResult(id: pose.id, pose: pose, image: nil, state: .failed)
            let maxAttempts = 3
            for attempt in 1...maxAttempts {
                do {
                    let generated = try await service.tryOnQuick(
                        photo: photo,
                        prompt: posePrompt,
                        model: chosenModel,
                        referenceImageData: referenceData
                    )
                    poseResult = PoseResult(id: pose.id, pose: pose, image: generated, state: .done)
                    break
                } catch {
                    if attempt == maxAttempts { break }
                    // Backoff long pour laisser passer un rate-limit transitoire : 3s, puis 8s.
                    let delaySeconds = attempt == 1 ? 3.0 : 8.0
                    try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                }
            }

            completed += 1
            updateResult(poseResult)
            progress = Double(completed) / Double(posesToGenerate.count)
        }

        generatingPoseId = nil
        isGenerating = false

        let failedCount = results.filter { $0.state == .failed }.count
        if failedCount > 0 {
            errorMessage = "\(failedCount) vue\(failedCount > 1 ? "s" : "") n'ont pas pu être générées."
        }
    }

    /// Relancer la génération d'une seule pose qui a échoué.
    func retryPose(
        _ pose: PoseVariant,
        photo: UIImage,
        items: [QuickTryOnItem],
        mode: QuickTryOnMode,
        bodyContext: BodyContext
    ) async {
        updateResultState(poseId: pose.id, state: .generating)
        generatingPoseId = pose.id

        let prompt = PosePromptBuilder.buildFromItems(
            items: items,
            mode: mode,
            pose: pose,
            bodyContext: bodyContext
        )
        let model = Self.model(for: items.count)

        do {
            let referenceData = await imageService.referenceData(for: items.first?.referenceImageURL)
            let generated = try await imageService.tryOnQuick(photo: photo, prompt: prompt, model: model, referenceImageData: referenceData)
            let result = PoseResult(id: pose.id, pose: pose, image: generated, state: .done)
            updateResult(result)
        } catch {
            updateResultState(poseId: pose.id, state: .failed)
        }

        generatingPoseId = nil
    }

    // MARK: - Private helpers

    private func updateResult(_ result: PoseResult) {
        if let index = results.firstIndex(where: { $0.id == result.id }) {
            results[index] = result
        }
    }

    private func updateResultState(poseId: String, state: PoseResult.GenerationState) {
        if let index = results.firstIndex(where: { $0.id == poseId }) {
            results[index] = PoseResult(
                id: results[index].id,
                pose: results[index].pose,
                image: results[index].image,
                state: state
            )
        }
    }
}
