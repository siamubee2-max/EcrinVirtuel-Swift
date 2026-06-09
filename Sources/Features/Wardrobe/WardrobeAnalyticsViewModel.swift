import SwiftUI
import Charts

// MARK: - WardrobeAnalyticsViewModel

@Observable @MainActor final class WardrobeAnalyticsViewModel {

    // MARK: - Supporting Types

    struct GroupStat: Identifiable {
        let id = UUID()
        let group: FashionGroup
        let count: Int
        var label: String { group.rawValue }
        var color: Color { group.color }
    }

    struct ColorStat: Identifiable {
        let id = UUID()
        let name: String
        let count: Int
    }

    struct BrandStat: Identifiable {
        let id = UUID()
        let name: String
        let count: Int
    }

    struct MonthStat: Identifiable {
        let id = UUID()
        let label: String
        let count: Int
    }

    // MARK: - Published State

    private(set) var groupStats: [GroupStat] = []
    private(set) var topColors: [ColorStat] = []
    private(set) var topBrands: [BrandStat] = []
    private(set) var monthStats: [MonthStat] = []
    private(set) var totalItems: Int = 0
    private(set) var favoriteCount: Int = 0
    private(set) var totalValue: Double? = nil
    private(set) var avgPrice: Double? = nil

    // MARK: - Compute

    func compute(from items: [FashionItem]) {
        totalItems = items.count
        favoriteCount = items.filter(\.isFavorite).count

        // Group breakdown
        var groupCounts: [FashionGroup: Int] = [:]
        for item in items { groupCounts[item.category.group, default: 0] += 1 }
        groupStats = FashionGroup.allCases
            .map { GroupStat(group: $0, count: groupCounts[$0] ?? 0) }
            .filter { $0.count > 0 }

        // Top colors (max 6)
        var colorCounts: [String: Int] = [:]
        for item in items {
            if let c = item.color, !c.isEmpty {
                colorCounts[c, default: 0] += 1
            }
        }
        topColors = colorCounts
            .sorted { $0.value > $1.value }
            .prefix(6)
            .map { ColorStat(name: $0.key, count: $0.value) }

        // Top brands (max 5)
        var brandCounts: [String: Int] = [:]
        for item in items {
            if let b = item.brand, !b.isEmpty {
                brandCounts[b, default: 0] += 1
            }
        }
        topBrands = brandCounts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { BrandStat(name: $0.key, count: $0.value) }

        // Monthly additions — last 6 months
        let calendar = Calendar.current
        let now = Date.now
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        formatter.locale = Locale(identifier: "fr_FR")

        var mCounts: [Int: Int] = [:]
        for item in items {
            let diff = calendar.dateComponents([.month], from: item.createdAt, to: now).month ?? 999
            if (0..<6).contains(diff) { mCounts[diff, default: 0] += 1 }
        }
        monthStats = (0..<6).reversed().map { offset in
            let date = calendar.date(byAdding: .month, value: -offset, to: now) ?? now
            let lbl = formatter.string(from: date).capitalized
            return MonthStat(label: lbl, count: mCounts[offset] ?? 0)
        }

        // Price stats (only items with price)
        let prices = items.compactMap(\.price).filter { $0 > 0 }
        if prices.isEmpty {
            totalValue = nil
            avgPrice = nil
        } else {
            totalValue = prices.reduce(0, +)
            avgPrice = totalValue! / Double(prices.count)
        }
    }
}
