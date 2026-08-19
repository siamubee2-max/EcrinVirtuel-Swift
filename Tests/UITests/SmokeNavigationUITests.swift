import XCTest

final class SmokeNavigationUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testNavigatesAllFiveTabs() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-uitest-auth"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15), "Tab bar never appeared")

        for label in ["Essayage", "Garde-robe", "Boutique", "Communauté", "Profil"] {
            let button = tabBar.buttons[label]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "Tab '\(label)' missing")
            button.tap()
        }

        // The quick-try-on FAB is present on the main tab surface.
        XCTAssertTrue(app.buttons["fab.quicktryon"].waitForExistence(timeout: 5),
                      "Quick-try-on FAB missing")
    }
}
