import Foundation
import UserNotifications

// MARK: - LookNotificationService

/// Gère la notification locale quotidienne "Look du Jour" à 8 h.
/// Usage :
///   await LookNotificationService.shared.requestAndSchedule()  // demande perm + programme
///   LookNotificationService.shared.cancel()                    // supprime le rappel
@MainActor
final class LookNotificationService: Sendable {

    static let shared = LookNotificationService()

    private let center = UNUserNotificationCenter.current()
    private let notificationID = "ecrin.look-du-jour.daily-8am"

    // UserDefaults key pour mémoriser le souhait utilisateur
    private let userWantsNotifKey = "ecrin.look-du-jour.notif.enabled"

    private init() {}

    // MARK: - Public API

    /// Demande la permission (si nécessaire) puis programme la notification.
    /// Retourne `true` si la notification a été programmée.
    @discardableResult
    func requestAndSchedule(hour: Int = 8, minute: Int = 0) async -> Bool {
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            guard (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) == true else {
                return false
            }
        case .authorized, .provisional, .ephemeral:
            break
        default:
            return false
        }

        await scheduleDailyLook(hour: hour, minute: minute)
        UserDefaults.standard.set(true, forKey: userWantsNotifKey)
        return true
    }

    /// Annule la notification en attente et mémorise le souhait.
    func cancel() {
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])
        UserDefaults.standard.set(false, forKey: userWantsNotifKey)
    }

    /// `true` si l'utilisateur a activé le rappel (basé sur UserDefaults).
    var userWantsNotification: Bool {
        UserDefaults.standard.bool(forKey: userWantsNotifKey)
    }

    /// Vérifie que la notification est réellement en attente dans le système.
    func checkIsScheduled() async -> Bool {
        let pending = await center.pendingNotificationRequests()
        return pending.contains { $0.identifier == notificationID }
    }

    // MARK: - Scheduling

    private func scheduleDailyLook(hour: Int, minute: Int) async {
        // Supprimer toute notification existante avant de reprogrammer
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])

        let content = UNMutableNotificationContent()
        content.title = "Votre Look du Jour est prêt ✨"
        content.body = "Découvrez la tenue du moment adaptée à la météo de votre ville."
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = "LOOK_DU_JOUR"

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        components.second = 0

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: true    // Tous les jours à la même heure
        )

        let request = UNNotificationRequest(
            identifier: notificationID,
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }

    // MARK: - Re-schedule on app foreground

    /// À appeler depuis ScenePhase.active pour s'assurer que la notification est toujours programmée.
    func rescheduleIfNeeded() async {
        guard userWantsNotification else { return }
        let isLive = await checkIsScheduled()
        if !isLive {
            await scheduleDailyLook(hour: 8, minute: 0)
        }
    }
}
