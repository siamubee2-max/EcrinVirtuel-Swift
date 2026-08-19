import XCTest
@testable import EcrinVirtuel

@MainActor
final class MoodBoardStoreTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: MoodBoardStore!

    override func setUp() {
        super.setUp()
        // Use an ephemeral suite so tests don't touch the real UserDefaults.
        suiteName = "MoodBoardStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        store = MoodBoardStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Save → Load Round-Trip

    func testSaveAndLoadRoundTrip() {
        let board = MoodBoard(
            id: "test-1",
            title: "Gala Test",
            prompt: "Un gala",
            occasion: "Gala",
            style: "Classique",
            jewelryItems: [],
            generatedDescription: "Description",
            colorPalette: ["#080808", "#CA8A04"],
            keywords: ["Gala"],
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        store.save(board)

        // Reload from same defaults to verify persistence
        let loaded = MoodBoardStore(defaults: defaults)
        XCTAssertEqual(loaded.boards.count, 1)
        XCTAssertEqual(loaded.boards.first?.id, "test-1")
        XCTAssertEqual(loaded.boards.first?.title, "Gala Test")
        XCTAssertEqual(loaded.boards.first?.colorPalette, ["#080808", "#CA8A04"])
    }

    func testSaveMultipleBoardsNewestFirst() {
        let b1 = MoodBoard(id: "b1", title: "First", prompt: "", createdAt: Date(timeIntervalSince1970: 1_000))
        let b2 = MoodBoard(id: "b2", title: "Second", prompt: "", createdAt: Date(timeIntervalSince1970: 2_000))

        store.save(b1)
        store.save(b2)

        XCTAssertEqual(store.boards.count, 2)
        XCTAssertEqual(store.boards[0].id, "b2")  // newest inserted at front
        XCTAssertEqual(store.boards[1].id, "b1")
    }

    func testSaveUpdatesExistingBoardInPlace() {
        var board = MoodBoard(id: "update-me", title: "Original", prompt: "")
        store.save(board)

        board.title = "Updated"
        store.save(board)

        XCTAssertEqual(store.boards.count, 1)
        XCTAssertEqual(store.boards.first?.title, "Updated")
    }

    func testDeleteRemovesBoard() {
        let board = MoodBoard(id: "del-1", title: "To Delete", prompt: "")
        store.save(board)
        XCTAssertEqual(store.boards.count, 1)

        store.delete(id: "del-1")
        XCTAssertTrue(store.boards.isEmpty)

        // Verify deletion persists across reload
        let reloaded = MoodBoardStore(defaults: defaults)
        XCTAssertTrue(reloaded.boards.isEmpty)
    }

    func testEmptyStoreOnFirstLoad() {
        XCTAssertTrue(store.boards.isEmpty)
    }
}
