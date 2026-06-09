import Foundation

// MARK: - Secrets — loaded from Info.plist / environment
// SECURITY: Only public/client-safe keys belong here.
// OPENAI_API_KEY and FAL_API_KEY must NEVER be in the IPA — they live in Supabase Edge Function secrets.
enum Secrets {
    static var revenueCatAPIKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_IOS_KEY") as? String, !key.isEmpty else {
            assertionFailure("REVENUECAT_IOS_KEY manquante dans Info.plist")
            return ""
        }
        return key
    }

    static var supabaseURL: String {
        guard let url = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String, !url.isEmpty else {
            assertionFailure("SUPABASE_URL manquante dans Info.plist")
            return ""
        }
        return url
    }

    static var supabaseAnonKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String, !key.isEmpty else {
            assertionFailure("SUPABASE_ANON_KEY manquante dans Info.plist")
            return ""
        }
        return key
    }
}
