import Foundation

/// The lengths in the panel: three quick ones, and the user's own, written in Settings as «15, 45».
public enum Presets {
    public static let quick = [5, 10, 25]
    /// How many own presets the menu of «…» holds.
    public static let limit = 9

    /// The own presets in a text: whole minutes on the ruler, separated by commas, semicolons or spaces. Anything else is
    /// skipped; the rest is sorted and has no repeats.
    public static func parse(_ text: String) -> [Int] {
        let separators = CharacterSet(charactersIn: ",;").union(.whitespacesAndNewlines)
        let minutes = text.components(separatedBy: separators)
            .compactMap { Int($0) }
            .filter { PomodoroTimer.minutesRange.contains($0) }
        return Array(Set(minutes).sorted().prefix(limit))
    }

    public static func format(_ minutes: [Int]) -> String {
        minutes.map(String.init).joined(separator: ", ")
    }

    /// What the field in Settings shows after the text is entered.
    public static func normalized(_ text: String) -> String {
        format(parse(text))
    }
}

/// The time as the display writes it.
public enum TimerDisplay {
    /// Whole seconds, rounded up, so «00:00» appears only when the time has run out.
    public static func seconds(_ remaining: TimeInterval) -> Int {
        Int(max(0, remaining).rounded(.up))
    }

    /// «24:13»; always two digits of minutes, so the width of a monospaced display stays the same.
    public static func clock(_ seconds: Int) -> String {
        let seconds = max(0, seconds)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    /// Whole minutes, rounded up: 24:13 is 25.
    public static func minutes(_ seconds: Int) -> Int {
        (max(0, seconds) + 59) / 60
    }

    /// How long the menu bar tomato's upper half takes for a full turn while a timer runs. At 16 seconds the marks cross the
    /// middle of the belt of the 16 pt tomato at about 2.6 pt a second, and one passes the pointer every 1.3 seconds: the eye
    /// sees them go. A turn a minute would be 0.7 pt a second, which looks still.
    public static let turnSeconds: TimeInterval = 16

    /// The menu bar tomato's dial after a timer has run for `elapsed` seconds: how far the upper half is turned from
    /// where it started, as a part of the full turn, 0..<1. The tomato does not show the time left (the capsule does); it
    /// turns steadily, without steps, a full turn in `turnSeconds`, so that the eye sees the timer going. It starts at 0,
    /// where a mark stands over the pointer, and a pause, which stops the elapsed time, stops the dial. With «Уменьшить
    /// движение» it does not turn at all.
    public static func dial(elapsed: TimeInterval, reducesMotion: Bool) -> Double {
        guard !reducesMotion, elapsed.isFinite, elapsed > 0 else { return 0 }
        let turns = elapsed / turnSeconds
        return turns - turns.rounded(.down)
    }

    /// How many times a second the menu bar tomato is redrawn while it turns. Fifteen is enough for the turn to look smooth
    /// (a frame moves the marks by a fraction of a pixel) and keeps the redraws, and the CPU they take, to a minimum.
    public static let framesPerSecond: Double = 15

    /// The dial of the flash at the end: the upper half shakes between zero and half the distance between two marks, so
    /// the marks jump by a visible step.
    public static func flashDial(_ on: Bool) -> Double {
        on ? 1.0 / 24 : 0
    }

    /// How long until what the display shows changes, for the timer that redraws it: the next whole second, plus a
    /// hair, so the redraw lands just after the change and not just before.
    public static func untilNextChange(_ remaining: TimeInterval) -> TimeInterval {
        let fraction = remaining - remaining.rounded(.down)
        return (fraction == 0 ? 1 : fraction) + 0.01
    }
}
