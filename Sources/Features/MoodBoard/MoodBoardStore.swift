import Foundation

// MARK: - MoodBoard Persistence Store
//
// Pragmatic choice: UserDefaults + JSON (Codable).
// Rationale: MoodBoard is already Codable; no extra dependency needed; boards are small
// (text + color strings + JewelryItem refs, no binary blobs). A Supabase-backed store
// would be the Phase-5 upgrade path.

@Observable
@MainActor
final class MoodBoardStore {

    // MARK: - Singleton

    static let shared = MoodBoardStore()

    // MARK: - State

    /// Currently saved boards, newest first.
    private(set) var boards: [MoodBoard] = []

    // MARK: - Private

    private static let userDefaultsKey = "com.ecrin.moodboard.savedBoards"

    private let defaults: UserDefaults

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.boards = Self.load(from: defaults)
    }

    // MARK: - Public API

    /// Persist a board. If a board with the same id already exists it is replaced.
    func save(_ board: MoodBoard) {
        if let idx = boards.firstIndex(where: { $0.id == board.id }) {
            boards[idx] = board
        } else {
            boards.insert(board, at: 0)
        }
        persist()
    }

    /// Remove a board by id.
    func delete(id: String) {
        boards.removeAll { $0.id == id }
        persist()
    }

    // MARK: - Private Helpers

    private func persist() {
        guard let data = try? JSONEncoder().encode(boards) else { return }
        defaults.set(data, forKey: Self.userDefaultsKey)
    }

    private static func load(from defaults: UserDefaults) -> [MoodBoard] {
        guard
            let data = defaults.data(forKey: userDefaultsKey),
            let decoded = try? JSONDecoder().decode([MoodBoard].self, from: data)
        else { return [] }
        return decoded
    }
}
