import XCTest
@testable import TomatoCore

/// The timer's logic with a clock the test moves by hand.
final class PomodoroTimerTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func later(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    func testItCountsDownAndEndsOnce() {
        var timer = PomodoroTimer(minutes: 25)
        XCTAssertTrue(timer.isIdle)
        XCTAssertEqual(timer.remaining(at: t0), 1500)
        timer.start(at: t0)
        XCTAssertTrue(timer.isRunning)
        XCTAssertEqual(timer.remaining(at: later(60)), 1440)
        XCTAssertNil(timer.finishIfDue(at: later(1499)))
        XCTAssertTrue(timer.isRunning)
        XCTAssertEqual(timer.finishIfDue(at: later(1500)), PomodoroTimer.Finish(minutes: 25, overdue: 0))
        XCTAssertTrue(timer.isIdle)
        XCTAssertNil(timer.finishIfDue(at: later(1501)), "an end is reported once")
        XCTAssertEqual(timer.remaining(at: later(1501)), 1500, "idle shows the whole length again")
    }

    func testPauseKeepsWhatIsLeftHoweverLongItWaits() {
        var timer = PomodoroTimer(minutes: 10)
        timer.start(at: t0)
        timer.pause(at: later(240))
        XCTAssertTrue(timer.isPaused)
        XCTAssertFalse(timer.isRunning)
        XCTAssertEqual(timer.remaining(at: later(240)), 360)
        XCTAssertEqual(timer.remaining(at: later(9000)), 360)
        XCTAssertNil(timer.finishIfDue(at: later(9000)))
        timer.resume(at: later(9000))
        XCTAssertEqual(timer.phase, .running(endsAt: later(9360)))
        XCTAssertNil(timer.finishIfDue(at: later(9359)))
        XCTAssertNotNil(timer.finishIfDue(at: later(9360)))
    }

    func testTheElapsedTimeIsWhatRanAndAPauseStopsIt() {
        var timer = PomodoroTimer(minutes: 25)
        XCTAssertEqual(timer.elapsed(at: later(100)), 0, "an idle timer has run for none")
        timer.start(at: t0)
        XCTAssertEqual(timer.elapsed(at: t0), 0)
        XCTAssertEqual(timer.elapsed(at: later(90.5)), 90.5, accuracy: 1e-9)
        timer.pause(at: later(120))
        XCTAssertEqual(timer.elapsed(at: later(120)), 120, accuracy: 1e-9)
        XCTAssertEqual(timer.elapsed(at: later(5000)), 120, accuracy: 1e-9, "a pause does not count")
        timer.resume(at: later(5000))
        XCTAssertEqual(timer.elapsed(at: later(5030)), 150, accuracy: 1e-9, "it goes on from where it stopped")
        XCTAssertEqual(timer.elapsed(at: later(5000 + 1380 + 10)), 1500, "never more than the length")
        XCTAssertEqual(timer.elapsed(at: later(-100)), 0, "a clock set back does not give a negative time")
    }

    func testAClockSetBackNeverShowsMoreThanTheLength() {
        var timer = PomodoroTimer(minutes: 25)
        timer.start(at: t0)
        XCTAssertEqual(timer.remaining(at: later(-7200)), 1500)
    }

    func testStopGoesBackToTheWholeLength() {
        var timer = PomodoroTimer(minutes: 5)
        timer.start(at: t0)
        timer.stop()
        XCTAssertTrue(timer.isIdle)
        XCTAssertEqual(timer.remaining(at: later(10)), 300)
        timer.start(at: later(10))
        timer.pause(at: later(20))
        timer.stop()
        XCTAssertTrue(timer.isIdle)
    }

    func testEachActionWorksOnlyWhereItMakesSense() {
        var timer = PomodoroTimer(minutes: 25)
        timer.pause(at: t0)
        timer.resume(at: t0)
        XCTAssertTrue(timer.isIdle, "nothing to pause or resume")
        timer.start(at: t0)
        timer.start(at: later(600))
        XCTAssertEqual(timer.phase, .running(endsAt: later(1500)), "a second start does not move the end")
        timer.resume(at: later(600))
        XCTAssertEqual(timer.phase, .running(endsAt: later(1500)))
        timer.pause(at: later(600))
        timer.pause(at: later(900))
        XCTAssertEqual(timer.remaining(at: later(900)), 900, "a second pause does not change what is left")
    }

    func testTheLengthStaysOnTheRulerAndChangesOnlyAtRest() {
        var timer = PomodoroTimer()
        XCTAssertEqual(timer.minutes, 25)
        timer.setMinutes(0)
        XCTAssertEqual(timer.minutes, 1)
        timer.setMinutes(90)
        XCTAssertEqual(timer.minutes, 60)
        timer.setMinutes(45)
        timer.start(at: t0)
        timer.setMinutes(10)
        XCTAssertEqual(timer.minutes, 45)
        XCTAssertEqual(timer.duration, 2700)
        XCTAssertEqual(PomodoroTimer(minutes: -3).minutes, 1)
    }

    func testAnEndNoticedLateIsStaleOnlyAfterAWhile() {
        var soon = PomodoroTimer(minutes: 1)
        soon.start(at: t0)
        let fresh = soon.finishIfDue(at: later(60 + 5 * 60))
        XCTAssertEqual(fresh?.overdue, 300)
        XCTAssertEqual(fresh?.isFresh, true)

        var late = PomodoroTimer(minutes: 1)
        late.start(at: t0)
        let stale = late.finishIfDue(at: later(60 + 3 * 3600))
        XCTAssertEqual(stale?.isFresh, false)
        XCTAssertTrue(late.isIdle, "a stale end still frees the timer")
    }
}

