import AppKit
import AVFoundation

/// The signal at the end of a timer. It is an alarm, not one of the family's interface sounds (SoundEffects.swift): those
/// play at the alert volume of System Settings, which many Macs keep at zero, so an alarm among them would go unheard. This
/// one plays through the Mac's output the way music does, at the normal volume, three times, with the classic «Glass» of
/// /System/Library/Sounds. The switch «Звуковые эффекты» is for the interface and does not touch it; its own switch is
/// «Звук в конце» in Settings, which `TimerController` reads before it asks for the alarm.
@MainActor
enum AlarmSound {
    static let file = URL(fileURLWithPath: "/System/Library/Sounds/Glass.aiff")
    static let times = 3

    /// What makes the noise; the tests swap it for a recorder.
    static var engine: (_ file: URL, _ times: Int) -> Void = playThroughTheOutput

    static func play() {
        engine(file, times)
    }

    /// The player that is sounding now, kept until the alarm is over or the next one starts.
    private static var player: AVAudioPlayer?

    private static func playThroughTheOutput(_ file: URL, _ times: Int) {
        player?.stop()
        player = nil
        guard let player = try? AVAudioPlayer(contentsOf: file) else {
            // The file is gone from this version of macOS: the system's beep, at the alert volume, is better than silence.
            NSSound.beep()
            return
        }
        player.numberOfLoops = max(0, times - 1)
        player.prepareToPlay()
        player.play()
        self.player = player
    }
}
