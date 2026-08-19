import XCTest

final class CoreJourneysUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    override func tearDown() {
        XCUIApplication().terminate()
        super.tearDown()
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

        // Assert at least one item cell is visible (fails if grid is empty / mock seam not seeded)
        let firstItem = app.descendants(matching: .any).matching(identifier: "wardrobe.item").firstMatch
        XCTAssertTrue(firstItem.waitForExistence(timeout: 5), "At least one wardrobe.item cell should be visible in the grid")

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

        // Cold first launch after fresh install can exceed 12s before the tab
        // bar renders — wait for it explicitly instead of tapping blind.
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 20), "TabBar should appear after launch")

        // Tap Garde-robe tab first (Catalogue button is in its toolbar)
        app.tabBars.buttons["Garde-robe"].tap()

        // Wait for wardrobe to be active
        let addButton = app.buttons["wardrobe.add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 20), "wardrobe.add button should exist")

        // Tap the Catalogue toolbar/navigation button
        let catalogueButton = app.buttons["Catalogue"]
        XCTAssertTrue(catalogueButton.waitForExistence(timeout: 5), "Catalogue button should be in toolbar")
        catalogueButton.tap()

        // Wait for the navigation push to complete before querying the grid
        XCTAssertTrue(
            app.navigationBars.element.waitForExistence(timeout: 8),
            "Navigation bar should appear after tapping Catalogue"
        )

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

        // ProfileView loads behind an async .task (credits fetch); under simulator
        // load the accessibility tree settles slowly. The sign-out button sits at the
        // bottom of a long ScrollView, so scroll it into view to make existence
        // deterministic regardless of timing (prevents flaky timeouts under CI load).
        let signOutButton = app.buttons["profile.signout"]
        if !signOutButton.waitForExistence(timeout: 20) {
            let scroll = app.scrollViews.firstMatch
            for _ in 0..<6 where !signOutButton.exists { scroll.swipeUp() }
        }
        XCTAssertTrue(signOutButton.exists, "profile.signout button should appear in Profil tab")
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
