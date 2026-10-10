import Foundation
import TomatoCore

/// How much of the capsule the menu bar item shows. When a timer starts the capsule appears: the item widens and the capsule
/// shows up in about a quarter of a second (`Fade`); when the timer stops it goes the same way, the tomato already at rest.
/// With «Уменьшить движение» it is there or gone at once. A change of the style in Settings and the flash at the end do not
/// fade: only the start and the end of a timer do. There is no clock and no timer in here, every call is told what time it is;
/// `StatusItem` redraws the icon while the capsule moves.
struct IconPresence {
    private var fade = Fade()
    /// The face whose capsule is on its way out once the timer is gone, drawn with the tomato at rest.
    private var departing: MenuBarIcon.TimerFace?

    /// The timer face has changed from `old` to `new`. Returns whether the capsule has begun to move.
    @discardableResult
    mutating func change(from old: MenuBarIcon.TimerFace?, to new: MenuBarIcon.TimerFace?, at now: Date,
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
    func value(at now: Date) -> Double { fade.value(at: now) }

    /// Whether the capsule is still on its way.
    func isMoving(at now: Date) -> Bool { !fade.isFinished(at: now) }

    /// The face to draw: the current one, or, once the timer is gone and while its capsule is leaving, the one it had.
    func face(_ current: MenuBarIcon.TimerFace?, at now: Date) -> MenuBarIcon.TimerFace? {
        if current?.capsule != nil { return current }
        return fade.value(at: now) > 0 ? departing : current
    }

    /// The movement is over: the face that left is forgotten.
    mutating func settle(at now: Date) {
        if fade.isFinished(at: now), fade.target == 0 { departing = nil }
    }
}
