import XCTest
@testable import EcrinVirtuel

final class UnlimitedAccessTests: XCTestCase {
    func testUnlimitedWhenBalanceAtSentinel() {
        XCTAssertTrue(UnlimitedAccess.isUnlimited(remainingCredits: UnlimitedAccess.quotaDisplayValue))
    }
    func testUnlimitedWhenBalanceAboveThreshold() {
        XCTAssertTrue(UnlimitedAccess.isUnlimited(remainingCredits: 500_000))
    }
    func testNotUnlimitedForNormalBalance() {
        XCTAssertFalse(UnlimitedAccess.isUnlimited(remainingCredits: 3))
    }
}
