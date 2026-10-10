import Foundation

/// The pomodoro timer without a clock or a screen: every call is told what time it is. A running timer keeps the moment
/// it runs out, not the time left, so a restart of the app (or of the Mac) takes nothing from it: `PomodoroStore` saves
/// the state and `restore` reads it back.
public struct PomodoroTimer: Equatable {
    /// The lengths the ruler offers, in minutes.
    public static let minutesRange = 1...60
    public static let defaultMinutes = 25
    /// An end noticed later than this (the Mac slept through it, the app was off) is not announced: a sound or a banner
    /// a long time after the fact would only confuse.
    public static let freshFinish: TimeInterval = 15 * 60

    public enum Phase: Equatable {
        case idle
        /// Counting down; `endsAt` is the moment it runs out.
        case running(endsAt: Date)
        /// Stopped for a while with this much left.
        case paused(remaining: TimeInterval)
    }

    /// How a timer ended.
    public struct Finish: Equatable {
        public let minutes: Int
        /// How long ago it ran out: zero when the app was watching, more after sleep or a restart.
        public let overdue: TimeInterval
        /// Worth a sound and a notification: it ran out a moment ago.
        public var isFresh: Bool { overdue <= PomodoroTimer.freshFinish }
    }

    /// The chosen length. It changes only while nothing runs.
    public private(set) var minutes: Int
    public private(set) var phase: Phase

    public init(minutes: Int = defaultMinutes, phase: Phase = .idle) {
        self.minutes = Self.clamped(minutes)
        self.phase = phase
    }

    public static func clamped(_ minutes: Int) -> Int {
        min(max(minutes, minutesRange.lowerBound), minutesRange.upperBound)
    }

    public var duration: TimeInterval { TimeInterval(minutes * 60) }

    public var isIdle: Bool { phase == .idle }

    public var isRunning: Bool {
        if case .running = phase { return true }
        return false
    }

    public var isPaused: Bool {
        if case .paused = phase { return true }
        return false
    }

    /// What the display counts: the whole length while idle.
    public func remaining(at now: Date) -> TimeInterval {
        switch phase {
        case .idle: return duration
        // Never more than the length: a clock set back would otherwise show a time the ruler cannot even choose.
        case .running(let end): return min(duration, max(0, end.timeIntervalSince(now)))
        case .paused(let remaining): return remaining
        }
    }

    /// How long it has run: the length less what is left, so a pause does not count and an idle timer has run for none.
    public func elapsed(at now: Date) -> TimeInterval {
        duration - remaining(at: now)
    }

    public mutating func setMinutes(_ minutes: Int) {
        guard isIdle else { return }
        self.minutes = Self.clamped(minutes)
    }

    public mutating func start(at now: Date) {
        guard isIdle else { return }
        phase = .running(endsAt: now.addingTimeInterval(duration))
    }

    public mutating func pause(at now: Date) {
        guard case .running(let end) = phase else { return }
        phase = .paused(remaining: max(0, end.timeIntervalSince(now)))
    }

    public mutating func resume(at now: Date) {
        guard case .paused(let remaining) = phase else { return }
        phase = .running(endsAt: now.addingTimeInterval(remaining))
    }

    public mutating func stop() {
        phase = .idle
    }

    /// Back to idle when a running timer has run out by `now`; says how it ended, once.
    public mutating func finishIfDue(at now: Date) -> Finish? {
        guard case .running(let end) = phase, end <= now else { return nil }
        phase = .idle
        return Finish(minutes: minutes, overdue: now.timeIntervalSince(end))
    }
}

/// The timer in the app's own defaults, as one small JSON: the chosen length and, while it runs or waits, the end or
/// what is left.
public struct PomodoroStore {
    public static let key = "pomodoroTimer"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private struct Stored: Codable {
        var minutes: Int
        var endsAt: TimeInterval?
        var remaining: TimeInterval?
    }

    public func save(_ timer: PomodoroTimer) {
        var stored = Stored(minutes: timer.minutes)
        switch timer.phase {
        case .idle: break
        case .running(let end): stored.endsAt = end.timeIntervalSince1970
        case .paused(let remaining): stored.remaining = remaining
        }
        if let data = try? JSONEncoder().encode(stored) {
            defaults.set(data, forKey: Self.key)
        }
    }

    /// The timer as it was saved; an idle 25 minutes when nothing readable is there.
    public func load() -> PomodoroTimer {
        guard let data = defaults.data(forKey: Self.key), let stored = try? JSONDecoder().decode(Stored.self, from: data) else {
            return PomodoroTimer()
        }
        var timer = PomodoroTimer(minutes: stored.minutes)
        let longest = TimeInterval(PomodoroTimer.minutesRange.upperBound * 60)
        if let end = stored.endsAt, end.isFinite {
            timer = PomodoroTimer(minutes: stored.minutes, phase: .running(endsAt: Date(timeIntervalSince1970: end)))
        } else if let remaining = stored.remaining, remaining.isFinite, remaining >= 0 {
            timer = PomodoroTimer(minutes: stored.minutes, phase: .paused(remaining: min(remaining, longest)))
        }
        return timer
    }

    /// The timer at launch: running or paused as it was left, or back to idle with its end when it ran out while the
    /// app was away. The end is reported once: the idle state is saved before this returns.
    public func restore(at now: Date) -> (timer: PomodoroTimer, finish: PomodoroTimer.Finish?) {
        var timer = load()
        // An end further away than the timer is long cannot be right (damaged data, a clock set far back): dropped.
        if case .running(let end) = timer.phase, end.timeIntervalSince(now) > timer.duration + 1 {
            timer.stop()
            save(timer)
        }
        let finish = timer.finishIfDue(at: now)
        if finish != nil { save(timer) }
        return (timer, finish)
    }
}
