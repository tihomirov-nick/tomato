import AppKit
import Combine
import TomatoCore

/// The timer's settings from Settings, read from the app's defaults whenever they matter.
struct TimerSettings {
    static let showSecondsKey = "showSeconds"
    /// What the menu bar shows while a timer runs (`MenuBarStyle`). Before the styles there was a switch for the time
    /// alone, `showTimeKey`, which is still read when no style was chosen.
    static let menuBarStyleKey = "menuBarStyle"
    static let showTimeKey = "showTime"
    static let endSoundKey = "endSound"
    static let endNotificationKey = "endNotification"
    static let presetsKey = "customPresets"

    var defaults: UserDefaults = .standard

    /// The menu bar says «24:13»; without seconds, «25 мин».
    var showSeconds: Bool { defaults.object(forKey: Self.showSecondsKey) as? Bool ?? true }
    /// The tomato, the time in a capsule, or both while a timer runs: both unless the user chose otherwise.
    var menuBarStyle: MenuBarStyle {
        MenuBarStyle.resolved(stored: defaults.string(forKey: Self.menuBarStyleKey),
                              legacyShowTime: defaults.object(forKey: Self.showTimeKey) as? Bool)
    }
    var endSound: Bool { defaults.object(forKey: Self.endSoundKey) as? Bool ?? true }
    var endNotification: Bool { defaults.object(forKey: Self.endNotificationKey) as? Bool ?? true }
    var customPresets: [Int] { Presets.parse(defaults.string(forKey: Self.presetsKey) ?? "") }
}

/// What the timer does in the world, so tests and previews can leave the world alone.
struct TimerSignals {
    /// The end of the timer: the alarm, at the Mac's normal volume (AlarmSound), not one of the family's interface sounds.
    var sound: @MainActor () -> Void
    var notify: @MainActor (_ minutes: Int) -> Void
    /// At a start: macOS asks for the permission to show notifications, once.
    var requestPermission: @MainActor () -> Void

    static let system = TimerSignals(
        sound: { AlarmSound.play() },
        notify: { SystemNotifier.shared.post(minutes: $0) },
        requestPermission: { SystemNotifier.shared.requestPermissionIfNeeded() })

    static let silent = TimerSignals(sound: {}, notify: { _ in }, requestPermission: {})
}

/// The running timer: `PomodoroTimer` with a clock, a saved state, the display and the signals at the end. The panel
/// reads it, the menu bar icon shows it, and `AppActions.isBusy` asks it.
@MainActor
final class TimerController: ObservableObject {
    /// The app's timer. The preview renderer swaps in timers of its own for a moment.
    static var shared = TimerController(icon: { StatusItem.shared.face = $0 })

    @Published private(set) var timer: PomodoroTimer
    /// The whole seconds on the display: what is left, or the chosen length while nothing runs.
    @Published private(set) var seconds: Int

    private let store: PomodoroStore
    private let settings: TimerSettings
    private let signals: TimerSignals
    private let now: @MainActor () -> Date
    private let showIcon: @MainActor (MenuBarIcon.TimerFace?) -> Void
    /// «Уменьшить движение» in System Settings: the tomato then does not turn (and the capsule appears without fading, see
    /// `StatusItem`). It is read when something changes and at every tick, not for every frame.
    private let reducesMotion: @MainActor () -> Bool
    private var motionReduced = false
    /// Whether anybody can see the icon (`IconVisibility`): a tomato that nobody sees does not turn.
    private let iconVisible: @MainActor () -> Bool
    /// Off in tests and previews, where nothing may wake up by itself.
    private let ticking: Bool
    private var tickTimer: Timer?
    /// The timer of the frames: there only while `isTurning`, and only when the controller ticks at all.
    private(set) var frameTimer: Timer?
    private var flashTimer: Timer?
    private var defaultsObserver: NSObjectProtocol?
    private var motionObserver: NSObjectProtocol?
    private var visibilityObserver: NSObjectProtocol?
    /// The tomato's upper half is turning: its frames are being drawn, about fifteen a second, by a timer of their own (`ticking`
    /// allowing). It is so only while a timer runs, the icon can be seen and «Уменьшить движение» is off; at rest, on a
    /// pause and at the end nothing is redrawn but when something changes.
    private(set) var isTurning = false
    /// While the timer runs, macOS must not nap the app: a napping menu bar app redraws the capsule late and the end with it.
    private var activity: NSObjectProtocol?
    /// The capsule flashes at the end: this many changes of the capsule are left, and which look comes next.
    private(set) var flashesLeft = 0
    private var flashOutlined = false
    static let flashes = 16

