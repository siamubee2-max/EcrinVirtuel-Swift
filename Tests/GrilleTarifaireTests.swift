import XCTest
@testable import EcrinVirtuel

/// L'échelle tarifaire a été cassée deux fois : Elite mensuel dominé par le
/// pack Diamant (même prix, moins de crédits), et un badge « meilleure valeur »
/// posé sur la formule qui n'était pas la meilleure. Les deux étaient
/// vérifiables à la calculette depuis les chiffres affichés à l'écran.
///
/// Ce test refait ce calcul à chaque compilation.
@MainActor
final class GrilleTarifaireTests: XCTestCase {

    /// Une ligne du catalogue, packs et abonnements confondus — c'est ainsi que
    /// le client compare, pas famille par famille.
    private struct Ligne {
        let nom: String
        let credits: Int
        let prix: Double
        var prixParCredit: Double { prix / Double(credits) }
    }

    private var catalogue: [Ligne] {
        let packs = CreditsPack.all.map {
            Ligne(nom: $0.label, credits: $0.count, prix: $0.referencePrice)
        }
        let abonnements = PaywallViewModel().allPlans.map {
            Ligne(nom: $0.name, credits: $0.creditsPerMonth,
                  prix: Double($0.price.replacingOccurrences(of: "€", with: "")
                                       .replacingOccurrences(of: ",", with: ".")) ?? .nan)
        }
        return (packs + abonnements).sorted { $0.prix < $1.prix }
    }

    /// Aucune ligne ne doit être dominée : à prix croissant, les crédits
    /// doivent croître aussi. Sinon il existe une offre qui donne moins pour
    /// plus cher, et le client la trouve en dix secondes.
    func testAucuneLigneNestDominee() {
        let lignes = catalogue
        XCTAssertFalse(lignes.isEmpty)
        for (a, b) in zip(lignes, lignes.dropFirst()) {
            XCTAssertGreaterThan(b.prix, a.prix, "\(b.nom) et \(a.nom) au même prix : domination possible")
            XCTAssertGreaterThan(b.credits, a.credits,
                "\(b.nom) coûte plus cher que \(a.nom) mais donne moins de crédits")
        }
    }

    /// Monter en gamme doit TOUJOURS faire baisser le prix au crédit.
    func testPrixAuCreditStrictementDecroissant() {
        let lignes = catalogue
        for (a, b) in zip(lignes, lignes.dropFirst()) {
            XCTAssertLessThan(b.prixParCredit, a.prixParCredit,
                String(format: "%@ à %.4f €/cr n'améliore pas %@ à %.4f €/cr",
                       b.nom, b.prixParCredit, a.nom, a.prixParCredit))
        }
    }

    /// Chaque ligne doit rester rentable même si CHAQUE génération échoue une
    /// fois avant de réussir : 0,028 € pour la tentative perdue plus 0,093 €
    /// pour l'escalade, soit 0,121 €/crédit, Apple prenant 15 %.
    func testRentableMemeSiToutesLesGenerationsEscaladent() {
        let coutPireCas = 0.121
        for ligne in catalogue {
            let net = 0.85 * ligne.prix
            let cout = coutPireCas * Double(ligne.credits)
            XCTAssertGreaterThan(net, cout,
                String(format: "%@ perd de l'argent en cas d'escalade systématique (%.2f € nets pour %.2f € de coût)",
                       ligne.nom, net, cout))
        }
    }

    /// Les crédits affichés par le paywall ÉMOTIONNEL viennent de
    /// SubscriptionStatus.trialLimit ; ceux du paywall complet de
    /// PaywallPlan.creditsPerMonth ; ceux réellement accordés du serveur.
    /// Les trois divergeaient (15/40 contre 25/60) : le même tunnel d'achat
    /// annonçait deux quotas différents à trois secondes d'écart.
    func testLesQuotasAffichesSontCeuxDesFormules() {
        let plans = PaywallViewModel().allPlans
        let essentiel = plans.first { $0.rcIdentifier.contains("starter") }
        let signature = plans.first { $0.rcIdentifier.contains("premium") }
        XCTAssertEqual(SubscriptionStatus.starter.monthlyGenerations, essentiel?.creditsPerMonth,
                       "trialLimit(starter) a dérivé des formules du paywall")
        XCTAssertEqual(SubscriptionStatus.premium.monthlyGenerations, signature?.creditsPerMonth,
                       "trialLimit(premium) a dérivé des formules du paywall")
    }

    /// Aucun badge « meilleure offre » tant qu'une formule le porte à tort.
    func testAucuneFormuleNeSeDeclareMeilleure() {
        let plans = PaywallViewModel().allPlans
        let meilleurPack = CreditsPack.all.map { $0.referencePrice / Double($0.count) }.min() ?? 0
        for plan in plans where plan.isBestValue {
            let unitaire = (Double(plan.price.replacingOccurrences(of: "€", with: "")
                                              .replacingOccurrences(of: ",", with: ".")) ?? .nan)
                            / Double(plan.creditsPerMonth)
            XCTAssertLessThan(unitaire, meilleurPack,
                "\(plan.name) s'annonce meilleure offre alors qu'un pack fait mieux au crédit")
        }
    }
}
