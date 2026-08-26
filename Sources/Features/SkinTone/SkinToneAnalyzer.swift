import UIKit
import CoreImage
import Vision

// MARK: - Skin Tone Analyzer

@MainActor
final class SkinToneAnalyzer {

    // MARK: - Public API

    static func analyze(_ image: UIImage) async throws -> SkinToneProfile {
        // Extract dominant hue/saturation/brightness from face region
        let hsl = try await extractFaceRegionHSL(from: image)
        let undertone = determineUndertone(hue: hsl.hue, saturation: hsl.saturation)
        let depth = determineSkinDepth(brightness: hsl.brightness)
        let recommendations = buildRecommendations(undertone: undertone)
        let avoidMetals = buildAvoidList(undertone: undertone)
        let powerStones = buildPowerStones(undertone: undertone, depth: depth)

        return SkinToneProfile(
            undertone: undertone,
            depth: depth,
            recommendedMetals: recommendations,
            avoidMetals: avoidMetals,
            powerStones: powerStones
        )
    }

    // MARK: - Image Analysis

    private static func extractFaceRegionHSL(from image: UIImage) async throws -> HSLColor {
        guard let cgImage = image.cgImage else {
            throw AnalysisError.invalidImage
        }

        // Attempt to detect face rectangle via Vision
        let faceRegion = await detectFaceRegion(cgImage: cgImage)

        // Crop to face region or central crop
        let croppedCG = cropImage(cgImage, to: faceRegion)

        // Sample pixels and compute average HSL
        return computeAverageHSL(from: croppedCG)
    }

    /// One-shot guard: Vision peut appeler le completion (avec erreur d'annulation)
    /// ET faire jeter `perform()` — un double resume de continuation est fatal.
    private final class ContinuationResumeGuard: @unchecked Sendable {
        private let lock = NSLock()
        private var resumed = false
        func tryResume() -> Bool {
            lock.lock(); defer { lock.unlock() }
            if resumed { return false }
            resumed = true
            return true
        }
    }

