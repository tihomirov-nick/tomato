import AVFoundation
import XCTest
import TomatoCore
@testable import Tomato

/// The signal at the end of a timer: an alarm at the Mac's normal volume, apart from the family's interface sounds. The
/// tests swap the engine for a recorder: nothing here makes a sound.
@MainActor
final class AlarmSoundTests: XCTestCase {
    private var played: [(file: URL, times: Int)] = []
    private var engine: ((URL, Int) -> Void)!
    private let suite = "AlarmSoundTests"
    private var defaults: UserDefaults!
    private var time = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUp() {
        super.setUp()
        played = []
        engine = AlarmSound.engine
        AlarmSound.engine = { [unowned self] file, times in played.append((file, times)) }
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        AlarmSound.engine = engine
        UserDefaults.standard.removeObject(forKey: SoundEffects.enabledKey)
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testTheAlarmIsGlassThreeTimes() throws {
        AlarmSound.play()
        XCTAssertEqual(played.count, 1)
        XCTAssertEqual(played.first?.file.path, "/System/Library/Sounds/Glass.aiff")
        XCTAssertEqual(played.first?.times, 3)
        // The real engine can load the file: it is in this macOS and long enough to be heard.
        let player = try AVAudioPlayer(contentsOf: AlarmSound.file)
        XCTAssertGreaterThan(player.duration, 0.3)
    }

    /// The end of a timer as the app has it: the real alarm behind the signal, nothing else of the system.
    private func controller() -> TimerController {
        let signals = TimerSignals(sound: TimerSignals.system.sound, notify: { _ in }, requestPermission: {})
        let controller = TimerController(store: PomodoroStore(defaults: defaults), settings: TimerSettings(defaults: defaults),
                                         signals: signals, now: { self.time }, ticking: false)
        controller.begin()
        return controller
    }

    private func runOut(_ controller: TimerController) {
        controller.start()
        time = time.addingTimeInterval(1500)
        controller.tick()
    }

    func testTheSystemSignalPlaysTheAlarm() {
        TimerSignals.system.sound()
        XCTAssertEqual(played.count, 1)
    }

    func testTheSoundEffectsSwitchDoesNotTouchTheAlarm() {
        UserDefaults.standard.set(false, forKey: SoundEffects.enabledKey)
        XCTAssertFalse(SoundEffects.isEnabled, "the family's interface sounds are off")
        runOut(controller())
        XCTAssertEqual(played.count, 1, "the end of the timer still sounds")
    }

    func testOnlyTheSwitchAtTheEndTurnsTheAlarmOff() {
        defaults.set(false, forKey: TimerSettings.endSoundKey)
        runOut(controller())
        XCTAssertEqual(played.count, 0)
        defaults.set(true, forKey: TimerSettings.endSoundKey)
        runOut(controller())
        XCTAssertEqual(played.count, 1)
    }
}
