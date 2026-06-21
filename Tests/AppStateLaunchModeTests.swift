import XCTest
@testable import EcrinVirtuel

@MainActor
final class AppStateLaunchModeTests: XCTestCase {

    func testAuthenticatedMockStartsAuthenticated() {
        let state = AppState(launchArguments: ["-uitest", "-uitest-auth"])
        XCTAssertEqual(state.phase, .authenticated)
        XCTAssertEqual(state.currentUser?.email, "uitest@ecrin.local")
    }

    func testUITestWithoutAuthStartsOnboarding() {
        let state = AppState(launchArguments: ["-uitest"])
        XCTAssertEqual(state.phase, .onboarding)
    }
}
