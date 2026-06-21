import XCTest

final class CoreJourneysUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Test 1: Wardrobe tab shows items grid and add sheet opens

    func testWardrobeTabShowsItemsAndAddSheetOpens() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-uitest-auth"]
        app.launch()

        // Tap Garde-robe tab
        app.tabBars.buttons["Garde-robe"].tap()

        // LazyVGrid may render as collectionView or otherElement depending on iOS version
        // Use descendants to find regardless of element type
        let grid = app.descendants(matching: .any).matching(identifier: "wardrobe.list").firstMatch
        XCTAssertTrue(grid.waitForExistence(timeout: 12), "wardrobe.list grid should appear")

        // Tap the + FAB in WardrobeView
        let addButton = app.buttons["wardrobe.add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "wardrobe.add button should exist")
        addButton.tap()

        // Sheet should appear (ZStack with identifier → search descendants)
        let addSheet = app.descendants(matching: .any).matching(identifier: "wardrobe.addsheet").firstMatch
        XCTAssertTrue(addSheet.waitForExistence(timeout: 10), "wardrobe.addsheet should appear after tapping +")
    }

    // MARK: - Test 2: Catalog shows items grid

    func testCatalogShowsItems() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-uitest-auth"]
        app.launch()

        // Tap Garde-robe tab first (Catalogue button is in its toolbar)
        app.tabBars.buttons["Garde-robe"].tap()

        // Wait for wardrobe to be active
        let addButton = app.buttons["wardrobe.add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 12), "wardrobe.add button should exist")

        // Tap the Catalogue toolbar/navigation button
        let catalogueButton = app.buttons["Catalogue"]
        XCTAssertTrue(catalogueButton.waitForExistence(timeout: 5), "Catalogue button should be in toolbar")
        catalogueButton.tap()

        // ScrollView wrapping LazyVGrid
        let catalogGrid = app.scrollViews["catalog.grid"]
        XCTAssertTrue(catalogGrid.waitForExistence(timeout: 12), "catalog.grid should appear")
    }

    // MARK: - Test 3: QuickTryOn opens from FAB

    func testQuickTryOnOpensFromFab() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-uitest-auth"]
        app.launch()

        // Tap the global QuickTryOn FAB
        let fab = app.buttons["fab.quicktryon"]
        XCTAssertTrue(fab.waitForExistence(timeout: 10), "fab.quicktryon button should exist")
        fab.tap()

        // ZStack in QuickTryOnView body may render as otherElement or scrollView
        // Use firstMatch to find the identifier regardless of element type
        let tryOnRoot = app.descendants(matching: .any).matching(identifier: "quicktryon.root").firstMatch
        XCTAssertTrue(tryOnRoot.waitForExistence(timeout: 15), "quicktryon.root should appear after tapping FAB")
    }

    // MARK: - Test 4: Profile tab shows sign-out button

    func testProfileTabShowsSignOut() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-uitest-auth"]
        app.launch()

        // Tap Profil tab
        app.tabBars.buttons["Profil"].tap()

        // Sign-out button should be visible
        let signOutButton = app.buttons["profile.signout"]
        XCTAssertTrue(signOutButton.waitForExistence(timeout: 12), "profile.signout button should appear in Profil tab")
    }

    // MARK: - Test 5: Community tab shows feed

    func testCommunityTabShowsFeed() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-uitest-auth"]
        app.launch()

        // Tap Communauté tab
        app.tabBars.buttons["Communauté"].tap()

        // ScrollView in FeedTab → scrollViews
        let feed = app.scrollViews["community.feed"]
        XCTAssertTrue(feed.waitForExistence(timeout: 12), "community.feed scroll view should appear in Communauté tab")
    }
}
