import Foundation

/// Comptes fondateur / QA avec essayages illimités (client + serveur).
enum UnlimitedAccess {
    static let quotaDisplayValue = 999_999

    private static let emails: Set<String> = [
        "siamubee2@gmail.com",
        "monia.valenza@gmail.com",
    ]

    static func isUnlimited(email: String?) -> Bool {
        guard let email else { return false }
        return emails.contains(email.lowercased())
    }
}
