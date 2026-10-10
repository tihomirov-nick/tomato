import XCTest
import TomatoCore
@testable import Tomato

/// The capsule coming in and going out as a timer starts and stops, with a clock the test moves by hand: seconds of a clock
/// that only goes forward, as the display link counts them.
final class IconPresenceTests: XCTestCase {
    private let t0: TimeInterval = 1000

    private func face(_ text: String = "24:13", dial: Double = 0.3, outlined: Bool = false,
                      style: MenuBarStyle = .both) -> MenuBarIcon.TimerFace {
        .init(dial: dial, time: .init(text: text, sample: "00:00", outlined: outlined), style: style)
    }

    private func after(_ seconds: TimeInterval) -> TimeInterval { t0 + seconds }

    func testAtStartTheCapsuleComesInInAThirdOfASecond() {
        var presence = IconPresence()
        XCTAssertEqual(presence.value(at: t0), 0)
        XCTAssertNil(presence.face(nil, at: t0))
        let running = face()
        XCTAssertTrue(presence.change(from: nil, to: running, at: t0, reducesMotion: false), "it moves")
        XCTAssertEqual(presence.value(at: t0), 0, accuracy: 1e-12)
        XCTAssertEqual(presence.face(running, at: t0), running, "the face with its capsule from the first frame: the item is wide at once")
        XCTAssertEqual(presence.end, after(0.35), accuracy: 1e-12)
        XCTAssertTrue(presence.isMoving(at: after(0.3)))
        let middle = presence.value(at: after(0.175))
        XCTAssertGreaterThan(middle, 0.6, "well past the middle in half the time: it slows down towards the end")
        XCTAssertLessThan(middle, 0.9)
        XCTAssertEqual(presence.value(at: after(0.35)), 1, "in, exactly")
        XCTAssertFalse(presence.isMoving(at: after(0.35)))
        // The frames of the turning tomato are not a change of the capsule.
        XCTAssertFalse(presence.change(from: running, to: face(dial: 0.31), at: after(0.4), reducesMotion: false))
        XCTAssertEqual(presence.value(at: after(0.4)), 1)
    }

