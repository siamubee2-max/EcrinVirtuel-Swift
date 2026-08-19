import Vision
import CoreImage
import UIKit

// MARK: - BodyContextAnalyzer — Analyse la photo utilisateur avant envoi à GPT Image
//
// IMPORTANT: cette classe est délibérément non-isolated parce qu'elle invoque
// Vision (VNRequest), dont les completion handlers s'exécutent sur la queue
// interne de Vision (background thread). Sous Swift 6, marquer la classe
// `@MainActor` cause un crash `_dispatch_assert_queue_fail` quand Vision
// rappelle la closure depuis un thread non-main. Le state interne est
// immutable (let shared, méthodes pures sur CGImage), donc Sendable.

/// Garantit qu'une continuation Vision n'est résumée qu'une seule fois.
/// Nécessaire car Vision peut À LA FOIS appeler le completion handler d'une
/// requête (avec erreur) ET faire throw dans `perform()` — résumer deux fois
/// crashe, ne jamais résumer suspend la génération pour toujours (spinner
/// infini, crédit consommé perdu). Thread-safe : les completions Vision
/// arrivent sur sa queue background.
final class VisionResumeGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var resumed = false

    /// Exécute `body` (qui doit résumer la continuation) au premier appel
    /// seulement ; les appels suivants sont ignorés.
    func resume(_ body: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !resumed else { return }
        resumed = true
        body()
    }
}

final class BodyContextAnalyzer: @unchecked Sendable {

    static let shared = BodyContextAnalyzer()
    private init() {}

    // MARK: - Public entry point

    /// Analyse complète de la photo : peau, morphologie, éclairage, vêtements.
    /// Retourne toujours un BodyContext valide (fallback sur les valeurs par défaut si l'analyse échoue).
    func analyze(image: UIImage) async -> BodyContext {
        guard let cgImage = image.cgImage else {
            return BodyContext.default
        }

        // Lancement parallèle des analyses indépendantes
        async let skinResult   = analyzeSkin(cgImage: cgImage)
        async let poseResult   = analyzePose(cgImage: cgImage)
        async let lightResult  = analyzeLighting(cgImage: cgImage, source: image)
        async let clothResult  = detectClothing(cgImage: cgImage)

        let skin    = await skinResult
        let pose    = await poseResult
        let light   = await lightResult
        let clothing = await clothResult

        let promptContext = buildPromptContext(
            skin: skin,
            pose: pose,
            light: light,
            clothing: clothing
        )

        let transitionInstructions = buildTransitionInstructions(
            current: clothing,
            replacing: nil,
            withNew: nil
        )

        return BodyContext(
            skinTone: skin.tone,
            skinUndertone: skin.undertone,
            skinHex: skin.hex,
            bodyShape: pose.shape,
            estimatedHeight: pose.height,
            shoulderWidth: pose.shoulders,
            lightingType: light.type,
            lightingDirection: light.direction,
            brightnessLevel: light.brightness,
            colorTemperature: light.colorTemp,
            detectedClothing: clothing,
            promptContext: promptContext,
            transitionInstructions: transitionInstructions
        )
    }

    // MARK: - Prompt context builder (utilisé par BodyContextAnalyzer.analyze)

    nonisolated func buildPromptContext(
        skin: SkinAnalysisResult,
        pose: PoseAnalysisResult,
        light: LightingAnalysisResult,
        clothing: [DetectedGarment]
    ) -> String {
        let skinDesc = "a woman with \(skin.tone.description) (\(skin.hex)), \(skin.undertone.adjective)"
        let bodyDesc = "\(pose.shape.rawValue), \(pose.height.rawValue), \(pose.shoulders.rawValue)"
        let lightDesc = "\(light.type.rawValue) \(light.direction.description), \(light.colorTemp.description.lowercased()), brightness \(Int(light.brightness * 100))%"

        return "Fashion editorial photograph of \(skinDesc). Body type: \(bodyDesc). Lighting: \(lightDesc)."
    }

    // MARK: - Transition instructions builder (public, utilisé par EnrichedPromptBuilder)

