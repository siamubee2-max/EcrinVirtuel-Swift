import XCTest
@testable import EcrinVirtuel

// Tests for Bug C7 — SubscriptionStatus rawValue round-trip used to persist
// the last known subscription tier across cold-launch network failures.
final class SubscriptionStatusPersistenceTests: XCTestCase {

    private let key = "lastKnownSubscriptionTier"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        // Use an isolated suite so tests never pollute real UserDefaults.
        defaults = UserDefaults(suiteName: "SubscriptionStatusPersistenceTests")!
        defaults.removePersistentDomain(forName: "SubscriptionStatusPersistenceTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "SubscriptionStatusPersistenceTests")
        defaults = nil
        super.tearDown()
    }

    // MARK: - rawValue encoding

    func testAllCasesHaveExpectedRawValues() {
        XCTAssertEqual(SubscriptionStatus.free.rawValue,    "free")
        XCTAssertEqual(SubscriptionStatus.starter.rawValue, "starter")
        XCTAssertEqual(SubscriptionStatus.premium.rawValue, "premium")
        XCTAssertEqual(SubscriptionStatus.elite.rawValue,   "elite")
    }

    // MARK: - persist → restore round-trip

    func testEliteRoundTrip() {
        let tier = SubscriptionStatus.elite
        defaults.set(tier.rawValue, forKey: key)
        let raw = defaults.string(forKey: key)
        XCTAssertEqual(SubscriptionStatus(rawValue: raw!), .elite)
    }

    func testPremiumRoundTrip() {
        let tier = SubscriptionStatus.premium
        defaults.set(tier.rawValue, forKey: key)
        let raw = defaults.string(forKey: key)
        XCTAssertEqual(SubscriptionStatus(rawValue: raw!), .premium)
    }

    func testStarterRoundTrip() {
        let tier = SubscriptionStatus.starter
        defaults.set(tier.rawValue, forKey: key)
        let raw = defaults.string(forKey: key)
        XCTAssertEqual(SubscriptionStatus(rawValue: raw!), .starter)
    }

    func testFreeRoundTrip() {
        let tier = SubscriptionStatus.free
        defaults.set(tier.rawValue, forKey: key)
        let raw = defaults.string(forKey: key)
        XCTAssertEqual(SubscriptionStatus(rawValue: raw!), .free)
    }

    // MARK: - missing key falls back to nil (caller defaults to .free)

    func testMissingKeyYieldsNil() {
        let raw = defaults.string(forKey: key)
        XCTAssertNil(raw)
        // Callers do: SubscriptionStatus(rawValue: raw ?? "") which produces nil → fall back to .free
        XCTAssertNil(SubscriptionStatus(rawValue: ""))
    }

    // MARK: - corrupted value yields nil (safe)

    func testCorruptedValueYieldsNil() {
        defaults.set("corrupted_garbage", forKey: key)
        let raw = defaults.string(forKey: key)!
        XCTAssertNil(SubscriptionStatus(rawValue: raw))
    }
}
