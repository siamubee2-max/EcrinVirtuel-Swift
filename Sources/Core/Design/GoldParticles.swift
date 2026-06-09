import SwiftUI

// MARK: - Composant partagé — particules dorées (utilisé par WeddingMode + LevelUp)

struct GoldParticlesCanvas: View {
    @State private var particles: [GoldParticle] = []

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { _ in
                Canvas { ctx, size in
                    for particle in particles {
                        let age = particle.age
                        guard age < particle.lifetime else { continue }
                        let t = age / particle.lifetime
                        let alpha = t < 0.1 ? t / 0.1 : (1 - t)
                        let x = particle.origin.x + particle.velocity.x * age * 60
                        let y = particle.origin.y + particle.velocity.y * age * 60 + 0.5 * 200 * age * age
                        let sz = particle.size * (1 - t * 0.5)

                        ctx.opacity = alpha
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: x - sz/2, y: y - sz/2, width: sz, height: sz)),
                            with: particle.isGold
                                ? .color(EcrinColor.gold.opacity(alpha))
                                : .color(EcrinColor.goldLight.opacity(alpha * 0.7))
                        )
                    }
                }
                .onAppear { spawnBurst(in: geo.size) }
                .onReceive(Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()) { _ in
                    updateParticles()
                    if particles.count < 60 { spawnParticle(in: geo.size) }
                }
            }
        }
    }

    private func spawnBurst(in size: CGSize) {
        let cx = size.width / 2
        let cy = size.height * 0.35
        for _ in 0..<60 {
            particles.append(.burst(cx: cx, cy: cy))
        }
    }

    private func spawnParticle(in size: CGSize) {
        particles.append(GoldParticle(
            origin: CGPoint(x: .random(in: 0...size.width), y: .random(in: 0...size.height * 0.5)),
            velocity: CGPoint(x: .random(in: -0.3...0.3), y: .random(in: -1.5 ... -0.5)),
            size: .random(in: 2...5),
            lifetime: .random(in: 1.2...2.5),
            age: 0,
            isGold: Bool.random()
        ))
    }

    private func updateParticles() {
        particles = particles.compactMap { p in
            var mp = p; mp.age += 0.016
            return mp.age < mp.lifetime ? mp : nil
        }
    }
}

struct GoldParticle {
    var origin: CGPoint
    var velocity: CGPoint
    var size: CGFloat
    var lifetime: CGFloat
    var age: CGFloat
    var isGold: Bool

    static func burst(cx: CGFloat, cy: CGFloat) -> GoldParticle {
        let angle = CGFloat.random(in: 0...(2 * .pi))
        let speed = CGFloat.random(in: 0.5...3.5)
        return GoldParticle(
            origin: CGPoint(x: cx + .random(in: -20...20), y: cy + .random(in: -20...20)),
            velocity: CGPoint(x: cos(angle) * speed, y: sin(angle) * speed - 1.5),
            size: .random(in: 3...8),
            lifetime: .random(in: 0.8...2.2),
            age: 0,
            isGold: Double.random(in: 0...1) > 0.4
        )
    }
}
