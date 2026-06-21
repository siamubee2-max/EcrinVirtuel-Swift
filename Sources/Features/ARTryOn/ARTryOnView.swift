import SwiftUI
import ARKit
import OSLog
import RealityKit

// MARK: - AR Try-On View (UIViewRepresentable)

struct ARTryOnView: UIViewRepresentable {
    let jewelry: JewelryItem
    @Binding var isCapturing: Bool
    let onCapture: (UIImage) -> Void

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.session.delegate = context.coordinator
        context.coordinator.arView = arView
        context.coordinator.jewelry = jewelry
        context.coordinator.startSession()
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // Update jewelry if it changes
        if context.coordinator.jewelry?.id != jewelry.id {
            context.coordinator.jewelry = jewelry
            context.coordinator.replaceJewelry()
        }

        // Trigger capture
        if isCapturing {
            context.coordinator.captureSnapshot(
                completion: { image in
                    onCapture(image)
                    DispatchQueue.main.async { isCapturing = false }
                },
                onCaptureFailure: {
                    // snapshot returned nil — reset flag to break the infinite re-render loop
                    isCapturing = false
                }
            )
        }
    }

    func makeCoordinator() -> ARCoordinator {
        ARCoordinator()
    }
}

// MARK: - AR Coordinator

final class ARCoordinator: NSObject, ARSessionDelegate {
    weak var arView: ARView?
    var jewelry: JewelryItem?

    // Anchors
    private var faceAnchorEntity: AnchorEntity?
    private var bodyAnchorEntity: AnchorEntity?

    // Jewelry entities
    private var leftEarringEntity: ModelEntity?
    private var rightEarringEntity: ModelEntity?
    private var necklaceEntity: ModelEntity?
    private var braceletEntity: ModelEntity?
    private var ringEntity: ModelEntity?

    // Session mode
    private var sessionMode: SessionMode = .face

    enum SessionMode {
        case face   // earrings, necklace
        case body   // bracelet, ring, watch
    }

    // MARK: - Session Start

    func startSession() {
        guard let arView else { return }
        guard let jewelry else { return }

        sessionMode = modeForJewelry(jewelry)

        switch sessionMode {
        case .face:
            if ARFaceTrackingConfiguration.isSupported {
                let config = ARFaceTrackingConfiguration()
                config.maximumNumberOfTrackedFaces = 1
                arView.session.run(config, options: [.removeExistingAnchors, .resetTracking])
            }
        case .body:
            if ARBodyTrackingConfiguration.isSupported {
                let config = ARBodyTrackingConfiguration()
                arView.session.run(config, options: [.removeExistingAnchors, .resetTracking])
            } else if ARFaceTrackingConfiguration.isSupported {
                // Fallback to face if body not available
                sessionMode = .face
                let config = ARFaceTrackingConfiguration()
                arView.session.run(config, options: [.removeExistingAnchors, .resetTracking])
            }
        }

        setupJewelryEntities()
    }

    func replaceJewelry() {
        removeAllJewelry()
        startSession()
    }

    // MARK: - Entity Setup

    private func setupJewelryEntities() {
        guard let arView, let jewelry else { return }
        let material = ARJewelryEntity.goldMaterial()
        _ = material // already captured in factory

        switch jewelry.category {
        case .earring:
            setupEarrings(in: arView)
        case .necklace:
            setupNecklace(in: arView)
        case .bracelet, .watch:
            setupBracelet(in: arView)
        case .ring:
            setupRing(in: arView)
        case .nosePiercing, .eyebrowPiercing, .lipPiercing, .tonguePiercing:
            setupEarrings(in: arView) // face-tracking anchor; full AR piercing TBD
        }
    }

    private func setupEarrings(in arView: ARView) {
        let anchor = AnchorEntity(.face)
        faceAnchorEntity = anchor

        let (left, right) = ARJewelryEntity.makeEarrings()

        // Position at ear locations relative to face center
        left.position  = SIMD3<Float>(-0.08, -0.03, -0.01)
        right.position = SIMD3<Float>( 0.08, -0.03, -0.01)

        leftEarringEntity = left
        rightEarringEntity = right

        anchor.addChild(left)
        anchor.addChild(right)
        arView.scene.addAnchor(anchor)
    }

