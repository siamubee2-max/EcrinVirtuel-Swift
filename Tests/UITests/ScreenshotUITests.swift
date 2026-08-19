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

    // MARK: - Robust navigation helpers
    //
    // Under heavy back-to-back UI-test load on a busy simulator, the accessibility
    // tree settles slowly and a single tab `.tap()` occasionally does not register
    // before the wait expires. These helpers use a generous timeout and retry the
    // tap once, which makes the screenshot suite deterministic regardless of timing.

    private static let uiTimeout: TimeInterval = 20

    /// Waits for an element by identifier (any element type), failing the test if absent.
    @discardableResult
    private func waitForID(_ id: String, timeout: TimeInterval = ScreenshotUITests.uiTimeout) -> XCUIElement {
        let el = app.descendants(matching: .any).matching(identifier: id).firstMatch
        XCTAssertTrue(el.waitForExistence(timeout: timeout), "\(id) not found")
        return el
    }

    /// Taps a tab-bar button and waits for its screen identifier; retries the tap once
    /// if the screen does not appear (covers a dropped first tap or slow view load).
    private func openTab(_ label: String, screen screenID: String,
                         timeout: TimeInterval = ScreenshotUITests.uiTimeout) {
        let tab = app.tabBars.buttons[label]
        XCTAssertTrue(tab.waitForExistence(timeout: timeout), "\(label) tab missing")
        tab.tap()
        let screen = app.descendants(matching: .any).matching(identifier: screenID).firstMatch
        if !screen.waitForExistence(timeout: timeout) {
            tab.tap() // retry once — first tap may not have registered under load
            XCTAssertTrue(screen.waitForExistence(timeout: timeout),
                          "\(screenID) not found after tapping \(label) (incl. retry)")
        }
    }

    // MARK: - 01 Essayage (default / first tab)

    func test01Essayage() {
        // Essayage is the default tab; verify its screen identifier exists then snap
        waitForID("screen.essayage")
        snap("01-essayage")
    }

    // MARK: - 02 Garde-robe

    func test02Garderobe() {
        openTab("Garde-robe", screen: "screen.garderobe")
        snap("02-garderobe")
    }

    // MARK: - 03 Catalogue (opened from Garde-robe toolbar)

    func test03Catalogue() {
        // Navigate to Garde-robe first (with retry), then open Catalogue from its toolbar.
        openTab("Garde-robe", screen: "screen.garderobe")

        let catalogueButton = app.buttons["Catalogue"]
        XCTAssertTrue(catalogueButton.waitForExistence(timeout: Self.uiTimeout),
                      "Catalogue button missing in Garde-robe toolbar")
        catalogueButton.tap()

        // Wait for catalog grid; retry the toolbar tap once if the push was missed.
        let grid = app.scrollViews["catalog.grid"]
        if !grid.waitForExistence(timeout: Self.uiTimeout) {
            catalogueButton.tap()
            XCTAssertTrue(grid.waitForExistence(timeout: Self.uiTimeout),
                          "catalog.grid not found after opening Catalogue (incl. retry)")
        }
        snap("03-catalogue")
    }

    // MARK: - 04 Communauté

    func test04Communaute() {
        openTab("Communauté", screen: "screen.communaute")
        snap("04-communaute")
    }

    // MARK: - 05 Profil

    func test05Profil() {
        openTab("Profil", screen: "screen.profil")
        snap("05-profil")
    }

    // MARK: - 06 Quick Try-On (FAB)

    func test06QuickTryOn() {
        let fab = app.buttons["fab.quicktryon"]
        XCTAssertTrue(fab.waitForExistence(timeout: Self.uiTimeout), "fab.quicktryon not found")
        fab.tap()
        let root = app.descendants(matching: .any).matching(identifier: "quicktryon.root").firstMatch
        if !root.waitForExistence(timeout: Self.uiTimeout) {
            fab.tap() // retry once
            XCTAssertTrue(root.waitForExistence(timeout: Self.uiTimeout),
                          "quicktryon.root not found after tapping FAB (incl. retry)")
        }
        snap("06-quicktryon")
    }
}
