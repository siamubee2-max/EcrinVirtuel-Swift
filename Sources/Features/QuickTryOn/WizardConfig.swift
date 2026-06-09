// WizardConfig.swift — Static configuration for first-run wizard
// Path: Sources/Features/QuickTryOn/WizardConfig.swift

import Foundation

enum WizardConfig {
    /// The star jewelry item shown pre-selected in the wizard.
    /// Pick the one most likely to produce a stunning result.
    static let starJewelry = JewelryItem(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        name: "Créoles Quartz Rose",
        category: .earring,
        imageURL: nil,
        icon: "oval.fill",
        material: "Argent 925 · Quartz rose",
        prompt: "rose quartz drop earrings on ears, artisanal handmade, soft pink gemstone, silver setting, photorealistic luxury jewelry photography"
    )

    /// Curated picks shown in step 2 of wizard (star first, then 3 others)
    static let curatedPicks: [JewelryItem] = [
        starJewelry,
        JewelryItem(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            name: "Sautoir Pierre de Lune",
            category: .necklace,
            imageURL: nil,
            icon: "moonphase.last.quarter",
            material: "Argent 925 · Pierre de lune",
            prompt: "moonstone pendant long necklace on neck, bohemian artisanal style, photorealistic"
        ),
        JewelryItem(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            name: "Bague Améthyste",
            category: .ring,
            imageURL: nil,
            icon: "hexagon.fill",
            material: "Laiton doré · Améthyste",
            prompt: "raw amethyst crystal ring on finger, artisanal boho style, purple gemstone, photorealistic"
        ),
        JewelryItem(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            name: "Bracelet Labradorite",
            category: .bracelet,
            imageURL: nil,
            icon: "square.on.circle",
            material: "Cuir · Labradorite",
            prompt: "labradorite wrap bracelet on wrist, bohemian wellness style, photorealistic"
        ),
    ]

    static let userDefaultsKey = "hasCompletedFirstRun"

    /// 2 bijoux proposés dans le nudge post-résultat.
    static var nudgePicks: [JewelryItem] {
        Array(curatedPicks.dropFirst().prefix(2))
    }
}
