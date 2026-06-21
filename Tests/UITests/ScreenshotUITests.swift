import XCTest

/// Captures full-screen screenshots of all core App Store screens on iPhone 17 Pro Max (6.9").
/// Launch: [-uitest -uitest-auth] boots the app authenticated with mock data, zero backend.
final class ScreenshotUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitest", "-uitest-auth"]
        app.launch()
        // Wait for the tab bar to be ready before any capture
        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 20),
            "Tab bar never appeared — mock boot may have failed"
        )
    }

    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    // MARK: - Screenshot helper

    func snap(_ name: String) {
        let s = XCUIScreen.main.screenshot()
        let a = XCTAttachment(screenshot: s)
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    // MARK: - 01 Essayage (default / first tab)

    func test01Essayage() {
        // Essayage is the default tab; verify its screen identifier exists then snap
        let screen = app.descendants(matching: .any).matching(identifier: "screen.essayage").firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 12), "screen.essayage not found")
        snap("01-essayage")
    }

    // MARK: - 02 Garde-robe

    func test02Garderobe() {
        let tab = app.tabBars.buttons["Garde-robe"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Garde-robe tab missing")
        tab.tap()
        let screen = app.descendants(matching: .any).matching(identifier: "screen.garderobe").firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 12), "screen.garderobe not found")
        snap("02-garderobe")
    }

    // MARK: - 03 Catalogue (opened from Garde-robe toolbar)

    func test03Catalogue() {
        // Navigate to Garde-robe first
        let tab = app.tabBars.buttons["Garde-robe"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Garde-robe tab missing")
        tab.tap()

        // Tap the Catalogue toolbar button
        let catalogueButton = app.buttons["Catalogue"]
        XCTAssertTrue(catalogueButton.waitForExistence(timeout: 10), "Catalogue button missing in Garde-robe toolbar")
        catalogueButton.tap()

        // Wait for catalog grid to appear
        let grid = app.scrollViews["catalog.grid"]
        XCTAssertTrue(grid.waitForExistence(timeout: 15), "catalog.grid not found after opening Catalogue")
        snap("03-catalogue")
    }

    // MARK: - 04 Communauté

    func test04Communaute() {
        let tab = app.tabBars.buttons["Communauté"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Communauté tab missing")
        tab.tap()
        let screen = app.descendants(matching: .any).matching(identifier: "screen.communaute").firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 12), "screen.communaute not found")
        snap("04-communaute")
    }

    // MARK: - 05 Profil

    func test05Profil() {
        let tab = app.tabBars.buttons["Profil"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Profil tab missing")
        tab.tap()
        let screen = app.descendants(matching: .any).matching(identifier: "screen.profil").firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 12), "screen.profil not found")
        snap("05-profil")
    }

    // MARK: - 06 Quick Try-On (FAB)

    func test06QuickTryOn() {
        let fab = app.buttons["fab.quicktryon"]
        XCTAssertTrue(fab.waitForExistence(timeout: 10), "fab.quicktryon not found")
        fab.tap()
        let root = app.descendants(matching: .any).matching(identifier: "quicktryon.root").firstMatch
        XCTAssertTrue(root.waitForExistence(timeout: 15), "quicktryon.root not found after tapping FAB")
        snap("06-quicktryon")
    }
}
