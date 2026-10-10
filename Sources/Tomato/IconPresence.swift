import Foundation
import TomatoCore

/// How far the capsule of the menu bar item has come in. When a timer starts the item takes its full width at once and the
/// capsule comes in inside it, in about a third of a second (`Fade`, `MenuBarIcon.composition`); when the timer stops it goes
/// the same way back, the tomato already at rest, and the item narrows at once at the end. With «Уменьшить движение» it is
/// there or gone at once. A change of the style in Settings, a pause and the flash at the end do not move it: only the start
/// and the end of a timer do. There is no clock and no timer in here, every call is told what time it is, in seconds of a
/// clock that only goes forward (`CACurrentMediaTime`, the display link's `targetTimestamp`); `StatusItem` redraws the icon
/// while the capsule moves.
struct IconPresence {
    private var fade = Fade()
    /// The face whose capsule is on its way out once the timer is gone, drawn with the tomato at rest.
    private var departing: MenuBarIcon.TimerFace?

    /// The timer face has changed from `old` to `new`. Returns whether the capsule has begun to move.
    @discardableResult
    mutating func change(from old: MenuBarIcon.TimerFace?, to new: MenuBarIcon.TimerFace?, at now: TimeInterval,
                         reducesMotion: Bool) -> Bool {
        let shown = new?.capsule != nil
        guard shown != (fade.target > 0) else { return false }
        let animated = (old == nil) != (new == nil) && !reducesMotion
        if shown {
            // Coming in; what was leaving, if anything, is not needed any more.
            departing = nil
        } else if animated, var gone = old {
            gone.dial = 0
            departing = gone
        } else {
            departing = nil
        }
        fade.move(to: shown ? 1 : 0, at: now, animated: animated)
        return animated
    }

    /// How far the capsule has come, 0 (the tomato alone) to 1 (the face as it runs).
    func value(at now: TimeInterval) -> Double { fade.value(at: now) }

    /// Whether the capsule is still on its way.
    func isMoving(at now: TimeInterval) -> Bool { !fade.isFinished(at: now) }

    /// When the capsule is in or gone.
    var end: TimeInterval { fade.end }

    /// The face to draw: the current one, or, once the timer is gone and while its capsule is leaving, the one it had.
    /// When the capsule is all gone it is the current one again, nil, and the item is as narrow as the tomato.
    func face(_ current: MenuBarIcon.TimerFace?, at now: TimeInterval) -> MenuBarIcon.TimerFace? {
        if current?.capsule != nil { return current }
        return fade.value(at: now) > 0 ? departing : current
    }

    /// The movement is over: the face that left is forgotten.
    mutating func settle(at now: TimeInterval) {
        if fade.isFinished(at: now), fade.target == 0 { departing = nil }
    }
}
