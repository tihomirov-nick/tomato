import XCTest
@testable import TomatoCore

/// The styles of the menu bar and the fade of the capsule, both without a screen or a clock.
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

    // MARK: Fade

    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    func testTheCapsuleFadesInAQuarterOfASecond() {
        XCTAssertEqual(Fade.duration, 0.25)
        var fade = Fade()
        XCTAssertEqual(fade.value(at: start), 0)
        fade.move(to: 1, at: start, animated: true)
        XCTAssertEqual(fade.target, 1)
        XCTAssertEqual(fade.value(at: start), 0, accuracy: 1e-12)
        XCTAssertEqual(fade.value(at: start.addingTimeInterval(0.125)), 0.5, accuracy: 1e-9, "half way in half the time")
        XCTAssertEqual(fade.value(at: start.addingTimeInterval(0.25)), 1, accuracy: 1e-12)
        XCTAssertEqual(fade.value(at: start.addingTimeInterval(5)), 1)
        XCTAssertFalse(fade.isFinished(at: start.addingTimeInterval(0.2)))
        XCTAssertTrue(fade.isFinished(at: start.addingTimeInterval(0.25)))
        // Smooth, from nothing to all, and never back.
        let steps = (0...30).map { fade.value(at: start.addingTimeInterval(Double($0) / 120)) }
        XCTAssertEqual(steps, steps.sorted())
        XCTAssertTrue(steps.allSatisfy { (0.0...1.0).contains($0) })
    }

    func testItFadesOutTheSameWay() {
        var fade = Fade(value: 1)
        fade.move(to: 0, at: start, animated: true)
        XCTAssertEqual(fade.value(at: start), 1, accuracy: 1e-12)
        XCTAssertEqual(fade.value(at: start.addingTimeInterval(0.125)), 0.5, accuracy: 1e-9)
        XCTAssertEqual(fade.value(at: start.addingTimeInterval(0.25)), 0, accuracy: 1e-12)
        XCTAssertTrue(fade.isFinished(at: start.addingTimeInterval(0.26)))
    }

    /// With «Уменьшить движение» the capsule is there or gone at once, without a step between.
    func testWithReducedMotionItIsThereAtOnce() {
        var fade = Fade()
        fade.move(to: 1, at: start, animated: false)
        XCTAssertEqual(fade.value(at: start), 1)
        XCTAssertTrue(fade.isFinished(at: start))
        fade.move(to: 0, at: start.addingTimeInterval(10), animated: false)
        XCTAssertEqual(fade.value(at: start.addingTimeInterval(10)), 0)
    }

    /// A change of mind half way goes on from where it is: nothing jumps.
    func testAChangeOfMindHalfWayStartsFromWhereItIs() {
        var fade = Fade()
        fade.move(to: 1, at: start, animated: true)
        let turning = start.addingTimeInterval(0.1)
        let here = fade.value(at: turning)
        XCTAssertGreaterThan(here, 0)
        XCTAssertLessThan(here, 1)
        fade.move(to: 0, at: turning, animated: true)
        XCTAssertEqual(fade.value(at: turning), here, accuracy: 1e-12, "no jump")
        XCTAssertLessThan(fade.value(at: turning.addingTimeInterval(0.05)), here)
        XCTAssertEqual(fade.value(at: turning.addingTimeInterval(0.25)), 0, accuracy: 1e-12)
    }
}
