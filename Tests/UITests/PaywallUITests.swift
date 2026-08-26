import XCTest

final class PaywallUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    override func tearDown() {
        XCUIApplication().terminate()
        super.tearDown()
    }

    // MARK: - Test: Paywall presents from Profile tab (zero-credits path)
    //
    // Trigger: `-uitest-credits 0` causes ProfileView to enter the credits-empty
    // branch, showing the "S'abonner" button (profile.premium). Tapping it
    // presents PaywallView as a sheet. PaywallView renders its static chrome
    // (title, plan cards, CTA, restore) from hardcoded data — no RevenueCat
    // connection required.

    func testPaywallPresentsAndShowsStaticUI() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-uitest-auth", "-uitest-credits", "0"]
        app.launch()

        // Navigate to Profile tab
        let profileTab = app.tabBars.buttons["Profil"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 15), "Profil tab should exist")
        profileTab.tap()

        // Give the profile view time to finish its .task (sets remainingCredits = 0)
        // then wait for the profile.premium button to appear.
        let premiumButton = app.descendants(matching: .any).matching(identifier: "profile.premium").firstMatch
        XCTAssertTrue(premiumButton.waitForExistence(timeout: 10), "profile.premium button should appear when credits are empty")

        // Ensure it's in the center of the screen before tapping
        // (the profile scroll view places it near the top — should be visible)
        premiumButton.tap()

        // PaywallView sheet renders static chrome (no RevenueCat needed).
        // Wait generously for the sheet to animate in.
        // Primary signal: "Restaurer mes achats" Button (paywall.restore)
        let restore = app.descendants(matching: .any).matching(identifier: "paywall.restore").firstMatch
        XCTAssertTrue(restore.waitForExistence(timeout: 15),
                      "paywall.restore should appear — confirms PaywallView sheet is presented")

        // paywall.root is on the ZStack container
        let paywallRoot = app.descendants(matching: .any).matching(identifier: "paywall.root").firstMatch
        XCTAssertTrue(paywallRoot.exists, "paywall.root container should exist once paywall is shown")

        // Primary CTA button (GoldButton)
        let cta = app.descendants(matching: .any).matching(identifier: "paywall.cta").firstMatch
        XCTAssertTrue(cta.exists, "paywall.cta should be visible in paywall sheet")
    }
}
