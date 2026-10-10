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