    /// At the stop the capsule goes the same way, with the time it had and the tomato already at rest, and the item stays
    /// wide until it is gone.
    func testAtTheEndTheCapsuleGoesOutWithTheTimeItHadAndTheTomatoAtRest() {
        var presence = IconPresence()
        let running = face("12:00", dial: 0.3)
        presence.change(from: nil, to: running, at: t0, reducesMotion: false)
        XCTAssertTrue(presence.change(from: running, to: nil, at: after(10), reducesMotion: false), "it moves")
        XCTAssertEqual(presence.end, after(10.3), accuracy: 1e-12, "a little quicker than it came")
        XCTAssertEqual(presence.value(at: after(10)), 1, accuracy: 1e-12)
        let leaving = presence.face(nil, at: after(10.1))
        XCTAssertEqual(leaving?.time.text, "12:00", "the capsule that is going out says what it said")
        XCTAssertEqual(leaving?.dial, 0, "while the tomato stands at rest")
        XCTAssertGreaterThan(presence.value(at: after(10.1)), 0)
        XCTAssertLessThan(presence.value(at: after(10.1)), 1)
        XCTAssertTrue(presence.isMoving(at: after(10.25)))
        XCTAssertNotNil(presence.face(nil, at: after(10.29)), "the item is wide until the capsule is gone")
        XCTAssertEqual(presence.value(at: after(10.3)), 0, "gone, exactly")
        XCTAssertFalse(presence.isMoving(at: after(10.3)))
        XCTAssertNil(presence.face(nil, at: after(10.3)), "the tomato alone, as narrow as at rest")
        presence.settle(at: after(10.3))
        XCTAssertNil(presence.face(nil, at: after(10.3)))
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

    /// Only the start and the end of a timer move the capsule. The style changing in Settings while it runs is at once, and
    /// so are a pause and the flash at the end, the capsule going from a plate to an outline.
    func testAChangeOfStyleAPauseAndTheFlashDoNotMoveIt() {
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
        XCTAssertFalse(presence.change(from: running, to: face(outlined: true), at: after(3), reducesMotion: false), "a pause")
        XCTAssertEqual(presence.value(at: after(3)), 1, "the flash keeps the capsule where it is too")
        XCTAssertFalse(presence.change(from: running, to: face(style: .timerOnly), at: after(4), reducesMotion: false))
        XCTAssertEqual(presence.value(at: after(4)), 1, "the time alone instead of both: at once")
    }

    /// With the tomato alone there is no capsule to come in or go out: starting and stopping change nothing in it.
    func testWithTheTomatoAloneNothingMoves() {
        var presence = IconPresence()
        let running = face(style: .tomatoOnly)
        XCTAssertFalse(presence.change(from: nil, to: running, at: t0, reducesMotion: false))
        XCTAssertEqual(presence.value(at: t0), 0)
        XCTAssertFalse(presence.change(from: running, to: nil, at: after(60), reducesMotion: false))
        XCTAssertNil(presence.face(nil, at: after(60)))
    }

    /// With the time alone the capsule grows out of the tomato: first the tomato shrinks a little and closes its cuts into a
    /// solid ball, then the ball fades into the plate, then the digits show. At the end it goes back into the tomato the same
    /// way.
    func testWithTheTimeAloneTheCapsuleGrowsOutOfTheTomatoAndGoesBackIntoIt() throws {
        var presence = IconPresence()
        let running = face(style: .timerOnly)
        let layout = MenuBarIcon.capsuleLayout(running.capsule)
        func composition(at time: TimeInterval, _ current: MenuBarIcon.TimerFace?) -> MenuBarIcon.Composition {
            MenuBarIcon.composition(face: presence.face(current, at: time), presence: CGFloat(presence.value(at: time)), layout: layout)
        }
        XCTAssertTrue(presence.change(from: nil, to: running, at: t0, reducesMotion: false))
        let first = composition(at: t0, running)
        XCTAssertNil(first.capsule, "nothing of the capsule in the first frame")
        XCTAssertEqual(first.tomato, MenuBarIcon.Placed(rect: first.tomato?.rect ?? .zero, alpha: 1, cuts: 1))
        let early = composition(at: after(0.03), running)
        let tomato = try XCTUnwrap(early.tomato), capsule = try XCTUnwrap(early.capsule)
        XCTAssertEqual(tomato.alpha, 1, "the tomato is still all there")
        XCTAssertLessThan(tomato.cuts, 1, "closing its cuts")
        XCTAssertGreaterThan(tomato.cuts, 0)
        XCTAssertLessThan(tomato.rect.width, MenuBarIcon.canvas.width, "and smaller")
        XCTAssertGreaterThan(capsule.alpha, 0, "while the plate comes")
        XCTAssertEqual(capsule.digits, 0, "no digits yet")
        XCTAssertLessThan(capsule.plate.width, capsule.home.width)
        let ball = try XCTUnwrap(composition(at: after(0.07), running).tomato)
        XCTAssertEqual(ball.cuts, 0, "a solid ball")
        XCTAssertLessThan(ball.alpha, 1, "fading into the plate")
        XCTAssertGreaterThan(ball.alpha, 0)
        let late = composition(at: after(0.25), running)
        XCTAssertNil(late.tomato, "the tomato is gone before the digits show")
        XCTAssertGreaterThan(late.capsule?.digits ?? 0, 0)
        XCTAssertEqual(late.capsule?.alpha, 1)
        XCTAssertEqual(composition(at: after(0.35), running), MenuBarIcon.composition(face: running, presence: 1, layout: layout))
        XCTAssertTrue(presence.change(from: running, to: nil, at: after(30), reducesMotion: false))
        XCTAssertEqual(presence.face(nil, at: after(30.1))?.style, .timerOnly)
        let going = composition(at: after(30.05), nil)
        XCTAssertLessThan(going.capsule?.digits ?? 1, 1, "the digits go first")
        XCTAssertNil(going.tomato, "before the tomato comes back")
        XCTAssertNotNil(composition(at: after(30.25), nil).tomato, "which it does at the end")
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
        XCTAssertEqual(presence.value(at: after(10.45)), 1)
        XCTAssertEqual(presence.face(running, at: after(10.2)), running)
    }
}
