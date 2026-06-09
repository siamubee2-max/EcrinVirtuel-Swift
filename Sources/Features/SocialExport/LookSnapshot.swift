import UIKit
import Foundation

// MARK: - Watermark Style
enum WatermarkStyle: String, CaseIterable, Codable {
    case minimal  = "Minimal"
    case branded  = "Branded"
    case none     = "Sans"

    var displayLabel: String { rawValue }
}

// MARK: - Social Format
enum SocialFormat: String, CaseIterable, Codable {
    case stories  = "Stories"
    case post     = "Post"
    case portrait = "Portrait"

    var displayLabel: String { rawValue }

    var aspectRatio: CGFloat {
        switch self {
        case .stories:  return 9.0 / 16.0
        case .post:     return 1.0
        case .portrait: return 4.0 / 5.0
        }
    }

    var iconName: String {
        switch self {
        case .stories:  return "rectangle.portrait"
        case .post:     return "square"
        case .portrait: return "rectangle.portrait.inset.filled"
        }
    }

    var renderSize: CGSize {
        switch self {
        case .stories:  return CGSize(width: 1080, height: 1920)
        case .post:     return CGSize(width: 1080, height: 1080)
        case .portrait: return CGSize(width: 1080, height: 1350)
        }
    }

    var dimensionLabel: String {
        let s = renderSize
        return "\(Int(s.width)) × \(Int(s.height))"
    }
}

// MARK: - Look Snapshot Model
struct LookSnapshot: Identifiable {
    let id: UUID
    let tryOnImage: UIImage
    let jewelryItem: JewelryItem
    var brandName: String?          // Nom boutique partenaire
    var watermark: WatermarkStyle
    var format: SocialFormat

    init(
        id: UUID = UUID(),
        tryOnImage: UIImage,
        jewelryItem: JewelryItem,
        brandName: String? = nil,
        watermark: WatermarkStyle = .minimal,
        format: SocialFormat = .post
    ) {
        self.id = id
        self.tryOnImage = tryOnImage
        self.jewelryItem = jewelryItem
        self.brandName = brandName
        self.watermark = watermark
        self.format = format
    }
}
