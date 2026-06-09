import SwiftUI
import Observation

// MARK: - PartnerViewModel

@MainActor
@Observable
final class PartnerViewModel {

    // MARK: State

    var partners: [PartnerBrand] = []
    var selectedCategory: PartnerBrand.BrandCategory? = nil
    var isLoading = false
    var searchText = ""
    var error: String? = nil

    // MARK: Private

    private let service = PartnerService.shared

    // MARK: - Derived

    var filteredPartners: [PartnerBrand] {
        let base = selectedCategory == nil
            ? partners
            : partners.filter { $0.category == selectedCategory }

        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            return base
        }
        let q = searchText.lowercased()
        return base.filter {
            $0.name.lowercased().contains(q) ||
            $0.description.lowercased().contains(q) ||
            $0.country.lowercased().contains(q)
        }
    }

    var hasResults: Bool { !filteredPartners.isEmpty }

    // MARK: - Intents

    func loadPartners() async {
        guard partners.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        partners = await service.fetchPartners()
    }

    func selectCategory(_ category: PartnerBrand.BrandCategory?) {
        withAnimation(EcrinAnimation.springSnap) {
            selectedCategory = (selectedCategory == category) ? nil : category
        }
    }

    func refreshPartners() async {
        isLoading = true
        defer { isLoading = false }
        partners = await service.fetchPartners()
    }
}
