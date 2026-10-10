import XCTest
import TomatoCore
@testable import Tomato

/// The running timer with a clock the test moves by hand, a defaults domain of its own and signals that only count.
/// Nothing ticks by itself, nothing sounds, nothing asks the system for anything.
@MainActor
final class TimerControllerTests: XCTestCase {
    private let suite = "TimerControllerTests"
    private var defaults: UserDefaults!
    private var time = Date(timeIntervalSince1970: 1_800_000_000)
    private var sounds = 0
    private var notifications: [Int] = []
    private var permissionAsks = 0
    private var icons: [MenuBarIcon.TimerFace?] = []
    private var reducesMotion = false
    private var iconVisible = true

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
        sounds = 0
        notifications = []
        permissionAsks = 0
        icons = []
        reducesMotion = false
        iconVisible = true
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
        super.tearDown()
    }

    /// A new launch of the app: another controller on the same saved state.
    private func launch(ticking: Bool = false) -> TimerController {
        let signals = TimerSignals(sound: { self.sounds += 1 }, notify: { self.notifications.append($0) },
                                   requestPermission: { self.permissionAsks += 1 })
        let controller = TimerController(store: PomodoroStore(defaults: defaults), settings: TimerSettings(defaults: defaults),
                                         signals: signals, now: { self.time }, icon: { self.icons.append($0) },
                                         reducesMotion: { self.reducesMotion }, iconVisible: { self.iconVisible },
                                         ticking: ticking)
        if !ticking { controller.begin() }
        return controller
    }

    private func pass(_ seconds: TimeInterval) {
        time = time.addingTimeInterval(seconds)
    }

    func testARunningTimerHoldsUpUpdatesAndAPausedOneDoesNot() {
        let controller = launch()
        XCTAssertFalse(controller.isBusy)
        controller.start()
        XCTAssertTrue(controller.isBusy)
        controller.pause()
        XCTAssertFalse(controller.isBusy)
        controller.resume()
        XCTAssertTrue(controller.isBusy)
        controller.stop()
        XCTAssertFalse(controller.isBusy)
        XCTAssertTrue(controller.timer.isIdle)
    }

    func testTheDisplayAndTheCapsuleFollowTheTimer() {
        let controller = launch()
        XCTAssertEqual(controller.seconds, 1500)
        XCTAssertNil(icons.last ?? nil, "no capsule at rest")
        controller.start()
        XCTAssertEqual(icons.last??.time, MenuBarIcon.TimeCapsule(text: "25:00", sample: "00:00"))
        pass(61)
        controller.tick()
        XCTAssertEqual(controller.seconds, 1439)
        XCTAssertEqual(icons.last??.time, MenuBarIcon.TimeCapsule(text: "23:59", sample: "00:00"))
        controller.pause()
        XCTAssertEqual(icons.last??.time, MenuBarIcon.TimeCapsule(text: "23:59", sample: "00:00", outlined: true))
        pass(3600)
        controller.tick()
        XCTAssertEqual(controller.seconds, 1439, "a paused timer stands still")
        controller.resume()
        pass(30)
        controller.tick()
        XCTAssertEqual(icons.last??.time, MenuBarIcon.TimeCapsule(text: "23:29", sample: "00:00"))
        controller.stop()
        XCTAssertNil(icons.last ?? nil)
        XCTAssertEqual(controller.seconds, 1500)
    }

    // MARK: The dial

    private var turn: Double { TimerDisplay.turnSeconds }

    func testTheDialTurnsWithTheTimeTheTimerHasRunAndStandsStillWhilePaused() {
        let controller = launch()
        XCTAssertNil(icons.last ?? nil, "at rest the tomato stands still, the app icon's way")
        controller.start()
        XCTAssertEqual(icons.last??.dial ?? -1, 0, accuracy: 1e-12, "it starts where a mark stands over the pointer")
        pass(5)
        controller.tick()
        XCTAssertEqual(icons.last??.dial ?? -1, 5 / turn, accuracy: 1e-9, "it turns as the time runs")
        pass(2.5)
        controller.frame()
        XCTAssertEqual(icons.last??.dial ?? -1, 7.5 / turn, accuracy: 1e-9, "between the ticks, too")
        controller.pause()
        let paused = icons.last??.dial
        XCTAssertEqual(paused ?? -1, 7.5 / turn, accuracy: 1e-9, "the pause shows the dial where it was")
        pass(3600)
        controller.tick()
        controller.frame()
        XCTAssertEqual(icons.last??.dial, paused, "a waiting timer's dial stands where it stopped")
        controller.resume()
        pass(1)
        controller.frame()
        XCTAssertEqual(icons.last??.dial ?? -1, 8.5 / turn, accuracy: 1e-9, "and goes on from there")
        pass(1500)
        controller.tick()
        XCTAssertEqual(icons.last??.dial, 0, "the end is the flash's zero")
    }

    func testTheDialGrowsSmoothlyFrameByFrameForAsLongAsTheTimerRuns() {
        let controller = launch()
        controller.start()
        let frame = 1 / TimerDisplay.framesPerSecond
        var dials: [Double] = []
        for _ in 0..<Int(2.5 * turn / frame) {
            pass(frame)
            controller.frame()
            dials.append(icons.last??.dial ?? -1)
        }
        // The same small step from frame to frame, the dial wrapping round to zero at a full turn. (A date in 2027 is told to
        // a quarter of a microsecond, so the steps agree to about 1e-8 of a turn.)
        for (before, after) in zip(dials, dials.dropFirst()) {
            XCTAssertEqual((after - before + 1).truncatingRemainder(dividingBy: 1), frame / turn, accuracy: 1e-7)
        }
        XCTAssertGreaterThanOrEqual(Set(dials.map { ($0 * 1e6).rounded() }).count, Int(turn / frame), "a new position for every frame")
    }

    func testTheTomatoTurnsOnlyWhileATimerRunsAndTheIconCanBeSeen() {
        let controller = launch()
        XCTAssertFalse(controller.isTurning, "at rest nothing redraws the icon")
        controller.start()
        XCTAssertTrue(controller.isTurning)
        controller.pause()
        XCTAssertFalse(controller.isTurning, "a pause stops the tomato")
        controller.resume()
        XCTAssertTrue(controller.isTurning)
        iconVisible = false
        controller.turningConditionsChanged()
        XCTAssertFalse(controller.isTurning, "nobody can see the icon")
        iconVisible = true
        controller.turningConditionsChanged()
        XCTAssertTrue(controller.isTurning)
        iconVisible = false
        pass(1)
        controller.tick()
        XCTAssertFalse(controller.isTurning, "a change nobody told us about is found at the next tick")
        iconVisible = true
        controller.tick()
        XCTAssertTrue(controller.isTurning)
        pass(1500)
        controller.tick()
        XCTAssertFalse(controller.isTurning, "at the end the capsule flashes and the tomato does not turn")
        controller.start()
        XCTAssertTrue(controller.isTurning)
        controller.stop()
        XCTAssertFalse(controller.isTurning)
    }

    /// The claim in the user's words: the frames have a timer only while the tomato turns; at rest and on a pause there is
    /// none. This one controller ticks for real (nothing fires: the test never lets the run loop run).
    func testTheFramesHaveATimerOnlyWhileTheTomatoTurns() throws {
        let controller = launch(ticking: true)
        XCTAssertNil(controller.frameTimer, "at rest no timer")
        controller.start()
        let timer = try XCTUnwrap(controller.frameTimer)
        XCTAssertTrue(timer.isValid)
        XCTAssertEqual(timer.timeInterval, 1 / TimerDisplay.framesPerSecond, accuracy: 1e-9)
        controller.pause()
        XCTAssertNil(controller.frameTimer, "on a pause no timer")
        XCTAssertFalse(timer.isValid)
        controller.resume()
        XCTAssertNotNil(controller.frameTimer)
        reducesMotion = true
        controller.turningConditionsChanged()
        XCTAssertNil(controller.frameTimer, "with reduced motion no timer")
        reducesMotion = false
        controller.turningConditionsChanged()
        XCTAssertNotNil(controller.frameTimer)
        controller.stop()
        XCTAssertNil(controller.frameTimer, "at rest again no timer")
    }

    func testWithReducedMotionTheTomatoDoesNotTurnAndTheTimeGoesOn() {
        reducesMotion = true
        let controller = launch()
        controller.start()
        XCTAssertFalse(controller.isTurning)
        for second in 1...5 {
            pass(1)
            controller.tick()
            XCTAssertEqual(icons.last??.dial, 0, "second \(second): the tomato stands still")
        }
        XCTAssertEqual(icons.last??.time.text, "24:55", "the capsule keeps the time")
        controller.pause()
        XCTAssertEqual(icons.last??.dial, 0)
        controller.resume()
        // Switched off while the timer runs: the tomato turns, as far as the time the timer has run puts it.
        reducesMotion = false
        controller.turningConditionsChanged()
        XCTAssertTrue(controller.isTurning)
        XCTAssertEqual(icons.last??.dial ?? -1, 5 / turn, accuracy: 1e-9)
        // And on again: it stops and stands at the start.
        reducesMotion = true
        controller.turningConditionsChanged()
        XCTAssertFalse(controller.isTurning)
        XCTAssertEqual(icons.last??.dial, 0)
    }

    func testTheTimeCanBeHiddenAndTheDialStillTurns() {
        defaults.set(false, forKey: TimerSettings.showTimeKey)
        let controller = launch()
        controller.start()
        pass(61)
        controller.tick()
        let face = icons.last ?? nil
        XCTAssertEqual(face?.showsTime, false)
        XCTAssertNil(face?.capsule, "no capsule is drawn")
        XCTAssertEqual(face?.time.text, "23:59", "VoiceOver still reads the time")
        XCTAssertEqual(face?.dial ?? -1, TimerDisplay.dial(elapsed: 61, reducesMotion: false), accuracy: 1e-9)
        defaults.set(true, forKey: TimerSettings.showTimeKey)
        let shown = launch()
        shown.begin()
        XCTAssertEqual((icons.last ?? nil)?.showsTime, true, "the time is shown unless Settings hide it")
    }

    func testWithoutSecondsTheCapsuleShowsMinutesRoundedUp() {
        defaults.set(false, forKey: TimerSettings.showSecondsKey)
        let controller = launch()
        controller.start()
        pass(61)
        controller.tick()
        XCTAssertEqual(icons.last??.time, MenuBarIcon.TimeCapsule(text: "24 мин", sample: "00 мин"))
        pass(60)
        controller.tick()
        XCTAssertEqual((icons.last ?? nil)?.time.text, "23 мин")
    }

    func testTheEndSoundsAndNotifiesOnceAndFlashes() {
        let controller = launch()
        controller.start()
        pass(1499)
        controller.tick()
        XCTAssertTrue(controller.isBusy)
        XCTAssertEqual(sounds, 0)
        pass(1)
        controller.tick()
        XCTAssertFalse(controller.isBusy)
        XCTAssertEqual(sounds, 1)
        XCTAssertEqual(notifications, [25])
        XCTAssertEqual(icons.last??.time, MenuBarIcon.TimeCapsule(text: "00:00", sample: "00:00"), "the capsule stays and flashes")
        XCTAssertEqual(icons.last??.dial, 0, "the dial is at zero")
        controller.flash()
        XCTAssertEqual(icons.last??.time, MenuBarIcon.TimeCapsule(text: "00:00", sample: "00:00", outlined: true))
        XCTAssertEqual(icons.last??.dial, TimerDisplay.flashDial(true), "the dial shakes with the flash")
        XCTAssertNotEqual(TimerDisplay.flashDial(true), TimerDisplay.flashDial(false))
        controller.tick()
        XCTAssertEqual(sounds, 1, "one end, one sound")
        for _ in 1..<TimerController.flashes { controller.flash() }
        XCTAssertNil(icons.last ?? nil, "after the last flash the glyph is back")
        XCTAssertEqual(controller.seconds, 1500)
    }

    func testStartingAgainStopsTheFlashing() {
        let controller = launch()
        controller.start()
        pass(1500)
        controller.tick()
        XCTAssertGreaterThan(controller.flashesLeft, 0)
        controller.start()
        XCTAssertEqual(controller.flashesLeft, 0)
        XCTAssertEqual(icons.last??.time, MenuBarIcon.TimeCapsule(text: "25:00", sample: "00:00"))
    }

    func testTheSwitchesInSettingsTurnTheSoundAndTheNotificationOff() {
        defaults.set(false, forKey: TimerSettings.endSoundKey)
        var controller = launch()
        controller.start()
        pass(1500)
        controller.tick()
        XCTAssertEqual(sounds, 0)
        XCTAssertEqual(notifications, [25])
        XCTAssertGreaterThan(controller.flashesLeft, 0, "the capsule flashes whatever the switches say")

        defaults.set(true, forKey: TimerSettings.endSoundKey)
        defaults.set(false, forKey: TimerSettings.endNotificationKey)
        controller = launch()
        controller.start()
        pass(1500)
        controller.tick()
        XCTAssertEqual(sounds, 1)
        XCTAssertEqual(notifications, [25], "no second notification")
    }

    func testThePermissionIsAskedAtAStartAndNowhereElse() {
        let controller = launch()
        XCTAssertEqual(permissionAsks, 0)
        controller.start()
        XCTAssertEqual(permissionAsks, 1)
        controller.pause()
        controller.resume()
        controller.stop()
        XCTAssertEqual(permissionAsks, 1)
    }

    func testARunningTimerGoesOnAfterARestart() {
        let first = launch()
        first.setMinutes(10)
        first.start()
        pass(240)
        // The app quits and opens again.
        let second = launch()
        XCTAssertTrue(second.timer.isRunning)
        XCTAssertTrue(second.isBusy)
        XCTAssertEqual(second.seconds, 360)
        XCTAssertEqual(icons.last??.time, MenuBarIcon.TimeCapsule(text: "06:00", sample: "00:00"))
        XCTAssertEqual(sounds, 0)
        pass(360)
        second.tick()
        XCTAssertEqual(sounds, 1)
        XCTAssertEqual(notifications, [10])
    }

    func testAPausedTimerComesBackPausedAfterARestart() {
        let first = launch()
        first.start()
        pass(300)
        first.pause()
        pass(7200)
        let second = launch()
        XCTAssertTrue(second.timer.isPaused)
        XCTAssertFalse(second.isBusy)
        XCTAssertEqual(second.seconds, 1200)
        XCTAssertEqual(icons.last??.time, MenuBarIcon.TimeCapsule(text: "20:00", sample: "00:00", outlined: true))
        XCTAssertEqual(sounds, 0)
        second.resume()
        XCTAssertTrue(second.isBusy)
    }

    func testATimerThatRanOutWhileTheAppWasAwayEndsAtTheNextLaunchOnce() {
        launch().start()
        pass(1500 + 90)
        let second = launch()
        XCTAssertTrue(second.timer.isIdle)
        XCTAssertEqual(sounds, 1)
        XCTAssertEqual(notifications, [25])
        _ = launch()
        XCTAssertEqual(sounds, 1, "told once")
    }

    func testAnEndFromHoursAgoPassesInSilence() {
        launch().start()
        pass(1500 + 4 * 3600)
        let second = launch()
        XCTAssertTrue(second.timer.isIdle)
        XCTAssertFalse(second.isBusy)
        XCTAssertEqual(sounds, 0)
        XCTAssertEqual(notifications, [])
        XCTAssertEqual(second.flashesLeft, 0)
    }

    func testTheLengthChangesOnlyAtRestAndIsRemembered() {
        let controller = launch()
        controller.setMinutes(10)
        XCTAssertEqual(controller.timer.minutes, 10)
        XCTAssertEqual(controller.seconds, 600)
        controller.setMinutes(500)
        XCTAssertEqual(controller.timer.minutes, 60)
        controller.setMinutes(10)
        controller.start()
        controller.setMinutes(50)
        XCTAssertEqual(controller.timer.minutes, 10, "not while it runs")
        controller.stop()
        XCTAssertEqual(launch().timer.minutes, 10, "remembered across a launch")
    }
}
