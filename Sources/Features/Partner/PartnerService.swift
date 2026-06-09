import Foundation

// MARK: - Analytics event types (lightweight)

struct ClickEvent {
    let jewelry: JewelryItem
    let partner: PartnerBrand
    let timestamp: Date
}

struct SaleEvent {
    let jewelry: JewelryItem
    let partner: PartnerBrand
    let amount: Double
    let timestamp: Date
}

// MARK: - PartnerService

/// Mock service — all data is static, ready to be wired to a real API.
@MainActor
final class PartnerService {

    // MARK: Singleton

    static let shared = PartnerService()
    private init() {}

    // MARK: In-memory analytics log (session only)

    private(set) var clickLog: [ClickEvent]  = []
    private(set) var saleLog:  [SaleEvent]   = []

    // MARK: - Catalog helpers

    // Catalogue Moni'attitude — bijoux artisanaux de fantaisie en pierres
    // semi-précieuses naturelles. Aucune marque de luxe (or 18k, diamants).
    // Approche wellness : pierres choisies pour leurs vertus énergétiques.
    private static func moniCatalog() -> [JewelryItem] {[
        // Colliers
        JewelryItem(id: UUID(), name: "Pierre de Lune",      category: .necklace, imageURL: nil, icon: "moonphase.last.quarter",  material: "Argent 925 · Pierre de lune",   prompt: "moonstone pendant necklace on neck, boho artisanal style"),
        JewelryItem(id: UUID(), name: "Pendentif Aventurine", category: .necklace, imageURL: nil, icon: "leaf.fill",               material: "Plaqué or · Aventurine verte",   prompt: "green aventurine pendant necklace on neck, wellness boho"),
        JewelryItem(id: UUID(), name: "Sautoir Œil de Tigre", category: .necklace, imageURL: nil, icon: "eye.fill",                material: "Bronze · Œil de tigre",          prompt: "tigers eye long necklace, bronze chain, artisanal wellness"),
        JewelryItem(id: UUID(), name: "Tour de Cou Améthyste", category: .necklace, imageURL: nil, icon: "moonphase.waxing.crescent", material: "Argent 925 · Améthyste tumblé", prompt: "amethyst choker necklace silver chain, healing crystal boho"),

        // Bagues
        JewelryItem(id: UUID(), name: "Améthyste Brute",     category: .ring,     imageURL: nil, icon: "hexagon.fill",            material: "Laiton doré · Améthyste",       prompt: "raw amethyst crystal ring on finger, artisanal boho"),
        JewelryItem(id: UUID(), name: "Citrine Soleil",      category: .ring,     imageURL: nil, icon: "sun.max.fill",            material: "Plaqué or · Citrine",            prompt: "citrine cabochon ring on finger, sunny artisanal style"),
        JewelryItem(id: UUID(), name: "Turquoise Tribale",   category: .ring,     imageURL: nil, icon: "drop.triangle.fill",      material: "Argent 925 · Turquoise",        prompt: "turquoise tribal silver ring on finger, bohemian"),
        JewelryItem(id: UUID(), name: "Quartz Fumé",         category: .ring,     imageURL: nil, icon: "smoke.fill",              material: "Acier doré · Quartz fumé",      prompt: "smoky quartz minimal ring on finger, modern boho"),

        // Bracelets
        JewelryItem(id: UUID(), name: "Labradorite Wrap",    category: .bracelet, imageURL: nil, icon: "square.on.circle",        material: "Cuir · Labradorite",            prompt: "labradorite wrap bracelet on wrist, bohemian wellness style"),
        JewelryItem(id: UUID(), name: "Jaspe Rouge Mala",    category: .bracelet, imageURL: nil, icon: "circle.grid.cross.fill",  material: "Élastique · Jaspe rouge",       prompt: "red jasper mala beaded bracelet on wrist, wellness"),
        JewelryItem(id: UUID(), name: "Cristal de Roche",    category: .bracelet, imageURL: nil, icon: "diamond.fill",            material: "Élastique · Cristal de roche",  prompt: "clear quartz crystal beaded bracelet on wrist, pure energy"),
        JewelryItem(id: UUID(), name: "Onyx Noir & Acier",   category: .bracelet, imageURL: nil, icon: "circle.fill",             material: "Acier · Onyx",                  prompt: "black onyx steel bracelet on wrist, unisex artisanal"),

        // Boucles d'oreilles
        JewelryItem(id: UUID(), name: "Quartz Rose",         category: .earring,  imageURL: nil, icon: "drop.fill",               material: "Argent 925 · Quartz rose",      prompt: "rose quartz drop earrings on ears, artisanal handmade"),
        JewelryItem(id: UUID(), name: "Plume de Hibou",      category: .earring,  imageURL: nil, icon: "leaf",                    material: "Laiton · Plume gravée",         prompt: "feather brass dangle earrings, boho artisanal wellness"),
        JewelryItem(id: UUID(), name: "Créoles Lapis",       category: .earring,  imageURL: nil, icon: "circle.dotted",           material: "Plaqué or · Lapis-lazuli",      prompt: "lapis lazuli hoop earrings, gold plated, artisanal boho"),
        JewelryItem(id: UUID(), name: "Goutte Howlite",      category: .earring,  imageURL: nil, icon: "drop",                    material: "Argent 925 · Howlite blanche",   prompt: "white howlite teardrop earrings, silver hooks, wellness"),

        // Piercings (fantaisie · pierres semi-précieuses)
        JewelryItem(id: UUID(), name: "Anneau Nez Opale",         category: .nosePiercing,    imageURL: nil, icon: "circle.fill",        material: "Argent 925 · Opale",           prompt: "person wearing delicate opal nose ring, close-up portrait, natural light, boho artisanal"),
        JewelryItem(id: UUID(), name: "Anneau Nez Turquoise",     category: .nosePiercing,    imageURL: nil, icon: "circle",             material: "Argent 925 · Turquoise",       prompt: "person wearing turquoise nose ring, close-up portrait, natural light, tribal boho"),
        JewelryItem(id: UUID(), name: "Barbell Arcade Améthyste", category: .eyebrowPiercing, imageURL: nil, icon: "minus.circle.fill",  material: "Acier chirurgical · Améthyste", prompt: "person with amethyst eyebrow barbell piercing, close-up portrait, natural light"),
        JewelryItem(id: UUID(), name: "Barbell Arcade Labradorite",category: .eyebrowPiercing,imageURL: nil, icon: "minus.circle",       material: "Acier · Labradorite",          prompt: "person with labradorite eyebrow barbell, close-up portrait, natural light"),
        JewelryItem(id: UUID(), name: "Anneau Lèvre Citrine",     category: .lipPiercing,     imageURL: nil, icon: "moon.fill",          material: "Plaqué or · Citrine",          prompt: "person with gold citrine lip ring, close-up portrait, natural light"),
        JewelryItem(id: UUID(), name: "Anneau Lèvre Onyx",        category: .lipPiercing,     imageURL: nil, icon: "moon",               material: "Acier · Onyx noir",            prompt: "person with black onyx lip ring, close-up portrait, natural light"),
        JewelryItem(id: UUID(), name: "Barbell Langue Quartz Rose",category: .tonguePiercing,  imageURL: nil, icon: "capsule.fill",       material: "Acier · Quartz rose",          prompt: "person with rose quartz tongue barbell, mouth slightly open, close-up portrait"),
        JewelryItem(id: UUID(), name: "Barbell Langue Cristal",   category: .tonguePiercing,  imageURL: nil, icon: "capsule",            material: "Acier · Cristal de roche",     prompt: "person with clear crystal tongue barbell, mouth slightly open, wellness style"),
    ]}

