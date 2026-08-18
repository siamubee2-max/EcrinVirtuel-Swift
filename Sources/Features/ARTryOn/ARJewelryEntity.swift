import Foundation
import RealityKit
import ARKit

// MARK: - AR Jewelry Entity Factory

// ModelEntity creation is MainActor-isolated in modern RealityKit; keeping the
// whole factory on the main actor lets the non-Sendable [any Material] arrays
// stay within one isolation domain (all callers are AR view code on MainActor).
@MainActor
enum ARJewelryEntity {

    // MARK: - Gold Material

    static func goldMaterial() -> SimpleMaterial {
        var material = SimpleMaterial()
        material.metallic = .float(1.0)
        material.roughness = .float(0.1)
        material.color = .init(tint: .init(red: 0.80, green: 0.55, blue: 0.02, alpha: 1.0))
        return material
    }

    // MARK: - Earrings (2 flat spheres at left/right ear anchors)

    static func makeEarrings() -> (left: ModelEntity, right: ModelEntity) {
        let material = goldMaterial()

        // Flattened sphere simulating a hoop earring
        let leftMesh = MeshResource.generateSphere(radius: 0.012)
        let left = ModelEntity(mesh: leftMesh, materials: [material])
        left.scale = SIMD3<Float>(1.0, 0.25, 1.0) // flatten vertically

        let rightMesh = MeshResource.generateSphere(radius: 0.012)
        let right = ModelEntity(mesh: rightMesh, materials: [material])
        right.scale = SIMD3<Float>(1.0, 0.25, 1.0)

        return (left, right)
    }

    // MARK: - Necklace (arc of spheres along neckline)

    static func makeNecklace() -> ModelEntity {
        let material = goldMaterial()
        let container = ModelEntity()

        let beadCount = 11
        let arcRadius: Float = 0.065
        let beadRadius: Float = 0.004

        for i in 0..<beadCount {
            // Arc from -70° to +70° (front of neck)
            let fraction = Float(i) / Float(beadCount - 1)
            let angle = (-70 + fraction * 140) * (.pi / 180)
            let x = arcRadius * sin(angle)
            let y: Float = -0.01 // slightly below chin
            let z = arcRadius * cos(angle) - arcRadius

            let bead = ModelEntity(
                mesh: .generateSphere(radius: beadRadius),
                materials: [material]
            )
            bead.position = SIMD3<Float>(x, y, z)
            container.addChild(bead)
        }

        // Central pendant
        let pendant = ModelEntity(
            mesh: .generateSphere(radius: 0.008),
            materials: [material]
        )
        pendant.position = SIMD3<Float>(0, -0.025, -arcRadius)
        container.addChild(pendant)

        return container
    }

    // MARK: - Bracelet (torus-like ring of spheres)

    static func makeBracelet() -> ModelEntity {
        let material = goldMaterial()
        let container = ModelEntity()

        let beadCount = 16
        let ringRadius: Float = 0.032

        for i in 0..<beadCount {
            let angle = Float(i) / Float(beadCount) * 2 * .pi
            let x = ringRadius * cos(angle)
            let y = ringRadius * sin(angle)

            let bead = ModelEntity(
                mesh: .generateSphere(radius: 0.004),
                materials: [material]
            )
            bead.position = SIMD3<Float>(x, y, 0)
            container.addChild(bead)
        }

        return container
    }

    // MARK: - Ring (small torus)

    static func makeRing() -> ModelEntity {
        let material = goldMaterial()

        // Use a thin cylinder as ring band approximation
        let mesh = MeshResource.generateCylinder(height: 0.004, radius: 0.009)
        let ring = ModelEntity(mesh: mesh, materials: [material])
        return ring
    }

    // MARK: - Factory by category

    static func makeEntity(for category: JewelryCategory) -> ModelEntity {
        switch category {
        case .earring:
            // Returns left earring; right is created separately
            let (left, _) = makeEarrings()
            return left
        case .necklace:
            return makeNecklace()
        case .bracelet:
            return makeBracelet()
        case .ring:
            return makeRing()
        case .watch:
            return makeBracelet() // reuse bracelet geometry
        case .nosePiercing, .eyebrowPiercing, .lipPiercing, .tonguePiercing:
            let (left, _) = makeEarrings() // AR piercings not yet implemented; use earring geometry as placeholder
            return left
        }
    }
}

// MARK: - JewelryCategory local alias

typealias JewelryCategory = JewelryItem.JewelryCategory
