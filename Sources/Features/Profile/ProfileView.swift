import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var showStoneGuide = false
    @State private var showDressing = false
    @State private var showDeleteConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deleteError: String?
    @State private var showCreditsShop = false
    @State private var showSubscription = false
    @State private var remainingCredits: Int? = nil
    @State private var showRevokeConsentConfirmation = false

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: EcrinSpacing.xl) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PROFIL")
                            .font(EcrinFont.label)
                            .kerning(3)
                            .foregroundStyle(EcrinColor.gold)
                        Text("Mon Espace")
                            .font(EcrinFont.sectionHead)
                            .foregroundStyle(EcrinColor.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, EcrinSpacing.lg)
                    .padding(.top, EcrinSpacing.lg)

                    // MARK: - Crédits / Abonnement
                    let creditsEmpty = remainingCredits == 0
                    if creditsEmpty {
                        // Priorité : abonnement quand crédits épuisés
                        Button { showSubscription = true } label: {
                            HStack(spacing: EcrinSpacing.md) {
                                ZStack {
                                    Circle()
                                        .fill(EcrinColor.gold.opacity(0.18))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 18, weight: .thin))
                                        .foregroundStyle(EcrinColor.gold)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Essais épuisés")
                                        .font(EcrinFont.cardTitle)
                                        .foregroundStyle(EcrinColor.textPrimary)
                                    Text("Passez à Premium pour continuer")
                                        .font(EcrinFont.caption)
                                        .foregroundStyle(EcrinColor.gold.opacity(0.85))
                                }
                                Spacer()
                                Text("S'abonner")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(EcrinColor.background)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(EcrinColor.gold)
                                    .clipShape(Capsule())
                            }
                            .padding(EcrinSpacing.lg)
                            .background {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(EcrinColor.gold.opacity(0.08))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .strokeBorder(EcrinColor.gold.opacity(0.4), lineWidth: 1)
                                    }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("profile.premium")
                        .padding(.horizontal, EcrinSpacing.lg)

                        // Secondaire : achat à l'unité
                        Button { showCreditsShop = true } label: {
                            Text("Ou acheter des essais à l'unité →")
                                .font(EcrinFont.caption)
                                .foregroundStyle(EcrinColor.textMuted)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, EcrinSpacing.lg)
                    } else {
                        // Crédits restants — recharge secondaire
                        Button { showCreditsShop = true } label: {
                            HStack(spacing: EcrinSpacing.md) {
                                ZStack {
                                    Circle()
                                        .fill(EcrinColor.gold.opacity(0.12))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 18, weight: .thin))
                                        .foregroundStyle(EcrinColor.gold)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Essais disponibles")
                                        .font(EcrinFont.cardTitle)
                                        .foregroundStyle(EcrinColor.textPrimary)
                                    if let credits = remainingCredits {
                                        Text("\(credits) essai\(credits != 1 ? "s" : "") restant\(credits != 1 ? "s" : "")")
                                            .font(EcrinFont.caption)
                                            .foregroundStyle(credits > 5 ? EcrinColor.textSecondary : .orange.opacity(0.9))
                                    } else {
                                        Text(L10n.Common.loading)
                                            .font(EcrinFont.caption)
                                            .foregroundStyle(EcrinColor.textMuted)
                                    }
                                }
                                Spacer()
                                Text("Recharger")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(EcrinColor.background)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(EcrinColor.gold)
                                    .clipShape(Capsule())
                            }
                            .padding(EcrinSpacing.lg)
                            .background {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(EcrinColor.glassFill)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .strokeBorder(EcrinColor.gold.opacity(0.25), lineWidth: 0.5)
                                    }
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, EcrinSpacing.lg)
                        .accessibilityLabel("Essais disponibles, \(remainingCredits.map { "\($0) restants" } ?? ""). Ouvre la boutique de recharge")
                    }

                    // Mon Dressing — galerie persistante des essayages générés
                    Button {
                        showDressing = true
                    } label: {
                        HStack(spacing: EcrinSpacing.md) {
                            ZStack {
                                Circle()
                                    .fill(EcrinColor.gold.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "sparkles.rectangle.stack")
                                    .font(.system(size: 18, weight: .thin))
                                    .foregroundStyle(EcrinColor.gold)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Mes créations")
                                    .font(EcrinFont.cardTitle)
                                    .foregroundStyle(EcrinColor.textPrimary)
                                Text("Tous vos essayages sauvegardés")
                                    .font(EcrinFont.caption)
                                    .foregroundStyle(EcrinColor.textSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .light))
                                .foregroundStyle(EcrinColor.textMuted)
                        }
                        .padding(EcrinSpacing.lg)
                        .background {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(EcrinColor.glassFill)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
                                }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, EcrinSpacing.lg)

                    // Parrainage — « Invitez une amie, 3 essais offerts chacune »
                    if let userID = appState.currentUser?.id {
                        ShareLink(
                            item: URL(string: "https://ecrin.app/ecrin/ref/\(userID.uuidString)")!,
                            message: Text("Essaie L'Écrin Virtuel — l'essayage de bijoux par IA. Avec mon lien, on gagne 3 essais offerts chacune ✨")
                        ) {
                            HStack(spacing: EcrinSpacing.md) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: "#2E86AB").opacity(0.15))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "person.badge.plus")
                                        .font(.system(size: 18, weight: .thin))
                                        .foregroundStyle(Color(hex: "#2E86AB"))
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Invitez une amie")
                                        .font(EcrinFont.cardTitle)
                                        .foregroundStyle(EcrinColor.textPrimary)
                                    Text("3 essais offerts pour elle et pour vous")
                                        .font(EcrinFont.caption)
                                        .foregroundStyle(EcrinColor.textSecondary)
                                }

                                Spacer()

                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 14, weight: .light))
                                    .foregroundStyle(EcrinColor.textMuted)
                            }
                            .padding(EcrinSpacing.lg)
                            .background {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(EcrinColor.glassFill)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
                                    }
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, EcrinSpacing.lg)
                    }

                    // Stone Guide entry point
                    Button {
                        showStoneGuide = true
                    } label: {
                        HStack(spacing: EcrinSpacing.md) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "#9B59B6").opacity(0.15))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "diamond.fill")
                                    .font(.system(size: 18, weight: .thin))
                                    .foregroundStyle(Color(hex: "#9B59B6"))
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Guide des Pierres")
                                    .font(EcrinFont.cardTitle)
                                    .foregroundStyle(EcrinColor.textPrimary)
                                Text("Lithothérapie & vertus")
                                    .font(EcrinFont.caption)
                                    .foregroundStyle(EcrinColor.textSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .light))
                                .foregroundStyle(EcrinColor.textMuted)
                        }
                        .padding(EcrinSpacing.lg)
                        .background {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(EcrinColor.glassFill)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
                                }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, EcrinSpacing.lg)

                    Spacer()

                    // MARK: - Consentement IA (RGPD — droit de retrait)
                    if AIConsentModal.isGranted {
                        Button("Retirer mon consentement IA") {
                            showRevokeConsentConfirmation = true
                        }
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textMuted)
                        .padding(.horizontal, EcrinSpacing.lg)
                    }

                    // MARK: - Déconnexion + Suppression (Apple Guideline 5.1.1(v) — obligatoire)
                    VStack(spacing: EcrinSpacing.sm) {
                        Button("Se déconnecter") {
                            Task {
                                try? await SupabaseService.shared.signOut()
                                appState.signOut()
                            }
                        }
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textSecondary)
                        .accessibilityIdentifier("profile.signout")

                        if let error = deleteError {
                            Text(error)
                                .font(EcrinFont.caption)
                                .foregroundStyle(.red.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, EcrinSpacing.lg)
                        }

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            if isDeletingAccount {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .tint(.red.opacity(0.7))
                                        .scaleEffect(0.8)
                                    Text("Suppression…")
                                }
                            } else {
                                Text("Supprimer mon compte")
                            }
                        }
                        .font(EcrinFont.caption)
                        .foregroundStyle(.red.opacity(0.7))
                        .disabled(isDeletingAccount)
                    }
                    .padding(.bottom, 60)
                }
            }
        }
        .sheet(isPresented: $showStoneGuide) {
            StoneGuideView()
        }
        .sheet(isPresented: $showDressing) {
            DressingView()
        }
        .sheet(isPresented: $showSubscription) {
            PaywallView()
        }
        .sheet(isPresented: $showCreditsShop, onDismiss: {
            Task { remainingCredits = try? await SupabaseService.shared.fetchRemainingCredits() }
        }) {
            CreditsPackView()
        }
        .task {
            if AppLaunchEnvironment.isUITesting {
                remainingCredits = AppLaunchEnvironment.mockCredits
            } else if let credits = try? await SupabaseService.shared.fetchRemainingCredits() {
                remainingCredits = credits
            } else {
                // Pas de session (ou fetch échoué) : on affiche le solde local
                // plutôt qu'un "Chargement…" qui ne se résout jamais.
                await CreditsManager.shared.sync()
                remainingCredits = CreditsManager.shared.remaining
            }
        }
        .confirmationDialog(
            "Retirer votre consentement IA ?",
            isPresented: $showRevokeConsentConfirmation,
            titleVisibility: .visible
        ) {
            Button("Retirer le consentement", role: .destructive) {
                AIConsentModal.revoke()
            }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text("Vos photos ne seront plus envoyées à Google ou OpenAI. Vous pouvez le réaccorder lors du prochain essayage.")
        }
        .confirmationDialog(
            "Supprimer définitivement votre compte ?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Supprimer mon compte", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text("Toutes vos données seront supprimées définitivement : looks sauvegardés, historique d'essayage et informations personnelles. Cette action est irréversible.")
        }
    }

    private func deleteAccount() async {
        isDeletingAccount = true
        deleteError = nil
        do {
            try await SupabaseService.shared.deleteAccount()
            appState.signOut()
        } catch {
            deleteError = "La suppression a échoué. Contactez support@inferencevision.store pour procéder manuellement."
        }
        isDeletingAccount = false
    }
}