    // MARK: - Static sample data

    // SEULE boutique partenaire : Moni'attitude.
    // Bijoux artisanaux de fantaisie en pierres semi-précieuses, sans marques
    // de luxe. C'est la boutique de référence de L'Écrin Virtuel.
    static let sampleBrands: [PartnerBrand] = [
        PartnerBrand(
            id: UUID(),
            name: "Moni'attitude",
            description: "Bijoux artisanaux belges aux pierres semi-précieuses naturelles. Une approche wellness & bien-être : chaque création est pensée pour accompagner votre énergie au quotidien.",
            logoURL: nil,
            websiteURL: URL(string: "https://moniattitude.com"),
            country: "Belgique",
            category: .artisanal,
            isVerified: true,
            commissionRate: 0.15,
            monthlyFee: 199,
            catalog: moniCatalog(),
            totalSales: 14_850,
            joinedAt: Date(timeIntervalSinceNow: -60 * 86400)
        ),
    ]

    // MARK: - Fetch API (mock)

    /// Returns all partner brands, optionally filtered by category.
    func fetchPartners(category: PartnerBrand.BrandCategory? = nil) async -> [PartnerBrand] {
        // Simulate network latency
        try? await Task.sleep(nanoseconds: 400_000_000)
        if let category {
            return Self.sampleBrands.filter { $0.category == category }
        }
        return Self.sampleBrands
    }

    /// Returns the catalog of a specific partner.
    /// Pour Moni'attitude, charge les vrais bijoux depuis Supabase avec images.
    func fetchPartnerCatalog(id: UUID) async -> [JewelryItem] {
        // Moni'attitude → bijoux réels depuis Supabase
        if let moni = Self.sampleBrands.first(where: { $0.id == id }),
           moni.name.contains("Moni") {
            if let items = try? await SupabaseService.shared.fetchJewelryCatalog(), !items.isEmpty {
                return items.map { $0.asJewelryItem }
            }
        }
        // Fallback sur données statiques
        return Self.sampleBrands.first(where: { $0.id == id })?.catalog ?? []
    }

    // MARK: - Analytics tracking

    /// Records a product click (affiliate tracking).
    func trackClick(jewelry: JewelryItem, partner: PartnerBrand) {
        clickLog.append(ClickEvent(jewelry: jewelry, partner: partner, timestamp: .now))
    }

    /// Records a confirmed sale for commission calculation.
    func recordSale(jewelry: JewelryItem, partner: PartnerBrand, amount: Double) {
        saleLog.append(SaleEvent(jewelry: jewelry, partner: partner, amount: amount, timestamp: .now))
    }
}
