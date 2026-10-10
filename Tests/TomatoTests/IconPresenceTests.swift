import XCTest
import TomatoCore
@testable import Tomato

/// The capsule appearing and disappearing as a timer starts and stops, with a clock the test moves by hand.
final class IconPresenceTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func face(_ text: String = "24:13", dial: Double = 0.3, outlined: Bool = false,
                      style: MenuBarStyle = .both) -> MenuBarIcon.TimerFace {
        .init(dial: dial, time: .init(text: text, sample: "00:00", outlined: outlined), style: style)
    }

    private func after(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    func testAtStartTheCapsuleComesInInAQuarterOfASecond() {
        var presence = IconPresence()
        XCTAssertEqual(presence.value(at: t0), 0)
        XCTAssertNil(presence.face(nil, at: t0))
        let running = face()
        XCTAssertTrue(presence.change(from: nil, to: running, at: t0, reducesMotion: false), "it moves")
        XCTAssertEqual(presence.value(at: t0), 0, accuracy: 1e-12)
        XCTAssertEqual(presence.face(running, at: t0), running)
        XCTAssertTrue(presence.isMoving(at: after(0.1)))
        let middle = presence.value(at: after(0.125))
        XCTAssertGreaterThan(middle, 0.4)
        XCTAssertLessThan(middle, 0.6)
        XCTAssertEqual(presence.value(at: after(0.25)), 1, accuracy: 1e-12)
        XCTAssertFalse(presence.isMoving(at: after(0.25)))
        // The frames of the turning tomato are not a change of the capsule.
        XCTAssertFalse(presence.change(from: running, to: face(dial: 0.31), at: after(0.3), reducesMotion: false))
        XCTAssertEqual(presence.value(at: after(0.3)), 1)
    }

    /// At the stop the capsule goes the same way, with the time it had, and the tomato already at rest.
    func testAtTheEndTheCapsuleGoesOutWithTheTimeItHadAndTheTomatoAtRest() {
        var presence = IconPresence()
        let running = face("12:00", dial: 0.3)
        presence.change(from: nil, to: running, at: t0, reducesMotion: false)
        XCTAssertTrue(presence.change(from: running, to: nil, at: after(10), reducesMotion: false), "it moves")
        XCTAssertEqual(presence.value(at: after(10)), 1, accuracy: 1e-12)
        let leaving = presence.face(nil, at: after(10.1))
        XCTAssertEqual(leaving?.time.text, "12:00", "the capsule that is going out says what it said")
        XCTAssertEqual(leaving?.dial, 0, "while the tomato stands at rest")
        XCTAssertGreaterThan(presence.value(at: after(10.1)), 0)
        XCTAssertLessThan(presence.value(at: after(10.1)), 1)
        XCTAssertTrue(presence.isMoving(at: after(10.2)))
        XCTAssertEqual(presence.value(at: after(10.25)), 0, accuracy: 1e-12)
        XCTAssertFalse(presence.isMoving(at: after(10.25)))
        presence.settle(at: after(10.25))
        XCTAssertNil(presence.face(nil, at: after(10.25)), "gone: the tomato alone")
    }

    func testWithReducedMotionTheCapsuleIsThereAndGoneAtOnce() {
        var presence = IconPresence()
        let running = face()
        XCTAssertFalse(presence.change(from: nil, to: running, at: t0, reducesMotion: true), "nothing moves")
        XCTAssertEqual(presence.value(at: t0), 1)
        XCTAssertFalse(presence.isMoving(at: t0))
        XCTAssertFalse(presence.change(from: running, to: nil, at: after(5), reducesMotion: true))
        XCTAssertEqual(presence.value(at: after(5)), 0)
        XCTAssertNil(presence.face(nil, at: after(5)), "no capsule left behind")
    }

    /// Only the start and the end of a timer fade. The style changing in Settings while it runs is at once, and so is the
    /// flash at the end, the capsule going from a plate to an outline.
    func testAChangeOfStyleAndTheFlashAreNotFaded() {
        var presence = IconPresence()
        let running = face(style: .both)
        presence.change(from: nil, to: running, at: t0, reducesMotion: false)
        XCTAssertEqual(presence.value(at: after(1)), 1)
        let alone = face(style: .tomatoOnly)
        XCTAssertFalse(presence.change(from: running, to: alone, at: after(1), reducesMotion: false), "the tomato alone: at once")
        XCTAssertEqual(presence.value(at: after(1)), 0)
        XCTAssertEqual(presence.face(alone, at: after(1)), alone, "no capsule is held back")
        XCTAssertFalse(presence.change(from: alone, to: running, at: after(2), reducesMotion: false), "and back: at once")
        XCTAssertEqual(presence.value(at: after(2)), 1)
        XCTAssertFalse(presence.change(from: running, to: face(outlined: true), at: after(3), reducesMotion: false))
        XCTAssertEqual(presence.value(at: after(3)), 1, "the flash keeps the capsule where it is")
    }

    /// With the tomato alone there is no capsule to come in or go out: starting and stopping change nothing in it.
    func testWithTheTomatoAloneNothingFades() {
        var presence = IconPresence()
        let running = face(style: .tomatoOnly)
        XCTAssertFalse(presence.change(from: nil, to: running, at: t0, reducesMotion: false))
        XCTAssertEqual(presence.value(at: t0), 0)
        XCTAssertFalse(presence.change(from: running, to: nil, at: after(60), reducesMotion: false))
        XCTAssertNil(presence.face(nil, at: after(60)))
    }

    /// With the time alone the capsule takes the tomato's place, and at the end the tomato comes back as it goes.
    func testWithTheTimeAloneTheCapsuleTakesTheTomatosPlaceAndGivesItBack() {
        var presence = IconPresence()
        let running = face(style: .timerOnly)
        XCTAssertTrue(presence.change(from: nil, to: running, at: t0, reducesMotion: false))
        let mid = MenuBarIcon.composition(face: presence.face(running, at: after(0.125)), presence: CGFloat(presence.value(at: after(0.125))),
                                          layout: MenuBarIcon.capsuleLayout(running.capsule))
        XCTAssertEqual(mid.tomato?.alpha ?? -1, 0.5, accuracy: 0.1)
        XCTAssertEqual(mid.capsule?.alpha ?? -1, 0.5, accuracy: 0.1)
        XCTAssertTrue(presence.change(from: running, to: nil, at: after(30), reducesMotion: false))
        XCTAssertEqual(presence.face(nil, at: after(30.1))?.style, .timerOnly)
    }

    /// A timer started again while the capsule is still going out brings it back from where it is, with no jump.
    func testStartingAgainWhileTheCapsuleLeavesBringsItBackFromWhereItIs() {
        var presence = IconPresence()
        let running = face()
        presence.change(from: nil, to: running, at: t0, reducesMotion: false)
        presence.change(from: running, to: nil, at: after(10), reducesMotion: false)
        let here = presence.value(at: after(10.1))
        XCTAssertGreaterThan(here, 0)
        XCTAssertLessThan(here, 1)
        XCTAssertTrue(presence.change(from: nil, to: running, at: after(10.1), reducesMotion: false))
        XCTAssertEqual(presence.value(at: after(10.1)), here, accuracy: 1e-12, "no jump")
        XCTAssertGreaterThan(presence.value(at: after(10.2)), here)
        XCTAssertEqual(presence.value(at: after(10.35)), 1, accuracy: 1e-12)
        XCTAssertEqual(presence.face(running, at: after(10.2)), running)
    }
}