    private func setupNecklace(in arView: ARView) {
        let anchor = AnchorEntity(.face)
        faceAnchorEntity = anchor

        let necklace = ARJewelryEntity.makeNecklace()
        necklace.position = SIMD3<Float>(0, -0.12, 0)
        necklaceEntity = necklace

        anchor.addChild(necklace)
        arView.scene.addAnchor(anchor)
    }

    private func setupBracelet(in arView: ARView) {
        // Try body anchor first; fall back to a world anchor
        if ARBodyTrackingConfiguration.isSupported {
            let anchor = AnchorEntity(.body)
            bodyAnchorEntity = anchor

            let bracelet = ARJewelryEntity.makeBracelet()
            bracelet.position = SIMD3<Float>(0.28, 0, 0) // approximate wrist offset
            braceletEntity = bracelet

            anchor.addChild(bracelet)
            arView.scene.addAnchor(anchor)
        } else {
            // Fallback: place in front of camera
            let anchor = AnchorEntity(world: SIMD3<Float>(0, -0.2, -0.5))
            bodyAnchorEntity = anchor

            let bracelet = ARJewelryEntity.makeBracelet()
            braceletEntity = bracelet
            anchor.addChild(bracelet)
            arView.scene.addAnchor(anchor)
        }
    }

    private func setupRing(in arView: ARView) {
        if ARBodyTrackingConfiguration.isSupported {
            let anchor = AnchorEntity(.body)
            bodyAnchorEntity = anchor

            let ring = ARJewelryEntity.makeRing()
            ring.position = SIMD3<Float>(0.28, 0.01, 0.01)
            ringEntity = ring

            anchor.addChild(ring)
            arView.scene.addAnchor(anchor)
        } else {
            let anchor = AnchorEntity(world: SIMD3<Float>(0, -0.25, -0.5))
            bodyAnchorEntity = anchor

            let ring = ARJewelryEntity.makeRing()
            ringEntity = ring
            anchor.addChild(ring)
            arView.scene.addAnchor(anchor)
        }
    }

    // MARK: - Remove All

    private func removeAllJewelry() {
        faceAnchorEntity?.removeFromParent()
        bodyAnchorEntity?.removeFromParent()
        faceAnchorEntity = nil
        bodyAnchorEntity = nil
        leftEarringEntity = nil
        rightEarringEntity = nil
        necklaceEntity = nil
        braceletEntity = nil
        ringEntity = nil
    }

    // MARK: - Capture

    /// onCaptureFailure is called (on main thread) when the snapshot returns nil,
    /// so the caller can reset `isCapturing` and break the re-render loop.
    func captureSnapshot(
        completion: @escaping @Sendable (UIImage) -> Void,
        onCaptureFailure: @escaping @Sendable () -> Void = {}
    ) {
        guard let arView else {
            DispatchQueue.main.async { onCaptureFailure() }
            return
        }
        arView.snapshot(saveToHDR: false) { image in
            if let image {
                completion(image)
            } else {
                // snapshot returned nil — completion must NOT be called (no valid image),
                // but we MUST notify the caller so it can reset isCapturing and stop the loop.
                DispatchQueue.main.async { onCaptureFailure() }
            }
        }
    }

    // MARK: - ARSessionDelegate

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        // Anchors added — entities are already placed via AnchorEntity
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        // Real-time update handled automatically by RealityKit's anchor tracking
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        Logger(subsystem: "com.ecrin.jewelry", category: "ar-tryon").error("Session failed: \(error.localizedDescription, privacy: .public)")
    }

    // MARK: - Helpers

    private func modeForJewelry(_ jewelry: JewelryItem) -> SessionMode {
        switch jewelry.category {
        case .earring, .necklace,
             .nosePiercing, .eyebrowPiercing, .lipPiercing, .tonguePiercing: return .face
        case .bracelet, .ring, .watch: return .body
        }
    }
}
