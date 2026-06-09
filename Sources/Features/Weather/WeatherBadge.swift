import SwiftUI

// MARK: - WeatherBadge

struct WeatherBadge: View {
    let snapshot: WeatherSnapshot
    var showsCity: Bool = true

    var body: some View {
        HStack(spacing: 6) {
            Text(snapshot.condition.emoji)
                .font(.system(size: 14))
            if showsCity, let city = snapshot.cityName ?? LocationService.shared.cityName {
                Text(city)
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textSecondary)
                Text("·")
                    .foregroundStyle(EcrinColor.textMuted)
            }
            Text(snapshot.formattedTemp)
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textPrimary)
            Text("·")
                .foregroundStyle(EcrinColor.textMuted)
            Text(snapshot.condition.label)
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(EcrinColor.gold.opacity(0.08))
                .overlay {
                    Capsule()
                        .strokeBorder(EcrinColor.gold.opacity(0.25), lineWidth: 0.5)
                }
        }
    }
}
