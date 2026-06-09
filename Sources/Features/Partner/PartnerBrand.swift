import Foundation

// MARK: - PartnerBrand

struct PartnerBrand: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let description: String
    let logoURL: URL?
    let websiteURL: URL?
    let country: String
    let category: BrandCategory
    let isVerified: Bool
    let commissionRate: Double      // e.g. 0.15 = 15 %
    let monthlyFee: Double          // EUR
    var catalog: [JewelryItem]
    var totalSales: Double          // EUR cumul
    let joinedAt: Date

    // MARK: - Brand category

    enum BrandCategory: String, Codable, CaseIterable, Identifiable {
        case artisanal  = "Artisanal"
        case luxe       = "Luxe"
        case createur   = "Créateur"
        case vintage    = "Vintage"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .artisanal: return "hands.and.sparkles"
            case .luxe:      return "crown"
            case .createur:  return "paintpalette"
            case .vintage:   return "clock.arrow.circlepath"
            }
        }
    }

    // MARK: - Computed helpers

    /// Formatted commission string, e.g. "15 %"
    var commissionDisplay: String {
        let pct = Int((commissionRate * 100).rounded())
        return "\(pct) %"
    }

    /// Formatted monthly fee string, e.g. "199 €"
    var monthlyFeeDisplay: String {
        String(format: "%.0f €", monthlyFee)
    }

    /// Formatted total sales string
    var totalSalesDisplay: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: totalSales)) ?? "\(totalSales) €"
    }

    /// Short country flag + name for UI display
    var countryDisplay: String { country }
}

// MARK: - Hashable conformance (identity-based)
// JewelryItem is not yet Hashable, so we implement hash(into:) manually.
extension PartnerBrand {
    static func == (lhs: PartnerBrand, rhs: PartnerBrand) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
