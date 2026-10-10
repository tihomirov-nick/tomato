import Foundation

/// What the menu bar shows while a timer runs, as the user chose in Settings: the tomato alone, the time alone, or both.
/// While no timer runs the tomato is always shown, since without it the icon would be gone from the menu bar.
public enum MenuBarStyle: String, CaseIterable, Equatable {
    case tomatoOnly, timerOnly, both

    public static let `default`: MenuBarStyle = .both

    /// The time in its capsule is drawn while a timer runs.
    public var showsTimer: Bool { self != .tomatoOnly }

    /// The tomato is drawn: always at rest, and while a timer runs in every style but `timerOnly`.
    public func showsTomato(timerRunning: Bool) -> Bool { !timerRunning || self != .timerOnly }

    /// The style from what the defaults hold: the one the user picked, or, for a copy that was set up before the styles,
    /// the old switch «Показывать время в строке меню» (off meant the tomato alone); `both` when nothing was chosen.
    public static func resolved(stored: String?, legacyShowTime: Bool?) -> MenuBarStyle {
        if let stored, let style = MenuBarStyle(rawValue: stored) { return style }
        return legacyShowTime == false ? .tomatoOnly : .default
    }
}

/// A value that eases between 0 and 1: how far the capsule with the time has come in. It comes in over 0.35 s and goes
/// out over 0.3 s, quickly at first and slowing down to a stop at the end, never past it (`easeOut`). It keeps no clock and
/// no timer: every call is told what time it is, in seconds of a clock that only goes forward (the display link's
/// `targetTimestamp`, `CACurrentMediaTime`), so the value depends on the time alone and a frame that comes late is simply
/// further on.
public struct Fade: Equatable {
    public static let inDuration: TimeInterval = 0.35
    public static let outDuration: TimeInterval = 0.3

    private var from: Double
    private var to: Double
    /// When the last move began; a value that has never moved has been where it is for ever.
    private var start: TimeInterval = -.infinity
    private var duration: TimeInterval = 0

    public init(value: Double = 0) {
        from = value
        to = value
    }

    /// Where it is heading.
    public var target: Double { to }

    /// When it gets there.
    public var end: TimeInterval { start + duration }

    /// The value at `now`: from where it was to where it is heading, eased out. At the end it is the target exactly.
    public func value(at now: TimeInterval) -> Double {
        guard duration > 0, now < end else { return to }
        let t = max((now - start) / duration, 0)
        return from + (to - from) * Self.easeOut(t)
    }

    public func isFinished(at now: TimeInterval) -> Bool { now >= end }

    /// Heads for `target` from wherever it is now, in `inDuration` up and `outDuration` down. Without `animated` (the
    /// user asked for less motion) it is there at once.
    public mutating func move(to target: Double, at now: TimeInterval, animated: Bool) {
        let here = value(at: now)
        from = animated ? here : target
        to = target
        start = now
        duration = animated && target != here ? (target > here ? Self.inDuration : Self.outDuration) : 0
    }

    /// The ease-out, 0 at 0 and 1 at 1: it leaves at twice the average speed and slows down evenly to a stop, with no
    /// overshoot.
    public static func easeOut(_ t: Double) -> Double {
        let left = 1 - min(max(t, 0), 1)
        return 1 - left * left
    }
}
