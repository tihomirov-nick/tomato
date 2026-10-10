import AppKit

/// Whether anybody can see the menu bar icon. Nobody does while the Mac sleeps or its screens are off, the screen is
/// locked or the screen saver runs, the user's session is in the background (fast user switching), or the icon's window is
/// covered (a full-screen app has taken the menu bar, another app has hidden the icon). A tomato that turns for nobody only
/// wastes the processor, so `TimerController` asks and stops its frames.
///
/// The icon counts as visible until something says otherwise, so a notification that never comes can make the tomato turn
/// when nobody looks, never stand still when somebody does.
@MainActor
final class IconVisibility {
    static let shared = IconVisibility()
    /// Posted when `isVisible` changes.
    static let didChange = Notification.Name("TomatoIconVisibilityDidChange")

    private enum Reason { case asleep, screensOff, backgroundSession, locked, screenSaver, covered }
    private var hiddenBy: Set<Reason> = []
    private var started = false

    var isVisible: Bool { hiddenBy.isEmpty }

    /// Starts listening; the notifications stay for the life of the app.
    func start() {
        guard !started else { return }
        started = true
        let workspace = NSWorkspace.shared.notificationCenter, distributed = DistributedNotificationCenter.default()
        let notices: [(NotificationCenter, Notification.Name, Reason, hides: Bool)] = [
            (workspace, NSWorkspace.willSleepNotification, .asleep, true),
            (workspace, NSWorkspace.didWakeNotification, .asleep, false),
            (workspace, NSWorkspace.screensDidSleepNotification, .screensOff, true),
            (workspace, NSWorkspace.screensDidWakeNotification, .screensOff, false),
            (workspace, NSWorkspace.sessionDidResignActiveNotification, .backgroundSession, true),
            (workspace, NSWorkspace.sessionDidBecomeActiveNotification, .backgroundSession, false),
            (distributed, Notification.Name("com.apple.screenIsLocked"), .locked, true),
            (distributed, Notification.Name("com.apple.screenIsUnlocked"), .locked, false),
            (distributed, Notification.Name("com.apple.screensaver.didstart"), .screenSaver, true),
            (distributed, Notification.Name("com.apple.screensaver.didstop"), .screenSaver, false)]
        for (center, name, reason, hides) in notices {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.set(reason, hides: hides) }
            }
        }
        // The icon's own window is occluded when a full-screen app takes the menu bar or something hides the icon.
        NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: nil,
                                               queue: .main) { [weak self] note in
            MainActor.assumeIsolated {
                guard let window = note.object as? NSWindow, window === StatusItem.shared.iconWindow else { return }
                self?.set(.covered, hides: !window.occlusionState.contains(.visible))
            }
        }
    }

    private func set(_ reason: Reason, hides: Bool) {
        let before = isVisible
        if hides { hiddenBy.insert(reason) } else { hiddenBy.remove(reason) }
        if isVisible != before { NotificationCenter.default.post(name: Self.didChange, object: self) }
    }
}
