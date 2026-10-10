import XCTest
@testable import TomatoCore

/// The styles of the menu bar and the way the capsule comes in, both without a screen or a clock.
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

    /// Seconds of a clock that only goes forward, as the display link counts them.
    private let start: TimeInterval = 1000

    func testTheCapsuleComesInInAThirdOfASecondAndGoesOutALittleQuicker() {
        XCTAssertEqual(Fade.inDuration, 0.35)
        XCTAssertEqual(Fade.outDuration, 0.3)
        var fade = Fade()
        XCTAssertEqual(fade.value(at: start), 0)
        XCTAssertTrue(fade.isFinished(at: start))
        XCTAssertTrue(fade.isFinished(at: -start), "whatever the clock says")
        fade.move(to: 1, at: start, animated: true)
        XCTAssertEqual(fade.target, 1)
        XCTAssertEqual(fade.end, start + 0.35, accuracy: 1e-12)
        XCTAssertEqual(fade.value(at: start), 0, accuracy: 1e-12)
        XCTAssertFalse(fade.isFinished(at: start + 0.34))
        XCTAssertTrue(fade.isFinished(at: start + 0.35))
        XCTAssertEqual(fade.value(at: start + 0.35), 1, "at the end it is there exactly")
        XCTAssertEqual(fade.value(at: start + 5), 1)
        fade.move(to: 0, at: start + 10, animated: true)
        XCTAssertEqual(fade.end, start + 10.3, accuracy: 1e-12)
        XCTAssertEqual(fade.value(at: start + 10), 1, accuracy: 1e-12)
        XCTAssertGreaterThan(fade.value(at: start + 10.2), 0)
        XCTAssertFalse(fade.isFinished(at: start + 10.29))
        XCTAssertEqual(fade.value(at: start + 10.3), 0, "and gone exactly")
        XCTAssertTrue(fade.isFinished(at: start + 10.3))
    }

    /// Ease-out: it leaves quickly and slows down to a stop, never back and never past the end. Seen at 120 frames a second.
    func testItEasesOutWithoutOvershoot() {
        for (from, to) in [(0.0, 1.0), (1.0, 0.0)] {
            var fade = Fade(value: from)
            fade.move(to: to, at: start, animated: true)
            let count = 40
            let frames = (0...count).map { fade.value(at: start + (fade.end - start) * Double($0) / Double(count)) }
            XCTAssertEqual(frames.first, from)
            XCTAssertEqual(frames.last, to)
            XCTAssertTrue(frames.allSatisfy { (0.0...1.0).contains($0) }, "never past the end")
            let steps = zip(frames.dropFirst(), frames).map { abs($0 - $1) }
            XCTAssertEqual(steps, steps.sorted(by: >), "every frame a shorter step than the one before, none back")
            XCTAssertGreaterThan(steps[0], 1.5 / Double(count), "it leaves quicker than the average speed")
            XCTAssertLessThan(steps[count - 1], 0.1 / Double(count), "and comes to a stop")
            XCTAssertEqual(abs(frames[count / 2] - from), 0.75, accuracy: 0.1, "three quarters of the way in half the time")
        }
        XCTAssertEqual(Fade.easeOut(0), 0)
        XCTAssertEqual(Fade.easeOut(1), 1)
        XCTAssertEqual(Fade.easeOut(-1), 0)
        XCTAssertEqual(Fade.easeOut(2), 1)
    }

    /// With «Уменьшить движение» the capsule is there or gone at once, without a step between.
    func testWithReducedMotionItIsThereAtOnce() {
        var fade = Fade()
        fade.move(to: 1, at: start, animated: false)
        XCTAssertEqual(fade.value(at: start), 1)
        XCTAssertTrue(fade.isFinished(at: start))
        XCTAssertEqual(fade.end, start)
        fade.move(to: 0, at: start + 10, animated: false)
        XCTAssertEqual(fade.value(at: start + 10), 0)
        XCTAssertTrue(fade.isFinished(at: start + 10))
    }

    /// A change of mind half way goes on from where it is: nothing jumps.
    func testAChangeOfMindHalfWayStartsFromWhereItIs() {
        var fade = Fade()
        fade.move(to: 1, at: start, animated: true)
        let turning = start + 0.1
        let here = fade.value(at: turning)
        XCTAssertGreaterThan(here, 0)
        XCTAssertLessThan(here, 1)
        fade.move(to: 0, at: turning, animated: true)
        XCTAssertEqual(fade.value(at: turning), here, accuracy: 1e-12, "no jump")
        XCTAssertLessThan(fade.value(at: turning + 0.05), here)
        XCTAssertEqual(fade.value(at: turning + Fade.outDuration), 0)
    }
}
