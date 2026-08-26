import SwiftUI
import Charts

// MARK: - WardrobeAnalyticsView

struct WardrobeAnalyticsView: View {

    let items: [FashionItem]
    @State private var vm = WardrobeAnalyticsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                EcrinColor.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: EcrinSpacing.lg) {
                        summaryCard
                        groupDonutSection
                        if !vm.topColors.isEmpty { colorsSection }
                        if !vm.topBrands.isEmpty { brandsSection }
                        monthlySection
                        if vm.totalValue != nil { priceSection }
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, EcrinSpacing.lg)
                    .padding(.top, EcrinSpacing.md)
                }
            }
            .navigationTitle(L10n.WardrobeUI.analytics)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.close) { dismiss() }
                        .font(EcrinFont.label)
                        .foregroundStyle(EcrinColor.gold)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { vm.compute(from: items) }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        GlassCard(cornerRadius: 20) {
            HStack(spacing: 0) {
                summaryCell(value: "\(vm.totalItems)", label: "Pièces")
                divider
                summaryCell(value: "\(vm.favoriteCount)", label: "Favoris")
                divider
                summaryCell(
                    value: "\(vm.groupStats.first(where: { $0.group == .jewelry })?.count ?? 0)",
                    label: "Bijoux"
                )
                divider
                summaryCell(
                    value: "\(vm.groupStats.first(where: { $0.group == .clothing })?.count ?? 0)",
                    label: "Vêtements"
                )
            }
            .padding(.vertical, EcrinSpacing.md)
        }
    }

    private func summaryCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(EcrinFont.sans(24, weight: .bold))
                .foregroundStyle(EcrinColor.gold)
            Text(label)
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(EcrinColor.glassStroke)
            .frame(width: 0.5, height: 36)
    }

    // MARK: - Group Donut

    private var groupDonutSection: some View {
        GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: EcrinSpacing.md) {
                sectionTitle(L10n.WardrobeUI.breakdownByGroup)

                Chart(vm.groupStats) { stat in
                    SectorMark(
                        angle: .value("Pièces", stat.count),
                        innerRadius: .ratio(0.6),
                        angularInset: 2
                    )
                    .foregroundStyle(stat.color)
                    .cornerRadius(4)
                }
                .frame(height: 200)
                .chartLegend(.hidden)

                // Legend
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(vm.groupStats) { stat in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(stat.color)
                                .frame(width: 8, height: 8)
                            Text("\(stat.label) (\(stat.count))")
                                .font(EcrinFont.caption)
                                .foregroundStyle(EcrinColor.textSecondary)
                            Spacer()
                        }
                    }
                }
            }
            .padding(EcrinSpacing.md)
        }
    }

    // MARK: - Colors

    private var colorsSection: some View {
        GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: EcrinSpacing.md) {
                sectionTitle(L10n.WardrobeUI.dominantColors)

                let maxCount = vm.topColors.map(\.count).max() ?? 1
                ForEach(vm.topColors) { stat in
                    HStack(spacing: EcrinSpacing.sm) {
                        Text(stat.name)
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.textPrimary)
                            .frame(width: 90, alignment: .leading)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(EcrinColor.surface)
                                    .frame(height: 8)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(EcrinColor.gold.opacity(0.7))
                                    .frame(width: geo.size.width * CGFloat(stat.count) / CGFloat(maxCount), height: 8)
                            }
                        }
                        .frame(height: 8)

                        Text("\(stat.count)")
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.textMuted)
                            .frame(width: 24, alignment: .trailing)
                    }
                }
            }
            .padding(EcrinSpacing.md)
        }
    }

    // MARK: - Brands

    private var brandsSection: some View {
        GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: EcrinSpacing.md) {
                sectionTitle(L10n.WardrobeUI.topBrands)

                let maxCount = vm.topBrands.map(\.count).max() ?? 1
                ForEach(vm.topBrands) { stat in
                    HStack(spacing: EcrinSpacing.sm) {
                        Text(stat.name)
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.textPrimary)
                            .lineLimit(1)
                            .frame(width: 100, alignment: .leading)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(EcrinColor.surface)
                                    .frame(height: 8)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(hex: "#6366F1").opacity(0.7))
                                    .frame(width: geo.size.width * CGFloat(stat.count) / CGFloat(maxCount), height: 8)
                            }
                        }
                        .frame(height: 8)

                        Text("\(stat.count)")
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.textMuted)
                            .frame(width: 24, alignment: .trailing)
                    }
                }
            }
            .padding(EcrinSpacing.md)
        }
    }

    // MARK: - Monthly

    private var monthlySection: some View {
        GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: EcrinSpacing.md) {
                sectionTitle(L10n.WardrobeUI.additionsSixMonths)

                Chart(vm.monthStats) { stat in
                    BarMark(
                        x: .value("Mois", stat.label),
                        y: .value("Pièces", stat.count)
                    )
                    .foregroundStyle(EcrinColor.gold.opacity(0.8))
                    .cornerRadius(4)
                }
                .frame(height: 140)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                        AxisValueLabel()
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.textMuted)
                    }
                }
                .chartXAxis {
                    AxisMarks {
                        AxisValueLabel()
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.textMuted)
                    }
                }
            }
            .padding(EcrinSpacing.md)
        }
    }

    // MARK: - Price

    private var priceSection: some View {
        GlassCard(cornerRadius: 20) {
            HStack(spacing: 0) {
                if let total = vm.totalValue {
                    summaryCell(value: formattedPrice(total), label: "Valeur totale")
                }
                if vm.totalValue != nil { divider }
                if let avg = vm.avgPrice {
                    summaryCell(value: formattedPrice(avg), label: "Prix moyen")
                }
            }
            .padding(.vertical, EcrinSpacing.md)
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(EcrinFont.sectionHead)
            .foregroundStyle(EcrinColor.textPrimary)
    }

    private func formattedPrice(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "EUR"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "\(Int(value)) €"
    }
}