    init(store: PomodoroStore = PomodoroStore(), settings: TimerSettings = TimerSettings(), signals: TimerSignals = .system,
         now: @escaping @MainActor () -> Date = Date.init, icon: @escaping @MainActor (MenuBarIcon.TimerFace?) -> Void = { _ in },
         reducesMotion: @escaping @MainActor () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion },
         iconVisible: @escaping @MainActor () -> Bool = { IconVisibility.shared.isVisible }, ticking: Bool = true) {
        self.store = store
        self.settings = settings
        self.signals = signals
        self.now = now
        self.showIcon = icon
        self.reducesMotion = reducesMotion
        self.motionReduced = reducesMotion()
        self.iconVisible = iconVisible
        self.ticking = ticking
        let timer = store.load()
        self.timer = timer
        self.seconds = TimerDisplay.seconds(timer.remaining(at: now()))
    }

    /// At launch: the saved timer goes on, or ends if it ran out while the app was away.
    func begin() {
        let restored = store.restore(at: now())
        timer = restored.timer
        if let finish = restored.finish { announce(finish) }
        refresh()
        schedule()
        guard ticking else { return }
        // A change in Settings (seconds or the style of the menu bar) shows in the icon at once, also while the timer waits.
        defaultsObserver = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil,
                                                                  queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        // «Уменьшить движение» and the icon going out of sight or coming back: the tomato stops turning or starts again.
        motionObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.turningConditionsChanged() }
        }
        IconVisibility.shared.start()
        visibilityObserver = NotificationCenter.default.addObserver(forName: IconVisibility.didChange, object: nil,
                                                                    queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.turningConditionsChanged() }
        }
    }

    /// A timer is running: an update waits for it, and so does the restart for a new interface language. A paused one
    /// does not hold anything up: it is saved and comes back after a restart as it was.
    var isBusy: Bool { timer.isRunning }

    // MARK: Actions

    func start() {
        guard timer.isIdle else { return }
        stopFlashing()
        timer.start(at: now())
        signals.requestPermission()
        commit()
    }

    func pause() {
        guard timer.isRunning else { return }
        timer.pause(at: now())
        commit()
    }

    func resume() {
        guard timer.isPaused else { return }
        timer.resume(at: now())
        commit()
    }

    func stop() {
        guard !timer.isIdle else { return }
        timer.stop()
        commit()
    }

    /// The ruler and the presets; only while nothing runs.
    func setMinutes(_ minutes: Int) {
        guard timer.isIdle, PomodoroTimer.clamped(minutes) != timer.minutes else { return }
        timer.setMinutes(minutes)
        commit()
    }

    /// The display's own timer calls this at every change of the second; tests call it after moving their clock.
    func tick() {
        motionReduced = reducesMotion()
        if let finish = timer.finishIfDue(at: now()) {
            store.save(timer)
            announce(finish)
        }
        refresh()
        schedule()
    }

    /// What lets the tomato turn has changed («Уменьшить движение», or the icon is out of sight or back): the icon is drawn
    /// as it should be now, and the frames start or stop.
    func turningConditionsChanged() {
        motionReduced = reducesMotion()
        refresh()
        syncFrames()
    }

    /// One frame of the turning tomato: the dial where the time the timer has run puts it. The frame timer calls this;
    /// tests call it after moving their clock.
    func frame() {
        showIcon(face())
    }

    // MARK: Inside

    private func commit() {
        store.save(timer)
        refresh()
        schedule()
    }

    private func refresh() {
        let shown = TimerDisplay.seconds(timer.remaining(at: now()))
        if shown != seconds { seconds = shown }
        showIcon(face())
    }

    /// The icon of the menu bar: while a timer runs, the tomato's upper half turning with the time the timer has run and the
    /// time left in a plate beside it (or the one or the other alone, as Settings choose, `MenuBarStyle`); while it waits,
    /// the upper half stands where it was and the capsule is an outline; nothing at rest, where the tomato stands still; and
    /// at the end the flash, the upper half shaking and the «00:00» alternating between plate and outline.
    func face() -> MenuBarIcon.TimerFace? {
        switch timer.phase {
        case .running: return face(seconds: seconds, dial: dial(), outlined: false)
        case .paused: return face(seconds: seconds, dial: dial(), outlined: true)
        case .idle:
            guard flashesLeft > 0 else { return nil }
            return face(seconds: 0, dial: TimerDisplay.flashDial(flashOutlined), outlined: flashOutlined)
        }
    }

    private func dial() -> Double {
        TimerDisplay.dial(elapsed: timer.elapsed(at: now()), reducesMotion: motionReduced)
    }

    private func face(seconds: Int, dial: Double, outlined: Bool) -> MenuBarIcon.TimerFace {
        let time: MenuBarIcon.TimeCapsule
        if settings.showSeconds {
            time = .init(text: TimerDisplay.clock(seconds), sample: "00:00", outlined: outlined)
        } else {
            time = .init(text: L("%@ мин", String(TimerDisplay.minutes(seconds))), sample: L("%@ мин", "00"), outlined: outlined)
        }
        return .init(dial: dial, time: time, style: settings.menuBarStyle)
    }

    /// The timer redraws itself at every change of the second, in the common run loop modes, so the time goes on while
    /// a menu is open or the ruler is dragged. The tomato's frames come from a timer of their own (`syncFrames`).
    private func schedule() {
        syncFrames()
        tickTimer?.invalidate()
        tickTimer = nil
        guard ticking else { return }
        if timer.isRunning, activity == nil {
            activity = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep,
                                                              reason: "A pomodoro timer is running")
        } else if !timer.isRunning, let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
        guard timer.isRunning else { return }
        let next = Timer(timeInterval: TimerDisplay.untilNextChange(timer.remaining(at: now())), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        next.tolerance = 0.02
        RunLoop.main.add(next, forMode: .common)
        tickTimer = next
    }

    /// The tomato turns while a timer runs, the icon can be seen and «Уменьшить движение» is off.
    var shouldTurn: Bool { timer.isRunning && !motionReduced && iconVisible() }

    /// Starts or stops the frames, as `shouldTurn` says. Asked at every tick, too, so that a change nobody told us about is
    /// found within a second.
    private func syncFrames() {
        let wanted = shouldTurn
        guard wanted != isTurning else { return }
        isTurning = wanted
        frameTimer?.invalidate()
        frameTimer = nil
        guard wanted, ticking else { return }
        let interval = 1 / TimerDisplay.framesPerSecond
        let next = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.frame() }
        }
        // The frames' times come from the clock, not from counting the timer's fires: a late fire only moves the next
        // picture a little, the speed stays. No tolerance: measured, a wake-up with some leeway costs the process twice
        // the processor time of one without.
        next.tolerance = 0
        RunLoop.main.add(next, forMode: .common)
        frameTimer = next
    }

    /// The end of a timer. One that ran out long ago (a sleep, a restart) passes in silence.
    private func announce(_ finish: PomodoroTimer.Finish) {
        guard finish.isFresh else { return }
        if settings.endSound { signals.sound() }
        if settings.endNotification { signals.notify(finish.minutes) }
        startFlashing()
    }

    private func startFlashing() {
        flashTimer?.invalidate()
        flashTimer = nil
        flashesLeft = Self.flashes
        flashOutlined = false
        guard ticking else { return }
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.flash() }
        }
        RunLoop.main.add(timer, forMode: .common)
        flashTimer = timer
    }

    /// One change of the flash: the dial at zero and a plate, the dial a step off and an outline, and so on, then the tomato
    /// stands still again.
    func flash() {
        flashesLeft -= 1
        flashOutlined.toggle()
        if flashesLeft <= 0 { stopFlashing() }
        refresh()
    }

    private func stopFlashing() {
        flashTimer?.invalidate()
        flashTimer = nil
        flashesLeft = 0
    }
}
