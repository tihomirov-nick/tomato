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

/// A value that eases between 0 and 1 over a quarter of a second: the capsule with the time appears and disappears so,
/// its width growing with it. It keeps no clock and no timer: every call is told what time it is.
public struct Fade: Equatable {
    public static let duration: TimeInterval = 0.25

    private var from: Double
    private var to: Double
    private var start: Date

    public init(value: Double = 0) {
        from = value
        to = value
        start = .distantPast
    }

    /// Where it is heading.
    public var target: Double { to }

    /// The value at `now`: a smooth step from where it was to where it is heading.
    public func value(at now: Date) -> Double {
        let t = min(max(now.timeIntervalSince(start) / Self.duration, 0), 1)
        return from + (to - from) * t * t * (3 - 2 * t)
    }

    public func isFinished(at now: Date) -> Bool {
        now.timeIntervalSince(start) >= Self.duration
    }

    /// Heads for `target` from wherever it is now. Without `animated` (the user asked for less motion) it is there at once.
    public mutating func move(to target: Double, at now: Date, animated: Bool) {
        let here = animated ? value(at: now) : target
        from = here
        to = target
        start = animated ? now : .distantPast
    }
}
