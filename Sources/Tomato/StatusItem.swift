import AppKit
import QuartzCore
import SwiftUI
import TomatoCore

/// The icon in the menu bar. A left click opens the app's panel under it, a right click or a Control-click opens the
/// menu of the family standard: the app's actions, then «Настройки…», «Проверить обновления…», «О приложении», «Завершить».
@MainActor
final class StatusItem: NSObject {
    static let shared = StatusItem()

    private var item: NSStatusItem?
    private lazy var panel = StatusPanel()

    /// The dot of a new version the user has not answered yet (see `Updates`).
    var showsBadge = false {
        didSet {
            guard showsBadge != oldValue else { return }
            refreshIcon()
        }
    }

    /// The running timer: the tomato's upper half turning and the time left in a capsule beside it (or instead of it, as
    /// Settings choose), nil when nothing runs and the tomato stands still (see `TimerController`). It is set about fifteen
    /// times a second while the tomato turns, but VoiceOver is told only when the time it reads changes.
    var face: MenuBarIcon.TimerFace? {
        didSet {
            guard face != oldValue else { return }
            let now = CACurrentMediaTime(), wasMoving = displayLink != nil
            if presence.change(from: oldValue, to: face, at: now,
                               reducesMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion) {
                startMoving(at: now)
            }
            // A capsule that starts to move takes its full width at once. While it moves, the display link draws every
            // frame, and the new face with it.
            if !wasMoving { draw(at: now) }
            if face?.time.text != oldValue?.time.text { item?.button?.setAccessibilityValue(face?.time.text) }
        }
    }

    /// The window the icon is drawn in, nil before `install`.
    var iconWindow: NSWindow? { item?.button?.window }

    // MARK: The capsule coming in and going out

    /// How far the capsule has come (`IconPresence`), on the clock of the display (`CACurrentMediaTime`).
    private var presence = IconPresence()
    /// While the capsule moves, the display link redraws the icon in step with the screen, up to 120 times a second, each
    /// frame with the capsule where it is at the moment the frame is shown (`targetTimestamp`). It is there only while the
    /// capsule moves.
    private var displayLink: CADisplayLink?
    /// The end of the movement, in case the display link gives no frames, as while the menu bar is hidden: the movement
    /// depends on the time alone, so a frame drawn after its end finishes it.
    private var endTimer: Timer?

    private func startMoving(at now: CFTimeInterval) {
        if displayLink == nil, let button = item?.button {
            let link = button.displayLink(target: self, selector: #selector(displayFrame(_:)))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
            link.add(to: .main, forMode: .common)
            displayLink = link
        }
        endTimer?.invalidate()
        let timer = Timer(timeInterval: max(presence.end - now, 0) + 0.05, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.finishMoving(at: max(CACurrentMediaTime(), self.presence.end))
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        endTimer = timer
    }

    @objc private func displayFrame(_ link: CADisplayLink) {
        let time = link.targetTimestamp
        if presence.isMoving(at: time) {
            draw(at: time)
        } else {
            finishMoving(at: time)
        }
    }

    /// The capsule is in or gone: the last frame, and nothing redraws the icon again until something changes.
    private func finishMoving(at time: CFTimeInterval) {
        displayLink?.invalidate()
        displayLink = nil
        endTimer?.invalidate()
        endTimer = nil
        presence.settle(at: time)
        draw(at: time)
    }

    private func refreshIcon() {
        if displayLink == nil { draw(at: CACurrentMediaTime()) }
    }

    private func draw(at time: CFTimeInterval) {
        item?.button?.image = image(at: time)
    }

    /// The icon at `time`: the face, with the capsule as far in as it has come by then.
    private func image(at time: CFTimeInterval) -> NSImage {
        MenuBarIcon.image(badge: showsBadge, face: presence.face(face, at: time), presence: presence.value(at: time))
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = image(at: CACurrentMediaTime())
        item.button?.toolTip = "Tomato"
        item.button?.setAccessibilityLabel("Tomato")
        item.button?.target = self
        item.button?.action = #selector(clicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        self.item = item
    }

    @objc private func clicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showMenu()
        } else if panel.isVisible || panel.closedByThisClick {
            panel.dismiss()
        } else {
            showPanel()
        }
    }

    /// The panel under the icon; from the menu, at launch and when the app is opened again while it runs.
    func showPanel() {
        guard let button = item?.button, let window = button.window else { return }
        panel.show(under: window.convertToScreen(button.convert(button.bounds, to: nil)))
    }

