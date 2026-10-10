import XCTest
@testable import TomatoCore

final class PresetsTests: XCTestCase {
    func testTheQuickPresetsAreFiveTenAndTwentyFive() {
        XCTAssertEqual(Presets.quick, [5, 10, 25])
    }

    func testOwnPresetsAreWholeMinutesOnTheRuler() {
        XCTAssertEqual(Presets.parse("15, 45"), [15, 45])
        XCTAssertEqual(Presets.parse("45; 15 15,\n30"), [15, 30, 45], "any separator, sorted, no repeats")
        XCTAssertEqual(Presets.parse("0, 61, abc, 7.5, -3, 30"), [30], "only 1…60 and whole numbers")
        XCTAssertEqual(Presets.parse("1,60"), [1, 60])
        XCTAssertEqual(Presets.parse(""), [])
        XCTAssertEqual(Presets.parse("   "), [])
    }

    func testThereAreNoMoreThanNineOfThem() {
        let many = Presets.parse((1...20).map(String.init).joined(separator: ","))
        XCTAssertEqual(many, Array(1...9))
    }

    func testTheFieldShowsTheCleanedUpList() {
        XCTAssertEqual(Presets.normalized("45 ;15,, 15 xx"), "15, 45")
        XCTAssertEqual(Presets.normalized("nothing"), "")
        XCTAssertEqual(Presets.format([20, 50]), "20, 50")
    }
}

final class TimerDisplayTests: XCTestCase {
    func testSecondsRoundUpSoZeroMeansRanOut() {
        XCTAssertEqual(TimerDisplay.seconds(1500), 1500)
        XCTAssertEqual(TimerDisplay.seconds(1499.2), 1500)
        XCTAssertEqual(TimerDisplay.seconds(0.4), 1)
        XCTAssertEqual(TimerDisplay.seconds(0), 0)
        XCTAssertEqual(TimerDisplay.seconds(-3), 0)
    }

    func testTheClockAlwaysHasTwoDigitsOfMinutes() {
        XCTAssertEqual(TimerDisplay.clock(1453), "24:13")
        XCTAssertEqual(TimerDisplay.clock(3600), "60:00")
        XCTAssertEqual(TimerDisplay.clock(59), "00:59")
        XCTAssertEqual(TimerDisplay.clock(0), "00:00")
        XCTAssertEqual(TimerDisplay.clock(-5), "00:00")
    }

    func testMinutesRoundUp() {
        XCTAssertEqual(TimerDisplay.minutes(1453), 25)
        XCTAssertEqual(TimerDisplay.minutes(1500), 25)
        XCTAssertEqual(TimerDisplay.minutes(1501), 26)
        XCTAssertEqual(TimerDisplay.minutes(1), 1)
        XCTAssertEqual(TimerDisplay.minutes(0), 0)
    }

    func testTheRedrawComesJustAfterTheSecondChanges() {
        XCTAssertEqual(TimerDisplay.untilNextChange(1500), 1.01, accuracy: 1e-9)
        XCTAssertEqual(TimerDisplay.untilNextChange(1499.25), 0.26, accuracy: 1e-9)
        XCTAssertEqual(TimerDisplay.untilNextChange(0.5), 0.51, accuracy: 1e-9)
    }

    func testTheDialTurnsSteadilyWithTheTimeTheTimerHasRun() {
        let dial = { TimerDisplay.dial(elapsed: $0, reducesMotion: false) }
        let turn = TimerDisplay.turnSeconds
        XCTAssertEqual(dial(0), 0, "it starts where a mark stands over the pointer")
        XCTAssertEqual(dial(-5), 0)
        XCTAssertEqual(dial(turn / 4), 0.25, accuracy: 1e-12)
        XCTAssertEqual(dial(turn / 2), 0.5, accuracy: 1e-12)
        XCTAssertEqual(dial(turn), 0, accuracy: 1e-12, "a full turn is back at the start")
        XCTAssertEqual(dial(7 * turn + turn / 8), 0.125, accuracy: 1e-9, "and goes on turning")
        // No steps: the angle grows by the same amount from frame to frame, a fraction of a mark's distance (a twelfth of
        // the turn), the turn wrapping round at 1.
        let frame = 1 / TimerDisplay.framesPerSecond
        var previous = dial(0)
        for i in 1...(Int(3 * turn / frame)) {
            let now = dial(Double(i) * frame)
            let step = (now - previous + 1).truncatingRemainder(dividingBy: 1)
            XCTAssertEqual(step, frame / turn, accuracy: 1e-9, "frame \(i)")
            XCTAssertLessThan(step, 1.0 / 12 / 10, "a frame moves the marks by under a tenth of their distance")
            previous = now
        }
    }

    func testTheFramesComeFifteenToThirtyTimesASecond() {
        XCTAssertGreaterThanOrEqual(TimerDisplay.framesPerSecond, 15)
        XCTAssertLessThanOrEqual(TimerDisplay.framesPerSecond, 30)
    }

    func testWithReducedMotionTheDialDoesNotTurn() {
        for elapsed in [0, 1, 4.3, 20, 61, 1500, 3600] as [TimeInterval] {
            XCTAssertEqual(TimerDisplay.dial(elapsed: elapsed, reducesMotion: true), 0, "after \(elapsed) s")
        }
    }

    func testTheFlashShakesTheDialByHalfAStepOfTheMarks() {
        XCTAssertEqual(TimerDisplay.flashDial(false), 0)
        XCTAssertEqual(TimerDisplay.flashDial(true) * 360, 15, accuracy: 1e-9, "the marks are 30 degrees apart")
    }
}