    nonisolated func buildTransitionInstructions(
        current: [DetectedGarment],
        replacing: GarmentType?,
        withNew newItem: String?
    ) -> String {
        var instructions: [String] = []

        // Règle générale : toujours maintenir la cohérence du teint
        instructions.append("Any newly exposed skin areas must exactly match the skin tone detected in the reference photo.")

        guard let replacing else {
            return instructions.joined(separator: " ")
        }

        // Instructions spécifiques selon le type de remplacement
        switch replacing {

        case .bottom:
            // Remplacement pantalon/jupe → nouveau bas
            let currentBottom = current.first(where: { $0.type == .bottom })?.description ?? "pants"
            instructions.append("Previously wearing \(currentBottom).")
            if let new = newItem, (new.contains("skirt") || new.contains("dress") || new.contains("jupe") || new.contains("robe")) {
                instructions.append("Show bare legs in natural skin tone — smooth, natural texture, no stockings unless currently visible.")
            } else {
                instructions.append("Replace bottom garment with natural body proportions maintained.")
            }

        case .shoes:
            let currentShoes = current.first(where: { $0.type == .shoes })?.description ?? "flat shoes"
            instructions.append("Previously wearing \(currentShoes).")
            if let new = newItem, (new.contains("heel") || new.contains("pump") || new.contains("stiletto") || new.contains("escarp")) {
                instructions.append("Adjust foot and ankle position naturally for heeled shoes — show feet at the natural heel-wearing angle.")
            } else if let new = newItem, (new.contains("sandal") || new.contains("flat") || new.contains("ballerine")) {
                instructions.append("Show feet in a natural flat-footed stance, toes and arch visible if the sandal design allows.")
            } else {
                instructions.append("Maintain natural foot positioning appropriate for the new footwear.")
            }

        case .top:
            let currentTop = current.first(where: { $0.type == .top })?.description ?? "top"
            instructions.append("Previously wearing \(currentTop).")
            if let new = newItem, (new.contains("décolle") || new.contains("decolle") || new.contains("off-shoulder") || new.contains("strapless")) {
                instructions.append("Show natural décolleté area in exact matching skin tone from reference photo.")
            } else {
                instructions.append("Replace top garment maintaining natural neckline and shoulder area.")
            }

        case .jacket:
            instructions.append("Remove outerwear layer. Show appropriate underlayers in natural proportions.")

        case .dress:
            let currentClothing = current.filter { $0.type == .top || $0.type == .bottom || $0.type == .dress }
                .map { $0.description }.joined(separator: " and ")
            if !currentClothing.isEmpty {
                instructions.append("Previously wearing \(currentClothing).")
            }
            instructions.append("Show full silhouette in the new dress — ensure leg area displays natural skin tone if dress hemline permits.")

        case .accessory, .underwear:
            instructions.append("Maintain all existing clothing and body proportions. Only add or replace the specified accessory.")
        }

        return instructions.joined(separator: " ")
    }

    // MARK: - A. Skin Analysis

    struct SkinAnalysisResult: Sendable {
        let tone: SkinToneLevel
        let undertone: SkinUndertone
        let hex: String
        let averageRGB: (r: CGFloat, g: CGFloat, b: CGFloat)
    }

    private func analyzeSkin(cgImage: CGImage) async -> SkinAnalysisResult {
        // Détection du visage pour cibler la zone de peau
        let faceRect = await detectFaceRect(cgImage: cgImage)

        // Crop sur la zone de peau détectée
        let skinRegion = cropToSkinRegion(cgImage: cgImage, faceRect: faceRect)

        // Echantillonnage 32x32 pour rapidité
        let (r, g, b) = sampleAverageRGB(cgImage: skinRegion, targetSize: 32)

        // Classification
        let tone = classifySkinTone(r: r, g: g, b: b)
        let undertone = classifyUndertone(r: r, g: g, b: b)
        let hex = rgbToHex(r: r, g: g, b: b)

        return SkinAnalysisResult(tone: tone, undertone: undertone, hex: hex, averageRGB: (r, g, b))
    }

