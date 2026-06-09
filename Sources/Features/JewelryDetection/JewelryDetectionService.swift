import Vision
import UIKit

// MARK: - JewelryDetectionResult

struct JewelryDetectionResult {
    let category: FashionCategory
    let label: String          // raw Vision identifier
    let confidence: Float      // 0.0 – 1.0
}

// MARK: - JewelryDetectionService

/// Detects jewelry category from a UIImage using Apple's Vision framework.
/// Uses `VNClassifyImageRequest` (no network, no ML model download required).
final class JewelryDetectionService: Sendable {

    static let shared = JewelryDetectionService()
    private init() {}

    // MARK: - Public API

    /// Analyse la photo et retourne les bijoux détectés triés par confiance.
    func detect(image: UIImage) async -> [JewelryDetectionResult] {
        guard let cgImage = image.cgImage else { return [] }

        return await withCheckedContinuation { continuation in
            let request = VNClassifyImageRequest { req, _ in
                guard let observations = req.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                let results = Self.mapToJewelry(observations)
                continuation.resume(returning: results)
            }
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    // MARK: - Label mapping

    private static let labelMap: [(keywords: [String], category: FashionCategory)] = [
        (["necklace", "pendant", "chain", "choker", "collar"], .necklace),
        (["ring", "band", "engagement", "wedding ring", "signet"], .ring),
        (["earring", "ear ring", "stud", "hoop", "drop earring", "dangle"], .earring),
        (["bracelet", "bangle", "cuff", "wristband"], .bracelet),
        (["watch", "wristwatch", "timepiece"], .watch),
        (["brooch", "pin", "badge jewelry", "lapel"], .brooch),
    ]

    private static func mapToJewelry(
        _ observations: [VNClassificationObservation]
    ) -> [JewelryDetectionResult] {
        var results: [JewelryDetectionResult] = []

        for obs in observations where obs.confidence > 0.08 {
            let id = obs.identifier.lowercased()
            for (keywords, category) in labelMap {
                if keywords.contains(where: { id.contains($0) }) {
                    results.append(JewelryDetectionResult(
                        category: category,
                        label: obs.identifier,
                        confidence: obs.confidence
                    ))
                    break
                }
            }
        }

        // Deduplicate: keep highest confidence per category.
        var best: [FashionCategory: JewelryDetectionResult] = [:]
        for r in results {
            if (best[r.category]?.confidence ?? 0) < r.confidence {
                best[r.category] = r
            }
        }

        return best.values.sorted { $0.confidence > $1.confidence }
    }
}
