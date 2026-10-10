import AppKit
import UserNotifications
import TomatoCore

/// The system notification at the end of a timer. Only an app bundle can have notifications: `swift run`, the tests and
/// the preview renderer have none, and nothing here touches the notification center for them.
@MainActor
final class SystemNotifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = SystemNotifier()
    private static let identifier = "timer.end"

    static var isAvailable: Bool { Bundle.main.bundleURL.pathExtension == "app" }

    private lazy var center: UNUserNotificationCenter? = {
        guard Self.isAvailable else { return nil }
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        return center
    }()

    /// At the first start macOS asks whether Tomato may show notifications; later starts ask nothing. An answer «no» is
    /// final: the timer then ends with the sound and the flashing capsule only.
    func requestPermissionIfNeeded() {
        guard let center else { return }
        Task {
            guard await center.notificationSettings().authorizationStatus == .notDetermined else { return }
            _ = try? await center.requestAuthorization(options: [.alert])
        }
    }

    func post(minutes: Int) {
        guard let center else { return }
        Task {
            switch await center.notificationSettings().authorizationStatus {
            case .authorized, .provisional, .ephemeral: break
            default: return
            }
            let content = UNMutableNotificationContent()
            content.title = L("Время вышло")
            content.body = L("Таймер на %@ мин закончился", String(minutes))
            // The sound is the alarm the app plays itself (AlarmSound).
            content.sound = nil
            try? await center.add(UNNotificationRequest(identifier: Self.identifier, content: content, trigger: nil))
        }
    }

    /// The user said «no» in the system's question or in System Settings.
    func isDenied() async -> Bool {
        guard let center else { return false }
        return await center.notificationSettings().authorizationStatus == .denied
    }

    /// The page of Tomato in System Settings → Notifications.
    func openSystemSettings() {
        var link = "x-apple.systempreferences:com.apple.Notifications-Settings.extension"
        if let id = Bundle.main.bundleIdentifier { link += "?id=\(id)" }
        if let url = URL(string: link) { NSWorkspace.shared.open(url) }
    }

    /// A banner also while Tomato is the active app (Settings is open).
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .list]
    }
}