    // `nonisolated` CRITIQUE : la classe est @MainActor ; sans ça la closure Vision
    // hériterait de l'isolation MainActor et crasherait (dispatch_assert_queue) car
    // Vision appelle le handler sur une queue background. On exécute sur queue globale.
    nonisolated private static func detectFaceRegion(cgImage: CGImage) async -> CGRect {
        let resumeGuard = ContinuationResumeGuard()
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNDetectFaceRectanglesRequest { req, _ in
                    guard resumeGuard.tryResume() else { return }
                    guard let obs = req.results?.first as? VNFaceObservation else {
                        // Fallback: use central 40% of image
                        let fallback = CGRect(x: 0.3, y: 0.2, width: 0.4, height: 0.5)
                        continuation.resume(returning: fallback)
                        return
                    }
                    // Vision uses bottom-left origin; convert to top-left
                    let bb = obs.boundingBox
                    let topLeft = CGRect(
                        x: bb.minX,
                        y: 1 - bb.maxY,
                        width: bb.width,
                        height: bb.height
                    )
                    continuation.resume(returning: topLeft)
                }
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    if resumeGuard.tryResume() {
                        continuation.resume(returning: CGRect(x: 0.3, y: 0.2, width: 0.4, height: 0.5))
                    }
                }
            }
        }
    }

    private static func cropImage(_ cgImage: CGImage, to normalizedRect: CGRect) -> CGImage {
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)
        let pixelRect = CGRect(
            x: normalizedRect.minX * w,
            y: normalizedRect.minY * h,
            width: normalizedRect.width * w,
            height: normalizedRect.height * h
        )
        return cgImage.cropping(to: pixelRect) ?? cgImage
    }

    private static func computeAverageHSL(from cgImage: CGImage) -> HSLColor {
        let width  = min(cgImage.width,  64)
        let height = min(cgImage.height, 64)

        guard
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { return HSLColor(hue: 0.08, saturation: 0.4, brightness: 0.7) }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let data = context.data else {
            return HSLColor(hue: 0.08, saturation: 0.4, brightness: 0.7)
        }

        let pixelCount = width * height
        var totalR: CGFloat = 0
        var totalG: CGFloat = 0
        var totalB: CGFloat = 0

        for i in 0..<pixelCount {
            let offset = i * 4
            let ptr = data.assumingMemoryBound(to: UInt8.self)
            totalR += CGFloat(ptr[offset])     / 255.0
            totalG += CGFloat(ptr[offset + 1]) / 255.0
            totalB += CGFloat(ptr[offset + 2]) / 255.0
        }

        let r = totalR / CGFloat(pixelCount)
        let g = totalG / CGFloat(pixelCount)
        let b = totalB / CGFloat(pixelCount)

        return rgbToHSL(r: r, g: g, b: b)
    }

    // MARK: - Color Math

    private static func rgbToHSL(r: CGFloat, g: CGFloat, b: CGFloat) -> HSLColor {
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let l = (maxC + minC) / 2.0

        guard maxC != minC else {
            return HSLColor(hue: 0, saturation: 0, brightness: l)
        }

        let delta = maxC - minC
        let s = l > 0.5 ? delta / (2 - maxC - minC) : delta / (maxC + minC)

        var h: CGFloat
        if maxC == r {
            h = (g - b) / delta + (g < b ? 6 : 0)
        } else if maxC == g {
            h = (b - r) / delta + 2
        } else {
            h = (r - g) / delta + 4
        }
        h /= 6.0

        return HSLColor(hue: h, saturation: s, brightness: l)
    }

    // MARK: - Classification Logic

    private static func determineUndertone(hue: CGFloat, saturation: CGFloat) -> Undertone {
        // Hue in [0, 1]: 0=red, 0.08=orange, 0.16=yellow, 0.33=green, 0.5=cyan, 0.66=blue, 0.75=violet
        // Low saturation → neutral
        guard saturation > 0.05 else { return .neutral }

        // Warm: orange/yellow/red tones
        let isWarm = (hue < 0.12) || (hue > 0.92) || (hue > 0.08 && hue < 0.20)
        // Cool: pink/rosy/blue tones
        let isCool = (hue > 0.85 && hue <= 0.92) || (hue > 0.55 && hue < 0.80)

        if isWarm && !isCool { return .warm }
        if isCool && !isWarm { return .cool }
        return .neutral
    }

    private static func determineSkinDepth(brightness: CGFloat) -> SkinDepth {
        switch brightness {
        case 0.80...: return .fair
        case 0.65..<0.80: return .light
        case 0.50..<0.65: return .medium
        case 0.35..<0.50: return .tan
        default: return .deep
        }
    }

    // MARK: - Recommendation Engine

    private static func buildRecommendations(undertone: Undertone) -> [MetalRecommendation] {
        switch undertone {
        case .warm:
            return [
                MetalRecommendation(
                    id: "yellow-gold",
                    metal: "Or jaune 18k",
                    reason: "Le métal roi pour les teints chauds. Son éclat solaire prolonge naturellement votre carnation.",
                    score: 5,
                    icon: "circle.fill"
                ),
                MetalRecommendation(
                    id: "rose-gold",
                    metal: "Or rose",
                    reason: "La fusion parfaite entre chaleur cuivrée et raffinement. Une harmonie instinctive avec votre peau.",
                    score: 4,
                    icon: "heart.fill"
                ),
                MetalRecommendation(
                    id: "bronze",
                    metal: "Bronze doré",
                    reason: "Un métal audacieux qui amplifie les pigments chauds pour un rendu sculpté.",
                    score: 3,
                    icon: "star.fill"
                ),
            ]
        case .cool:
            return [
                MetalRecommendation(
                    id: "platinum",
                    metal: "Platine",
                    reason: "La noblesse absolue pour les teints froids. Son éclat glacé magnifie vos reflets naturels.",
                    score: 5,
                    icon: "snowflake"
                ),
                MetalRecommendation(
                    id: "white-gold",
                    metal: "Or blanc 18k",
                    reason: "Alliant pureté et préciosité, il crée une continuité lumineuse avec votre carnation.",
                    score: 4,
                    icon: "circle.fill"
                ),
                MetalRecommendation(
                    id: "silver",
                    metal: "Argent pur",
                    reason: "Sa fraîcheur métallique entre en résonance avec vos sous-tons rosés.",
                    score: 3,
                    icon: "moon.fill"
                ),
            ]
        case .neutral:
            return [
                MetalRecommendation(
                    id: "yellow-gold",
                    metal: "Or jaune 18k",
                    reason: "Votre équilibre rare vous permet de porter l'or jaune avec une aisance naturelle.",
                    score: 5,
                    icon: "circle.fill"
                ),
                MetalRecommendation(
                    id: "rose-gold",
                    metal: "Or rose",
                    reason: "La douceur de l'or rose souligne votre beauté équilibrée avec délicatesse.",
                    score: 5,
                    icon: "heart.fill"
                ),
                MetalRecommendation(
                    id: "platinum",
                    metal: "Platine",
                    reason: "Le platine s'adapte à votre polyvalence avec une élégance sans compromis.",
                    score: 4,
                    icon: "snowflake"
                ),
            ]
        }
    }

    private static func buildAvoidList(undertone: Undertone) -> [String] {
        switch undertone {
        case .warm:    return ["Argent pur", "Platine froid", "Rhodium mat"]
        case .cool:    return ["Or jaune bronze", "Or 9k jaunâtre", "Cuivre brut"]
        case .neutral: return []
        }
    }

    private static func buildPowerStones(undertone: Undertone, depth: SkinDepth) -> [String] {
        switch undertone {
        case .warm:
            return depth == .deep || depth == .tan
                ? ["Citrine", "Corail", "Ambre", "Grenat", "Topaze fumée"]
                : ["Citrine", "Ambre", "Corail", "Tourmaline rose", "Opale de feu"]
        case .cool:
            return depth == .deep || depth == .tan
                ? ["Saphir", "Aigue-marine", "Tanzanite", "Lapis-lazuli", "Perle"]
                : ["Diamant", "Aigue-marine", "Saphir clair", "Améthyste", "Perle"]
        case .neutral:
            return ["Diamant", "Émeraude", "Rubis", "Saphir", "Opale blanche"]
        }
    }

    // MARK: - Error

    enum AnalysisError: LocalizedError {
        case invalidImage
        var errorDescription: String? { "L'image ne peut pas être analysée." }
    }
}

// MARK: - HSL Helper

private struct HSLColor {
    let hue: CGFloat
    let saturation: CGFloat
    let brightness: CGFloat
}
