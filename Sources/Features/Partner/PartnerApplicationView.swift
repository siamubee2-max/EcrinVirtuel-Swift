import SwiftUI

// MARK: - PartnerApplicationView
// Formulaire de candidature pour les créateurs artisans qui souhaitent
// rejoindre L'Écrin Virtuel en tant que boutique partenaire.

struct PartnerApplicationView: View {

    @Environment(\.dismiss) private var dismiss

    // MARK: - Form fields
    @State private var brandName    = ""
    @State private var category     = PartnerBrand.BrandCategory.artisanal
    @State private var country      = ""
    @State private var contactEmail = ""
    @State private var websiteURL   = ""
    @State private var instagram    = ""
    @State private var description  = ""

    // MARK: - State
    @State private var isSubmitting = false
    @State private var submitted    = false
    @State private var errorMessage: String?

    private var isValid: Bool {
        !brandName.trimmingCharacters(in: .whitespaces).isEmpty
        && !contactEmail.trimmingCharacters(in: .whitespaces).isEmpty
        && contactEmail.contains("@")
        && !country.trimmingCharacters(in: .whitespaces).isEmpty
        && !description.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EcrinColor.background.ignoresSafeArea()

                if submitted {
                    successView
                } else {
                    formScrollView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(EcrinColor.textSecondary)
                            .padding(8)
                            .background(EcrinColor.glassFill, in: Circle())
                            .overlay(Circle().strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }

    // MARK: - Form

    private var formScrollView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: EcrinSpacing.xl) {
                formHeader
                mandatorySection
                contactSection
                onlineSection
                pitchSection
                submitButton
                    .padding(.bottom, EcrinSpacing.xxl)
            }
            .padding(.horizontal, EcrinSpacing.lg)
            .padding(.top, EcrinSpacing.md)
        }
    }

    // MARK: - Header

    private var formHeader: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
            Label(L10n.PartnerUI.becomePartner, systemImage: "hands.and.sparkles")
                .font(EcrinFont.label)
                .kerning(2)
                .foregroundStyle(EcrinColor.gold)

            Text(L10n.PartnerUI.joinEcrin)
                .font(EcrinFont.heroTitle)
                .foregroundStyle(EcrinColor.textPrimary)

            Text(L10n.PartnerUI.applyIntro)
                .font(EcrinFont.body)
                .foregroundStyle(EcrinColor.textSecondary)
                .lineSpacing(4)
        }
        .padding(.top, EcrinSpacing.sm)
    }

    // MARK: - Sections

    private var mandatorySection: some View {
        formSection(title: "VOTRE MARQUE", icon: "tag") {
            VStack(spacing: EcrinSpacing.md) {
                // Nom de la marque
                formField(
                    label: "Nom de la marque *",
                    placeholder: "ex : Moni'attitude",
                    text: $brandName,
                    keyboardType: .default
                )

                // Catégorie
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.PartnerUI.categoryField)
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textMuted)
                        .kerning(0.5)

                    Picker("Catégorie", selection: $category) {
                        ForEach(PartnerBrand.BrandCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(EcrinColor.gold)
                    .padding(.horizontal, EcrinSpacing.md)
                    .padding(.vertical, EcrinSpacing.sm)
                    .background(EcrinColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
                    )
                }

                // Pays
                formField(
                    label: "Pays *",
                    placeholder: "ex : Belgique",
                    text: $country,
                    keyboardType: .default
                )
            }
        }
    }

    private var contactSection: some View {
        formSection(title: "CONTACT", icon: "envelope") {
            VStack(spacing: EcrinSpacing.md) {
                formField(
                    label: "Email de contact *",
                    placeholder: "votre@adresse.com",
                    text: $contactEmail,
                    keyboardType: .emailAddress
                )
            }
        }
    }

    private var onlineSection: some View {
        formSection(title: "PRÉSENCE EN LIGNE", icon: "globe") {
            VStack(spacing: EcrinSpacing.md) {
                formField(
                    label: "Site web",
                    placeholder: "https://votreboutique.com",
                    text: $websiteURL,
                    keyboardType: .URL
                )
                formField(
                    label: "Instagram",
                    placeholder: "@votrecompte",
                    text: $instagram,
                    keyboardType: .default
                )
            }
        }
    }

    private var pitchSection: some View {
        formSection(title: "VOTRE PITCH", icon: "text.alignleft") {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.PartnerUI.describeCreativeUniverse)
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textMuted)
                    .kerning(0.5)

                TextEditor(text: $description)
                    .font(EcrinFont.body)
                    .foregroundStyle(EcrinColor.textPrimary)
                    .tint(EcrinColor.gold)
                    .scrollContentBackground(.hidden)
                    .background(EcrinColor.surface)
                    .frame(minHeight: 110)
                    .padding(EcrinSpacing.md)
                    .background(EcrinColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
                    )

                Text(L10n.PartnerUI.describeHint)
                    .font(.system(size: 11))
                    .foregroundStyle(EcrinColor.textMuted)
            }
        }
    }

    // MARK: - Submit

    private var submitButton: some View {
        VStack(spacing: EcrinSpacing.md) {
            if let err = errorMessage {
                HStack(spacing: EcrinSpacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(err)
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textSecondary)
                }
                .padding(EcrinSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Button(action: submit) {
                HStack(spacing: EcrinSpacing.sm) {
                    if isSubmitting {
                        ProgressView().tint(EcrinColor.background).scaleEffect(0.85)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    Text(isSubmitting ? "Envoi en cours…" : "Soumettre ma candidature")
                        .font(EcrinFont.cta)
                        .kerning(1.5)
                }
                .foregroundStyle(isValid ? EcrinColor.background : EcrinColor.textMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, EcrinSpacing.md)
                .background(isValid ? EcrinColor.gold : EcrinColor.gold.opacity(0.25))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!isValid || isSubmitting)
        }
    }

    // MARK: - Success

    private var successView: some View {
        VStack(spacing: EcrinSpacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(EcrinColor.gold.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(EcrinColor.gold)
            }

            VStack(spacing: EcrinSpacing.md) {
                Text(L10n.PartnerUI.applicationSent)
                    .font(EcrinFont.sectionHead)
                    .foregroundStyle(EcrinColor.textPrimary)

                Text("Merci pour votre intérêt. Notre équipe examinera votre dossier et vous contactera à **\(contactEmail)** sous 72 heures.")
                    .font(EcrinFont.body)
                    .foregroundStyle(EcrinColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, EcrinSpacing.xl)

            GoldButton(title: L10n.Common.close) { dismiss() }
                .padding(.horizontal, EcrinSpacing.xl)

            Spacer()
        }
    }

    // MARK: - Helpers

    private func formSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.md) {
            HStack(spacing: EcrinSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(EcrinColor.gold)
                Text(title)
                    .font(EcrinFont.label)
                    .kerning(2)
                    .foregroundStyle(EcrinColor.textMuted)
            }

            GlassCard(cornerRadius: 16) {
                content()
                    .padding(EcrinSpacing.md)
            }
        }
    }

    private func formField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textMuted)
                .kerning(0.5)

            TextField(placeholder, text: text)
                .font(EcrinFont.body)
                .foregroundStyle(EcrinColor.textPrimary)
                .tint(EcrinColor.gold)
                .keyboardType(keyboardType)
                .autocorrectionDisabled()
                .textInputAutocapitalization(keyboardType == .emailAddress || keyboardType == .URL ? .never : .sentences)
                .padding(EcrinSpacing.md)
                .background(EcrinColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
                )
        }
    }

    // MARK: - Submit action

    private func submit() {
        guard isValid else { return }
        isSubmitting = true
        errorMessage = nil

        Task {
            defer { isSubmitting = false }
            do {
                struct ApplicationRow: Encodable {
                    let brand_name:    String
                    let category:      String
                    let country:       String
                    let contact_email: String
                    let website_url:   String?
                    let instagram:     String?
                    let description:   String
                    let user_id:       String?
                }

                let userId = try? await SupabaseService.shared.client.auth.session.user.id.uuidString

                let row = ApplicationRow(
                    brand_name:    brandName.trimmingCharacters(in: .whitespaces),
                    category:      category.rawValue,
                    country:       country.trimmingCharacters(in: .whitespaces),
                    contact_email: contactEmail.trimmingCharacters(in: .whitespaces).lowercased(),
                    website_url:   websiteURL.trimmingCharacters(in: .whitespaces).isEmpty ? nil : websiteURL.trimmingCharacters(in: .whitespaces),
                    instagram:     instagram.trimmingCharacters(in: .whitespaces).isEmpty ? nil : instagram.trimmingCharacters(in: .whitespaces),
                    description:   description.trimmingCharacters(in: .whitespaces),
                    user_id:       userId
                )

                try await SupabaseService.shared.client
                    .from(SupabaseService.partnerApplications)
                    .insert(row)
                    .execute()

                withAnimation(EcrinAnimation.springSnap) {
                    submitted = true
                }
            } catch {
                errorMessage = "Envoi échoué. Vérifiez votre connexion et réessayez."
            }
        }
    }
}
