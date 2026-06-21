import XCTest
@testable import EcrinVirtuel

final class AppLaunchEnvironmentTests: XCTestCase {

    func testIsUITestingTrueWhenFlagPresent() {
        XCTAssertTrue(AppLaunchEnvironment.isUITesting(["app", "-uitest"]))
    }

    func testIsUITestingFalseWhenAbsent() {
        XCTAssertFalse(AppLaunchEnvironment.isUITesting(["app"]))
    }

    func testMockAuthenticatedRequiresFlag() {
        XCTAssertTrue(AppLaunchEnvironment.mockAuthenticated(["-uitest", "-uitest-auth"]))
        XCTAssertFalse(AppLaunchEnvironment.mockAuthenticated(["-uitest"]))
    }

    func testMockCreditsParsesValue() {
        XCTAssertEqual(AppLaunchEnvironment.mockCredits(["-uitest-credits", "7"]), 7)
    }

    func testMockCreditsDefaultsToThree() {
        XCTAssertEqual(AppLaunchEnvironment.mockCredits([]), 3)
    }
}