    /// One-shot guard: Vision can BOTH invoke the request completion (e.g. with a
    /// cancellation error when inference setup fails) AND make `perform()` throw.
    /// Resuming a CheckedContinuation twice is a fatal error (crash observed on
    /// simulator where the Vision inference context is unavailable).
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

    private func detectFaceRect(cgImage: CGImage) async -> CGRect? {
        let resumeGuard = ContinuationResumeGuard()
        return await withCheckedContinuation { continuation in
            let guardOnce = VisionResumeGuard()
            let request = VNDetectFaceRectanglesRequest { req, _ in
                guard resumeGuard.tryResume() else { return }
                guard let obs = req.results?.first as? VNFaceObservation else {
                    guardOnce.resume { continuation.resume(returning: nil) }
                    return
                }
                // Vision → coordonnées normalisées bas-gauche → haut-gauche
                let bb = obs.boundingBox
                let converted = CGRect(
                    x: bb.minX,
                    y: 1.0 - bb.maxY,
                    width: bb.width,
                    height: bb.height
                )
                guardOnce.resume { continuation.resume(returning: converted) }
            }
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                // perform threw — the completion may or may not have fired already.
                guardOnce.resume { continuation.resume(returning: nil) }
            }
        }
    }

    private func cropToSkinRegion(cgImage: CGImage, faceRect: CGRect?) -> CGImage {
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)

        let targetNorm: CGRect
        if let face = faceRect {
            // Légèrement à l'intérieur du visage pour éviter fond / cheveux
            let inset: CGFloat = 0.08
            targetNorm = face.insetBy(dx: face.width * inset, dy: face.height * inset)
        } else {
            // Fallback : zone centrale haute (là où est généralement la peau visible)
            targetNorm = CGRect(x: 0.30, y: 0.15, width: 0.40, height: 0.35)
        }

        let pixelRect = CGRect(
            x: targetNorm.minX * w,
            y: targetNorm.minY * h,
            width: targetNorm.width * w,
            height: targetNorm.height * h
        )

        return cgImage.cropping(to: pixelRect) ?? cgImage
    }

    private func sampleAverageRGB(cgImage: CGImage, targetSize: Int) -> (CGFloat, CGFloat, CGFloat) {
        let size = min(targetSize, min(cgImage.width, cgImage.height))
        guard
            let ctx = CGContext(
                data: nil,
                width: size, height: size,
                bitsPerComponent: 8,
                bytesPerRow: size * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { return (0.7, 0.55, 0.45) } // Fallback warm medium

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))
        guard let data = ctx.data else { return (0.7, 0.55, 0.45) }

        let ptr = data.assumingMemoryBound(to: UInt8.self)
        let count = size * size
        var totalR: CGFloat = 0, totalG: CGFloat = 0, totalB: CGFloat = 0

        for i in 0..<count {
            let offset = i * 4
            totalR += CGFloat(ptr[offset])     / 255.0
            totalG += CGFloat(ptr[offset + 1]) / 255.0
            totalB += CGFloat(ptr[offset + 2]) / 255.0
        }

        let n = CGFloat(count)
        return (totalR / n, totalG / n, totalB / n)
    }

    /// Classification SkinToneLevel basée sur la luminance perçue
    private func classifySkinTone(r: CGFloat, g: CGFloat, b: CGFloat) -> SkinToneLevel {
        // Luminance perceptuelle (pondération ITU-R BT.709)
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        switch luminance {
        case 0.80...: return .fair
        case 0.65..<0.80: return .light
        case 0.50..<0.65: return .medium
        case 0.35..<0.50: return .tan
        default: return .deep
        }
    }

    /// Classification undertone par analyse du rapport R/G/B
    private func classifyUndertone(r: CGFloat, g: CGFloat, b: CGFloat) -> SkinUndertone {
        // Warm : prédominance rouge/orange (R > B significativement)
        // Cool : teinte rosée ou bleutée (B relativement élevé, R avec teinte rose)
        let rMinusB = r - b
        let yellowness = r - g         // positif = teinte orangée/jaune

        if rMinusB > 0.12 && yellowness > 0.04 {
            return .warm
        } else if rMinusB < 0.06 || b > g {
            return .cool
        } else {
            return .neutral
        }
    }

    /// Conversion RGB (0-1) → hex string "#RRGGBB"
    private func rgbToHex(r: CGFloat, g: CGFloat, b: CGFloat) -> String {
        let ri = Int((r * 255).clamped(to: 0...255))
        let gi = Int((g * 255).clamped(to: 0...255))
        let bi = Int((b * 255).clamped(to: 0...255))
        return String(format: "#%02X%02X%02X", ri, gi, bi)
    }

    // MARK: - B. Pose / Morphology Analysis

    struct PoseAnalysisResult: Sendable {
        let shape: BodyShape
        let height: HeightRange
        let shoulders: ShoulderWidth
    }

    private func analyzePose(cgImage: CGImage) async -> PoseAnalysisResult {
        let fallback = PoseAnalysisResult(shape: .hourglass, height: .medium, shoulders: .medium)
        let resumeGuard = ContinuationResumeGuard()
        return await withCheckedContinuation { continuation in
            let guardOnce = VisionResumeGuard()
            let request = VNDetectHumanBodyPoseRequest { req, _ in
                guard resumeGuard.tryResume() else { return }
                guard let obs = req.results?.first as? VNHumanBodyPoseObservation else {
                    // Pas de pose détectée → valeurs par défaut
                    guardOnce.resume { continuation.resume(returning: fallback) }
                    return
                }

                let result = self.classifyPose(from: obs)
                guardOnce.resume { continuation.resume(returning: result) }
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                // perform threw — the completion may or may not have fired already.
                guardOnce.resume { continuation.resume(returning: fallback) }
            }
        }
    }

    private func classifyPose(from obs: VNHumanBodyPoseObservation) -> PoseAnalysisResult {
        // Extraction des landmarks clés
        let leftShoulder  = try? obs.recognizedPoint(.leftShoulder)
        let rightShoulder = try? obs.recognizedPoint(.rightShoulder)
        let leftHip       = try? obs.recognizedPoint(.leftHip)
        let rightHip      = try? obs.recognizedPoint(.rightHip)
        let neck          = try? obs.recognizedPoint(.neck)
        let leftAnkle     = try? obs.recognizedPoint(.leftAnkle)
        let rightAnkle    = try? obs.recognizedPoint(.rightAnkle)

        // Largeur épaules (normalisée)
        let shoulderWidth: CGFloat
        if let ls = leftShoulder, let rs = rightShoulder,
           ls.confidence > 0.5, rs.confidence > 0.5 {
            shoulderWidth = abs(rs.location.x - ls.location.x)
        } else {
            shoulderWidth = 0.35 // valeur médiane
        }

        // Largeur hanches (normalisée)
        let hipWidth: CGFloat
        if let lh = leftHip, let rh = rightHip,
           lh.confidence > 0.5, rh.confidence > 0.5 {
            hipWidth = abs(rh.location.x - lh.location.x)
        } else {
            hipWidth = 0.30
        }

        // Taille estimée via rapport cou / chevilles
        let heightRange: HeightRange
        if let n = neck, let la = leftAnkle, let ra = rightAnkle,
           n.confidence > 0.4, la.confidence > 0.4 {
            let ankleY = (la.location.y + ra.location.y) / 2.0
            // Use abs() to handle both coordinate orientations (landscape/portrait)
            // Vision y increases upward in portrait, so neck.y > ankleY normally.
            // For rotated images the sign can invert; abs() gives a robust ratio.
            let bodyHeight = abs(n.location.y - ankleY)
            if bodyHeight > 0.65 {
                heightRange = .tall
            } else if bodyHeight < 0.45 {
                heightRange = .petite
            } else {
                heightRange = .medium
            }
        } else {
            heightRange = .medium
        }

        // Classification de la silhouette
        let shoulderCat: ShoulderWidth
        if shoulderWidth > 0.42 {
            shoulderCat = .broad
        } else if shoulderWidth < 0.28 {
            shoulderCat = .narrow
        } else {
            shoulderCat = .medium
        }

        let bodyShape = classifyBodyShape(shoulderWidth: shoulderWidth, hipWidth: hipWidth)

        return PoseAnalysisResult(shape: bodyShape, height: heightRange, shoulders: shoulderCat)
    }

    private func classifyBodyShape(shoulderWidth: CGFloat, hipWidth: CGFloat) -> BodyShape {
        let ratio = shoulderWidth / max(hipWidth, 0.01)

        switch ratio {
        case ..<0.85:
            // Hanches nettement plus larges que épaules
            return .pear
        case 0.85..<1.05:
            // Proportions équilibrées épaules/hanches → hourglass si taille fine
            return .hourglass
        case 1.05..<1.20:
            // Epaules légèrement plus larges → rectangle ou triangle inversé
            return .rectangle
        case 1.20...:
            return .invertedTriangle
        default:
            return .hourglass
        }
    }

    // MARK: - C. Lighting Analysis

    struct LightingAnalysisResult: Sendable {
        let type: LightingType
        let direction: LightingDirection
        let brightness: Double
        let colorTemp: ColorTemperature
    }

    private func analyzeLighting(cgImage: CGImage, source: UIImage) async -> LightingAnalysisResult {
        // Analyse de la luminosité globale via CIImage
        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext()

        // Luminance globale
        let brightness = computeGlobalBrightness(ciImage: ciImage, context: context)

        // Direction de la lumière via analyse de la distribution des zones claires
        let direction = estimateLightDirection(cgImage: cgImage)

        // Température de couleur via ratio des canaux
        let (r, g, b) = sampleAverageRGB(cgImage: cgImage, targetSize: 64)
        let colorTemp = classifyColorTemperature(r: r, g: g, b: b)

        // Type d'éclairage basé sur luminosité + temperature
        let lightType = classifyLightingType(brightness: brightness, colorTemp: colorTemp)

        return LightingAnalysisResult(
            type: lightType,
            direction: direction,
            brightness: brightness,
            colorTemp: colorTemp
        )
    }

    private func computeGlobalBrightness(ciImage: CIImage, context: CIContext) -> Double {
        // Utilise CIAreaAverage pour obtenir la luminosité moyenne
        let extent = ciImage.extent
        let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: ciImage,
            kCIInputExtentKey: CIVector(cgRect: extent)
        ])

        guard let output = filter?.outputImage else { return 0.5 }

        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(output,
                       toBitmap: &pixel,
                       rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8,
                       colorSpace: CGColorSpaceCreateDeviceRGB())

        let r = Double(pixel[0]) / 255.0
        let g = Double(pixel[1]) / 255.0
        let b = Double(pixel[2]) / 255.0

        // Luminance perceptuelle
        return (0.2126 * r + 0.7152 * g + 0.0722 * b).clamped(to: 0...1)
    }

    /// Estimation de la direction lumineuse par comparaison gauche/droite et haut/bas
    private func estimateLightDirection(cgImage: CGImage) -> LightingDirection {
        // Use CGFloat to avoid integer truncation when dividing pixel dimensions.
        let wF = CGFloat(cgImage.width)
        let hF = CGFloat(cgImage.height)
        let w  = cgImage.width
        let h  = cgImage.height

        // Zones de comparaison : gauche/droite (tiers) + haut/bas
        let leftRegion  = cgImage.cropping(to: CGRect(x: 0,           y: 0, width: wF / 3,       height: CGFloat(h))) ?? cgImage
        let rightRegion = cgImage.cropping(to: CGRect(x: wF * 2 / 3,  y: 0, width: wF - wF * 2 / 3, height: CGFloat(h))) ?? cgImage
        let topRegion   = cgImage.cropping(to: CGRect(x: 0,           y: 0, width: CGFloat(w),   height: hF / 3)) ?? cgImage

        let (leftR, leftG, leftB)   = sampleAverageRGB(cgImage: leftRegion,  targetSize: 16)
        let (rightR, rightG, rightB) = sampleAverageRGB(cgImage: rightRegion, targetSize: 16)
        let (topR, topG, topB)       = sampleAverageRGB(cgImage: topRegion,   targetSize: 16)

        let leftLum  = 0.2126 * leftR  + 0.7152 * leftG  + 0.0722 * leftB
        let rightLum = 0.2126 * rightR + 0.7152 * rightG + 0.0722 * rightB
        let topLum   = 0.2126 * topR   + 0.7152 * topG   + 0.0722 * topB

        // Analyse des différences
        let horizontalDiff = abs(leftLum - rightLum)
        let threshold: CGFloat = 0.08

        if horizontalDiff < threshold && topLum > 0.55 {
            return .top
        } else if leftLum > rightLum + threshold {
            return .left
        } else if rightLum > leftLum + threshold {
            return .right
        } else {
            return .front
        }
    }

    private func classifyColorTemperature(r: CGFloat, g: CGFloat, b: CGFloat) -> ColorTemperature {
        // Warm si R > B significativement, cool si B > R
        let rMinusB = r - b
        if rMinusB > 0.08 {
            return .warm
        } else if rMinusB < -0.04 {
            return .cool
        } else {
            return .neutral
        }
    }

    private func classifyLightingType(brightness: Double, colorTemp: ColorTemperature) -> LightingType {
        switch brightness {
        case ..<0.30:
            return .dark
        case 0.30..<0.55:
            return colorTemp == .warm ? .indoor : .indoor
        case 0.55..<0.70:
            return colorTemp == .warm ? .outdoor : .natural
        case 0.70...:
            return colorTemp == .cool ? .studio : .outdoor
        default:
            return .natural
        }
    }

    // MARK: - D. Clothing Detection

    private func detectClothing(cgImage: CGImage) async -> [DetectedGarment] {
        let resumeGuard = ContinuationResumeGuard()
        return await withCheckedContinuation { continuation in
            let guardOnce = VisionResumeGuard()
            let request = VNClassifyImageRequest { req, _ in
                guard resumeGuard.tryResume() else { return }
                guard let observations = req.results as? [VNClassificationObservation] else {
                    guardOnce.resume { continuation.resume(returning: []) }
                    return
                }

                // Filtrage des observations pertinentes (confiance > 0.3)
                let relevant = observations
                    .filter { $0.confidence > 0.3 }
                    .prefix(20)

                let garments = self.mapObservationsToGarments(Array(relevant))
                guardOnce.resume { continuation.resume(returning: garments) }
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                // perform threw — the completion may or may not have fired already.
                guardOnce.resume { continuation.resume(returning: []) }
            }
        }
    }

    private func mapObservationsToGarments(
        _ observations: [VNClassificationObservation]
    ) -> [DetectedGarment] {
        var garments: [DetectedGarment] = []

        for obs in observations {
            let id = obs.identifier.lowercased()

            // Correspondances heuristiques identifier → GarmentType
            if id.contains("jean") || id.contains("trouser") || id.contains("pant") || id.contains("skirt") {
                let desc = id.contains("jean") ? "jeans" : id.contains("skirt") ? "skirt" : "trousers"
                garments.append(DetectedGarment(type: .bottom, description: desc, isBeingReplaced: false))
            } else if id.contains("shirt") || id.contains("blouse") || id.contains("top") || id.contains("sweater") {
                garments.append(DetectedGarment(type: .top, description: id, isBeingReplaced: false))
            } else if id.contains("dress") {
                garments.append(DetectedGarment(type: .dress, description: id, isBeingReplaced: false))
            } else if id.contains("jacket") || id.contains("coat") || id.contains("blazer") {
                garments.append(DetectedGarment(type: .jacket, description: id, isBeingReplaced: false))
            } else if id.contains("shoe") || id.contains("boot") || id.contains("sneaker") || id.contains("heel") || id.contains("sandal") {
                let desc = id.contains("heel") ? "heels" : id.contains("boot") ? "boots" : id.contains("sandal") ? "sandals" : "shoes"
                garments.append(DetectedGarment(type: .shoes, description: desc, isBeingReplaced: false))
            }
        }

        // Déduplique par type (garde le premier trouvé)
        var seen = Set<GarmentType>()
        return garments.filter { garment in
            guard !seen.contains(garment.type) else { return false }
            seen.insert(garment.type)
            return true
        }
    }
}

// MARK: - Comparable clamping helper

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