/// The saved state: what survives a restart of the app.
final class PomodoroStoreTests: XCTestCase {
    private let suite = "PomodoroStoreTests"
    private var defaults: UserDefaults!
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
        super.tearDown()
    }

    private func later(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    func testNothingSavedGivesAnIdleTwentyFiveMinutes() {
        let restored = PomodoroStore(defaults: defaults).restore(at: t0)
        XCTAssertEqual(restored.timer, PomodoroTimer())
        XCTAssertNil(restored.finish)
    }

    func testARunningTimerSurvivesARestart() {
        var timer = PomodoroTimer(minutes: 25)
        timer.start(at: t0)
        PomodoroStore(defaults: defaults).save(timer)
        // The next launch: a new store on the same defaults, five minutes later.
        let restored = PomodoroStore(defaults: defaults).restore(at: later(300))
        XCTAssertTrue(restored.timer.isRunning)
        XCTAssertEqual(restored.timer.remaining(at: later(300)), 1200)
        XCTAssertNil(restored.finish)
    }

    func testAPausedTimerSurvivesARestartAsItWas() {
        var timer = PomodoroTimer(minutes: 25)
        timer.start(at: t0)
        timer.pause(at: later(600))
        PomodoroStore(defaults: defaults).save(timer)
        let restored = PomodoroStore(defaults: defaults).restore(at: later(86400))
        XCTAssertTrue(restored.timer.isPaused)
        XCTAssertEqual(restored.timer.remaining(at: later(86400)), 900)
        XCTAssertNil(restored.finish)
    }

    func testTheChosenLengthSurvivesToo() {
        var timer = PomodoroTimer()
        timer.setMinutes(50)
        PomodoroStore(defaults: defaults).save(timer)
        XCTAssertEqual(PomodoroStore(defaults: defaults).load().minutes, 50)
    }

    func testATimerThatRanOutWhileTheAppWasAwayEndsOnceAtLaunch() {
        var timer = PomodoroTimer(minutes: 25)
        timer.start(at: t0)
        PomodoroStore(defaults: defaults).save(timer)
        let first = PomodoroStore(defaults: defaults).restore(at: later(1500 + 120))
        XCTAssertEqual(first.finish, PomodoroTimer.Finish(minutes: 25, overdue: 120))
        XCTAssertEqual(first.finish?.isFresh, true)
        XCTAssertTrue(first.timer.isIdle)
        let second = PomodoroStore(defaults: defaults).restore(at: later(1500 + 130))
        XCTAssertNil(second.finish, "the end is told once: the idle state was saved")
        XCTAssertTrue(second.timer.isIdle)
    }

    func testAnEndFromHoursAgoIsStale() {
        var timer = PomodoroTimer(minutes: 25)
        timer.start(at: t0)
        PomodoroStore(defaults: defaults).save(timer)
        let restored = PomodoroStore(defaults: defaults).restore(at: later(1500 + 5 * 3600))
        XCTAssertEqual(restored.finish?.isFresh, false)
        XCTAssertTrue(restored.timer.isIdle)
    }

    func testAnEndFurtherAwayThanTheTimerIsLongIsDropped() {
        var timer = PomodoroTimer(minutes: 25)
        timer.start(at: later(7200))
        PomodoroStore(defaults: defaults).save(timer)
        // The clock is two hours behind what it was when the timer started.
        let restored = PomodoroStore(defaults: defaults).restore(at: t0)
        XCTAssertTrue(restored.timer.isIdle)
        XCTAssertNil(restored.finish)
        XCTAssertTrue(PomodoroStore(defaults: defaults).load().isIdle, "and the idle state is saved")
    }

    func testDamagedDataIsIgnoredOrMendedNeverTrusted() {
        let store = PomodoroStore(defaults: defaults)
        defaults.set(Data("nonsense".utf8), forKey: PomodoroStore.key)
        XCTAssertEqual(store.load(), PomodoroTimer())
        defaults.set("not data", forKey: PomodoroStore.key)
        XCTAssertEqual(store.load(), PomodoroTimer())
        defaults.set(Data(#"{"minutes":500,"remaining":-5}"#.utf8), forKey: PomodoroStore.key)
        XCTAssertEqual(store.load(), PomodoroTimer(minutes: 60), "length clamped, a negative rest dropped")
        defaults.set(Data(#"{"minutes":0,"remaining":999999}"#.utf8), forKey: PomodoroStore.key)
        XCTAssertEqual(store.load(), PomodoroTimer(minutes: 1, phase: .paused(remaining: 3600)), "a rest never exceeds the ruler")
    }
}
