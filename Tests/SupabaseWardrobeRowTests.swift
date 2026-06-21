import XCTest
@testable import EcrinVirtuel

final class SupabaseWardrobeRowTests: XCTestCase {

    /// Verifies that SupabaseWardrobeRow encodes to EXACTLY the 10 prod columns:
    /// id, user_id, name, type, category, brand, color, image_url, is_favorite, created_at
    func testEncodedKeysMatchProdSchema() throws {
        let expectedKeys: Set<String> = [
            "id", "user_id", "name", "type", "category",
            "brand", "color", "image_url", "is_favorite", "created_at"
        ]

        let row = SupabaseWardrobeRow(
            id: UUID().uuidString,
            user_id: UUID().uuidString,
            name: "Chemise Blanche",
            type: FashionCategory.top.rawValue,
            category: FashionCategory.top.rawValue,
            brand: "Test Brand",
            color: "Blanc",
            image_url: "https://example.com/img.jpg",
            is_favorite: false,
            created_at: ISO8601DateFormatter().string(from: .now)
        )

        let data = try JSONEncoder().encode(row)
        let dict = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        XCTAssertEqual(
            Set(dict.keys), expectedKeys,
            "Encoded keys \(Set(dict.keys)) must exactly match prod schema \(expectedKeys)"
        )
    }

    /// Verifies that type == category == FashionCategory.rawValue.
    func testTypeEqualsCategoryEqualsCategoryRawValue() throws {
        let fashionCategory = FashionCategory.dress
        let rawValue = fashionCategory.rawValue

        let row = SupabaseWardrobeRow(
            id: UUID().uuidString,
            user_id: UUID().uuidString,
            name: "Robe Midi",
            type: rawValue,
            category: rawValue,
            brand: nil,
            color: "Noir",
            image_url: nil,
            is_favorite: true,
            created_at: ISO8601DateFormatter().string(from: .now)
        )

        let data = try JSONEncoder().encode(row)
        let dict = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        let encodedType = try XCTUnwrap(dict["type"] as? String)
        let encodedCategory = try XCTUnwrap(dict["category"] as? String)

        XCTAssertEqual(encodedType, rawValue,
                       "type must equal FashionCategory.rawValue")
        XCTAssertEqual(encodedCategory, rawValue,
                       "category must equal FashionCategory.rawValue")
        XCTAssertEqual(encodedType, encodedCategory,
                       "type and category must be equal")
    }

    /// Verifies that optional nil fields are omitted (not encoded as null),
    /// and that no extra columns (e.g. subcategory, material, tags) leak through.
    func testNoGhostColumnsWhenOptionalFieldsAreNil() throws {
        let forbiddenKeys: Set<String> = [
            "subcategory", "material", "tags", "try_on_prompt",
            "source", "price", "purchase_url", "updated_at", "auth_id"
        ]

        let row = SupabaseWardrobeRow(
            id: UUID().uuidString,
            user_id: UUID().uuidString,
            name: "Sac à Main",
            type: FashionCategory.bag.rawValue,
            category: FashionCategory.bag.rawValue,
            brand: nil,
            color: nil,
            image_url: nil,
            is_favorite: false,
            created_at: ISO8601DateFormatter().string(from: .now)
        )

        let data = try JSONEncoder().encode(row)
        let dict = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        let presentForbidden = forbiddenKeys.intersection(Set(dict.keys))
        XCTAssertTrue(
            presentForbidden.isEmpty,
            "Ghost columns found in encoded row: \(presentForbidden)"
        )
    }

    /// Verifies round-trip: asFashionItem reconstructs the item correctly.
    func testAsFashionItemRoundTrip() {
        let itemId = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let iso = ISO8601DateFormatter()

        let row = SupabaseWardrobeRow(
            id: itemId.uuidString,
            user_id: UUID().uuidString,
            name: "Bracelet Mala",
            type: FashionCategory.bracelet.rawValue,
            category: FashionCategory.bracelet.rawValue,
            brand: "Moni",
            color: "Transparent",
            image_url: "https://example.com/bracelet.jpg",
            is_favorite: true,
            created_at: iso.string(from: createdAt)
        )

        let item = row.asFashionItem

        XCTAssertEqual(item.id, itemId)
        XCTAssertEqual(item.name, "Bracelet Mala")
        XCTAssertEqual(item.category, .bracelet)
        XCTAssertEqual(item.brand, "Moni")
        XCTAssertEqual(item.color, "Transparent")
        XCTAssertEqual(item.isFavorite, true)
        XCTAssertEqual(item.imageURL?.absoluteString, "https://example.com/bracelet.jpg")
        // Non-persisted fields must have safe defaults
        XCTAssertNil(item.subcategory)
        XCTAssertNil(item.material)
        XCTAssertEqual(item.tags, [])
        XCTAssertNil(item.price)
        XCTAssertNil(item.purchaseURL)
        XCTAssertEqual(item.source, .userPhoto)
    }
}
