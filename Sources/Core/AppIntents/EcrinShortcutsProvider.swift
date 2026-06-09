import AppIntents

// MARK: - EcrinShortcutsProvider

struct EcrinShortcutsProvider: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenLookDuJourIntent(),
            phrases: [
                "Montre mon look du jour dans \(.applicationName)",
                "Look du jour \(.applicationName)",
                "Voir ma tenue du jour \(.applicationName)"
            ],
            shortTitle: "Look du Jour",
            systemImageName: "cloud.sun.fill"
        )

        AppShortcut(
            intent: OpenWardrobeIntent(),
            phrases: [
                "Ouvre ma garde-robe dans \(.applicationName)",
                "Garde-robe \(.applicationName)"
            ],
            shortTitle: "Garde-robe",
            systemImageName: "tshirt.fill"
        )

        AppShortcut(
            intent: OpenJewelryDetectionIntent(),
            phrases: [
                "Détecter un bijou avec \(.applicationName)",
                "Scanner un bijou \(.applicationName)"
            ],
            shortTitle: "Détecter bijou",
            systemImageName: "camera.viewfinder"
        )

        AppShortcut(
            intent: SuggestLookIntent(),
            phrases: [
                "Suggère-moi un look avec \(.applicationName)",
                "Idée de tenue \(.applicationName)"
            ],
            shortTitle: "Suggérer un look",
            systemImageName: "sparkles"
        )
    }
}
