import SwiftUI

// MARK: - CitySearchSheet

struct CitySearchSheet: View {
    @Binding var cityText: String
    let isLoading: Bool
    let errorMessage: String?
    let onSubmit: () -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                EcrinColor.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: EcrinSpacing.lg) {
                    Text("Indiquez votre ville pour adapter le look à la météo locale.")
                        .font(EcrinFont.body)
                        .foregroundStyle(EcrinColor.textSecondary)

                    TextField("Ex. Lyon, Marseille…", text: $cityText)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($isFocused)
                        .padding(EcrinSpacing.md)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(EcrinColor.surface)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(EcrinColor.gold.opacity(0.35), lineWidth: 0.5)
                                }
                        }
                        .foregroundStyle(EcrinColor.textPrimary)
                        .font(EcrinFont.body)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(EcrinFont.caption)
                            .foregroundStyle(.orange)
                    }

                    GoldButton(title: isLoading ? "Recherche…" : "Valider la ville") {
                        onSubmit()
                    }
                    .disabled(cityText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                    .opacity(cityText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)

                    Spacer()
                }
                .padding(EcrinSpacing.lg)
            }
            .navigationTitle("Votre ville")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                        .foregroundStyle(EcrinColor.gold)
                }
            }
            .onAppear { isFocused = true }
        }
        .preferredColorScheme(.dark)
    }
}