    private func showMenu() {
        panel.dismiss()
        guard let item else { return }
        // The menu belongs to the item only while it is open: a left click keeps opening the panel.
        item.menu = Self.menu()
        item.button?.performClick(nil)
        item.menu = nil
    }

    /// The menu of the icon: the app's actions (`AppActions.menuItems`), then the part every app of the family shares.
    /// Its actions go to the app delegate.
    static func menu() -> NSMenu {
        let menu = NSMenu()
        let actions = AppActions.menuItems()
        actions.forEach(menu.addItem)
        if !actions.isEmpty { menu.addItem(.separator()) }
        menu.addItem(withTitle: L("Настройки…"), action: #selector(AppDelegate.showSettings(_:)), keyEquivalent: ",")
        menu.addItem(withTitle: L("Проверить обновления…"), action: #selector(AppDelegate.checkForUpdates(_:)), keyEquivalent: "")
        menu.addItem(withTitle: L("О приложении «Tomato»"), action: #selector(AppDelegate.showAbout(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: L("Завершить Tomato"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }
}

/// The app's main window: a black panel right under the menu bar icon, the family's dark style with no arrow. It takes
/// the keyboard without bringing the app forward, so fields in it work and the app in front stays in front. It closes
/// on a click elsewhere, on Esc, on a second click on the icon and when the menu or Settings open. Its size follows the
/// content, the top stays under the icon.
@MainActor
final class StatusPanel: NSPanel, NSWindowDelegate {
    /// The icon's frame on screen, to stay under it while the content changes size.
    private var anchor: NSRect = .zero
    private var keyMonitor: Any?
    /// When the panel last closed because it lost the keyboard.
    private var resignedAt = Date.distantPast

    /// The panel closed a moment ago because another window took the keyboard: the click on the icon that caused it
    /// should not open it again.
    var closedByThisClick: Bool { Date().timeIntervalSince(resignedAt) < 0.3 }

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 300, height: 120), styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
        appearance = NSAppearance(named: .darkAqua)
        let hosting = NSHostingController(rootView: PanelView())
        hosting.sizingOptions = [.preferredContentSize]
        contentViewController = hosting
        delegate = self
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func show(under anchor: NSRect) {
        self.anchor = anchor
        // The size of the content before the first placing: SwiftUI would otherwise resize the panel after it shows.
        if let view = contentViewController?.view {
            view.layoutSubtreeIfNeeded()
            let size = view.fittingSize
            if size.width > 0, size.height > 0 { setContentSize(size) }
        }
        place()
        makeKeyAndOrderFront(nil)
        // Esc closes the panel, a field in it included.
        keyMonitor = keyMonitor ?? NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.keyCode == 53, self.isKeyWindow else { return event }
            self.dismiss()
            return nil
        }
        // The shadow follows the drawn corners once SwiftUI has drawn them.
        DispatchQueue.main.async { [weak self] in self?.invalidateShadow() }
    }

    func dismiss() {
        guard isVisible else { return }
        orderOut(nil)
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        Updates.panelClosed()
    }

    /// Centered under the icon, inside the screen, 6 pt below the menu bar.
    private func place() {
        let size = frame.size
        let screen = NSScreen.screens.first { $0.frame.intersects(anchor) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(origin: .zero, size: size)
        var x = anchor.midX - size.width / 2
        x = max(visible.minX + 8, min(x, visible.maxX - size.width - 8))
        setFrameTopLeftPoint(NSPoint(x: x.rounded(), y: min(anchor.minY, visible.maxY) - 6))
    }

    func windowDidResize(_ notification: Notification) {
        guard anchor != .zero else { return }
        place()
        invalidateShadow()
    }

    func windowDidResignKey(_ notification: Notification) {
        guard isVisible else { return }
        resignedAt = Date()
        dismiss()
    }
}

/// What the panel shows: the update when there is something to say about it, and the app's main view.
struct PanelView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.gap) {
            UpdateCard()
            MainView()
        }
        .padding(Metrics.inset)
        .frame(width: 300)
        .background(Color.black, in: RoundedRectangle(cornerRadius: Metrics.panelRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Metrics.panelRadius, style: .continuous)
            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        .foregroundStyle(.white)
        .tint(Brand.color)
        .environment(\.colorScheme, .dark)
        .fixedSize(horizontal: false, vertical: true)
    }
}
