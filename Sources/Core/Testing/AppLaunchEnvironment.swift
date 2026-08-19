import Foundation

/// The single seam between production code and UI tests. This is the ONLY place
/// that reads UI-test launch arguments. Production behaviour is unchanged unless
/// `-uitest` is passed — which only XCUITest does. Parsing is exposed as pure
/// functions over `[String]` so it is unit-testable without spawning a process.
enum AppLaunchEnvironment {

    // MARK: Pure parsing (testable)

    static func isUITesting(_ args: [String]) -> Bool { args.contains("-uitest") }

    static func mockAuthenticated(_ args: [String]) -> Bool { args.contains("-uitest-auth") }

    static func mockCredits(_ args: [String]) -> Int {
        guard let i = args.firstIndex(of: "-uitest-credits"),
              i + 1 < args.count, let n = Int(args[i + 1]) else { return 3 }
        return n
    }

    // MARK: Live accessors (use the real process arguments)

    private static var live: [String] { ProcessInfo.processInfo.arguments }

    static var isUITesting: Bool { isUITesting(live) }
    static var mockAuthenticated: Bool { mockAuthenticated(live) }
    static var mockCredits: Int { mockCredits(live) }

    /// Deterministic mock user for UI tests (never touches the backend).
    static var mockUser: User {
        User(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000AA") ?? UUID(),
             email: "uitest@ecrin.local",
             displayName: "UITest")
    }
}
