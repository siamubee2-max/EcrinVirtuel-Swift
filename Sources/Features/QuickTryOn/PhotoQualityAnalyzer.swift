// PhotoQualityAnalyzer.swift
// Path: Sources/Features/QuickTryOn/PhotoQualityAnalyzer.swift

import UIKit
import Vision
import CoreImage
import SwiftUI

// Analyzes a photo for quality before generation.
// Uses Vision framework to detect faces and assess lighting.
@MainActor
final class PhotoQualityAnalyzer {

    enum Quality {
        case excellent  // Good lighting, face detected, neutral background
        case acceptable // Face detected, some issues
        case poor       // No face detected or very dark

        var emoji: String {
            switch self {
            case .excellent: return "🟢"
            case .acceptable: return "🟡"
            case .poor: return "🔴"
            }
        }

        var label: String {
            switch self {
            case .excellent: return "EXCELLENT"
            case .acceptable: return "CORRECT"
            case .poor: return "À AMÉLIORER"
            }
        }

        var description: String {
            switch self {
            case .excellent: return "Lumière et cadrage parfaits"
            case .acceptable: return "Résultat possible, lumière à améliorer"
            case .poor: return "Essayez avec plus de lumière ou un fond neutre"
            }
        }

        var color: Color {
            switch self {
            case .excellent: return Color.green
            case .acceptable: return Color.yellow
            case .poor: return Color.red
            }
        }
    }

    func analyze(_ image: UIImage) async -> Quality {
        let luminance = await averageLuminance(image)
        let hasFace = await detectFace(image)

        if hasFace && luminance > 0.35 { return .excellent }
        if luminance > 0.2 { return .acceptable }
        return .poor
    }

    nonisolated private func averageLuminance(_ image: UIImage) async -> Double {
        guard let cgImage = image.cgImage else { return 0.3 }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let ciImage = CIImage(cgImage: cgImage)
                let extent = ciImage.extent
                guard let filter = CIFilter(
                    name: "CIAreaAverage",
                    parameters: [
                        kCIInputImageKey: ciImage,
                        kCIInputExtentKey: CIVector(cgRect: extent)
                    ]
                ), let output = filter.outputImage else {
                    continuation.resume(returning: 0.3)
                    return
                }
                var bitmap = [UInt8](repeating: 0, count: 4)
                let context = CIContext()
                context.render(
                    output,
                    toBitmap: &bitmap,
                    rowBytes: 4,
                    bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                    format: .RGBA8,
                    colorSpace: CGColorSpaceCreateDeviceRGB()
                )
                let r = Double(bitmap[0]) / 255
                let g = Double(bitmap[1]) / 255
                let b = Double(bitmap[2]) / 255
                // BT.601 luminance weights
                let luminance = 0.299 * r + 0.587 * g + 0.114 * b
                continuation.resume(returning: luminance)
            }
        }
    }

    // `nonisolated` est CRITIQUE : la classe est @MainActor, donc sans ça la closure
    // de complétion Vision hériterait de l'isolation MainActor. Or Vision appelle
    // ce handler sur une queue background → `dispatch_assert_queue(main)` échoue
    // → EXC_BREAKPOINT (crash). On exécute Vision sur une queue globale et la
    // continuation (Sendable) reprend depuis le thread background sans souci.
    nonisolated private func detectFace(_ image: UIImage) async -> Bool {
        guard let cgImage = image.cgImage else { return false }
        // One-shot guard : Vision peut appeler le completion (annulation) ET faire
        // jeter perform() — un double resume de continuation est fatal.
        let resumeGuard = PhotoQualityResumeGuard()
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNDetectFaceRectanglesRequest { req, _ in
                    guard resumeGuard.tryResume() else { return }
                    continuation.resume(returning: !(req.results ?? []).isEmpty)
                }
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    if resumeGuard.tryResume() {
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }
}

/// One-shot guard pour les continuations Vision de ce fichier.
private final class PhotoQualityResumeGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var resumed = false
    func tryResume() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if resumed { return false }
        resumed = true
        return true
    }
}
