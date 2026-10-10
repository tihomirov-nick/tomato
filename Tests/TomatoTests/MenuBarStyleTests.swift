import XCTest
@testable import TomatoCore

/// The styles of the menu bar, without a screen.
final class MenuBarStyleTests: XCTestCase {
    func testTheThreeStylesAndTheDefault() {
        XCTAssertEqual(MenuBarStyle.allCases, [.tomatoOnly, .timerOnly, .both])
        XCTAssertEqual(MenuBarStyle.default, .both, "the tomato and the timer unless the user chose otherwise")
        XCTAssertEqual(MenuBarStyle.allCases.map(\.showsTimer), [false, true, true])
        XCTAssertEqual(MenuBarStyle.allCases.map { $0.showsTomato(timerRunning: true) }, [true, false, true])
    }

    /// Without the tomato the icon would be gone while nothing runs: at rest it is shown in every style.
    func testAtRestTheTomatoIsShownInEveryStyle() {
        for style in MenuBarStyle.allCases {
            XCTAssertTrue(style.showsTomato(timerRunning: false), "\(style)")
        }
    }

    func testTheStyleFromTheDefaultsAndFromTheOldSwitch() {
        XCTAssertEqual(MenuBarStyle.resolved(stored: nil, legacyShowTime: nil), .both)
        XCTAssertEqual(MenuBarStyle.resolved(stored: nil, legacyShowTime: true), .both)
        XCTAssertEqual(MenuBarStyle.resolved(stored: nil, legacyShowTime: false), .tomatoOnly, "the old switch off: the tomato alone")
        for style in MenuBarStyle.allCases {
            XCTAssertEqual(MenuBarStyle.resolved(stored: style.rawValue, legacyShowTime: false), style, "a chosen style wins")
            XCTAssertEqual(MenuBarStyle.resolved(stored: style.rawValue, legacyShowTime: nil), style)
        }
        XCTAssertEqual(MenuBarStyle.resolved(stored: "", legacyShowTime: nil), .both, "an empty or unknown text is no choice")
        XCTAssertEqual(MenuBarStyle.resolved(stored: "garbage", legacyShowTime: false), .tomatoOnly)
    }
}
