import AppKit
import SwiftUI
import TomatoCore

// The places where an app made from the template becomes itself. The rest of Sources/Tomato is the family's
// plumbing: the icon with its menu and panel, Settings, updates, the interface language and the sounds. The timer
// itself is in TimerController.swift, the ruler in Ruler.swift, the time capsule of the menu bar in MenuBarCapsule.swift,
// the notification in SystemNotifier.swift and the logic without a screen in TomatoCore.

// MARK: - 1. The glyph

extension MenuBarIcon {
    /// The tomato in the menu bar, a kitchen timer cut in two: the upper half is the dial, and `dial` is how far it is
    /// turned (0 at rest, the part of a full turn while a timer runs). Glyph.swift and Tomato.swift draw it, the same code
    /// that draws the mark of the app icon (scripts/make_icon.swift); they size and place the glyph themselves, 16 pt tall.
    /// The glyph is drawn in two parts, because only the upper half moves: `drawGlyphBase` is the rest, drawn once and kept
    /// (`IconFrames`), `drawGlyphTop` the calyx, the stem and the marks over it, drawn again for every frame. While a timer
    /// runs, the time's capsule is drawn beside it (MenuBarCapsule.swift).
    ///
    /// Both draw into a context that counts in points with y down on the mark's canvas, `scale` pixels to the point.
    static func drawGlyphBase(in ctx: CGContext, scale: CGFloat) {
        // `enterMenuBox` moves and scales the context into the glyph's 100-unit box; the capsule and the dot of an update
        // are drawn after the glyph in points again.
        ctx.saveGState()
        defer { ctx.restoreGState() }
        Glyph.enterMenuBox(ctx, bounds: Tomato.bounds, scale: scale)
        Tomato.drawBase(ctx, gap: Glyph.menuGap)
    }

    static func drawGlyphTop(in ctx: CGContext, scale: CGFloat, dial: Double) {
        ctx.saveGState()
        defer { ctx.restoreGState() }
        Glyph.enterMenuBox(ctx, bounds: Tomato.bounds, scale: scale)
        Tomato.drawTop(ctx, line: Glyph.menuLine, gap: Glyph.menuGap, dial: dial)
    }
}

// MARK: - 2. The main view

/// The panel under the icon: the ruler, the quick lengths, the buttons and the time. Its width is 276 pt inside the
/// panel's padding, the height follows the content.
struct MainView: View {
    @ObservedObject private var model = TimerController.shared
    @State private var anchor = ViewAnchor()

    var body: some View {
        let timer = model.timer
        VStack(alignment: .leading, spacing: 10) {
            Ruler(minutes: timer.minutes, isActive: timer.isIdle) { model.setMinutes($0) }
                .frame(height: 48)
            HStack(spacing: 6) {
                ForEach(Presets.quick, id: \.self) { minutes in
                    PresetCapsule(title: L("%@ мин", String(minutes)), isSelected: timer.minutes == minutes) {
                        model.setMinutes(minutes)
                    }
                }
                // «…» opens the user's own lengths; it is lit while a length that is not one of the quick ones is set.
                PresetCapsule(title: "…", help: L("Свои значения"), isSelected: !Presets.quick.contains(timer.minutes),
                              anchor: anchor) {
                    anchor.popUp(ownLengthsMenu())
                }
            }
            .disabled(!timer.isIdle)
            HStack(alignment: .bottom, spacing: 6) {
                buttons(for: timer)
                Spacer(minLength: 0)
                Text(TimerDisplay.clock(model.seconds))
                    .font(.system(size: 32, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(timer.isPaused ? Palette.secondary : Color.white)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func buttons(for timer: PomodoroTimer) -> some View {
        HStack(spacing: 6) {
            switch timer.phase {
            case .idle:
                Button(L("Старт")) { model.start() }.appButton(.primary)
            case .running:
                Button(L("Пауза")) { model.pause() }.appButton(.primary)
                Button(L("Стоп")) { model.stop() }.appButton(.secondary)
            case .paused:
                Button(L("Продолжить")) { model.resume() }.appButton(.primary)
                Button(L("Стоп")) { model.stop() }.appButton(.secondary)
            }
        }
        .controlSize(.small)
        .fixedSize()
        .padding(.bottom, 4)
    }

    /// The menu of «…»: the lengths the user wrote in Settings, and the way to write them.
    private func ownLengthsMenu() -> NSMenu {
        let menu = NSMenu()
        let own = TimerSettings().customPresets
        if own.isEmpty {
            let hint = NSMenuItem(title: L("Своих пресетов пока нет"), action: nil, keyEquivalent: "")
            hint.isEnabled = false
            menu.addItem(hint)
        }
        for minutes in own {
            menu.addItem(ClosureMenuItem(L("%@ мин", String(minutes)), checked: minutes == model.timer.minutes) {
                model.setMinutes(minutes)
            })
        }
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem(L("Задать в настройках…")) { SettingsWindow.show() })
        return menu
    }
}

/// A length to pick: a translucent capsule as wide as its share of the row, lit when it is the length now.
private struct PresetCapsule: View {
    let title: String
    /// What the capsule is, when its title does not say: the tooltip and the name for VoiceOver.
    var help = ""
    var isSelected = false
    /// Set for the capsule that opens a menu: the menu opens under it.
    var anchor: ViewAnchor?
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: 26)
                .background(Capsule().fill(isSelected ? Color.white.opacity(0.3) : (hovering && isEnabled ? Color.white.opacity(0.18) : Palette.control)))
                .contentShape(Capsule())
                .background(anchor.map { AnchorView(anchor: $0) })
        }
        .buttonStyle(PressStyle())
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .opacity(isEnabled ? 1 : 0.4)
        .help(help)
        .accessibilityLabel(help.isEmpty ? title : help)
    }
}

// MARK: - 3. The app's section in Settings

/// «Таймер» under «Основные» and «Обновления»: the user's own lengths, what the menu bar shows and the seconds in it, the
/// sound and the notification at the end.
struct AppSettingsSection: View {
    @AppStorage(TimerSettings.showSecondsKey) private var showSeconds = true
    @AppStorage(TimerSettings.endSoundKey) private var endSound = true
    @AppStorage(TimerSettings.endNotificationKey) private var endNotification = true
    /// The user said no to the notifications of Tomato, in the system's question or later in System Settings.
    @State private var notificationsDenied = false

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.gap) {
            SectionTitle(L("Таймер"))
            VStack(spacing: 0) {
                PresetsRow()
                Separator()
                MenuBarStyleRow()
                Separator()
                SwitchRow(title: L("Показывать секунды"),
                          help: L("В строке меню время идёт с секундами: 24:13. Без секунд остаются минуты: 25 мин"),
                          isOn: $showSeconds)
                Separator()
                SwitchRow(title: L("Звук в конце, на обычной громкости"),
                          help: L("Когда время вышло, Tomato звонит три раза, как будильник. Звук идёт на обычной громкости Mac, переключатель «Звуковые эффекты» на него не влияет"),
                          isOn: $endSound)
                Separator()
                SwitchRow(title: L("Уведомление в конце"),
                          help: L("Когда время вышло, macOS показывает уведомление от Tomato. Разрешение на него спрашивается при первом старте"),
                          isOn: $endNotification)
                    .task { notificationsDenied = await SystemNotifier.shared.isDenied() }
                    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                        Task { notificationsDenied = await SystemNotifier.shared.isDenied() }
                    }
                if notificationsDenied {
                    // Only System Settings can change that.
                    Separator()
                    NoteRow(text: L("Выключено в Системных настройках"),
                            help: L("Уведомления Tomato выключены в Системных настройках, в разделе «Уведомления». Звук и мигание значка остаются")) {
                        Button(L("Открыть «Уведомления»")) { SystemNotifier.shared.openSystemSettings() }
                            .appButton(.secondary)
                            .controlSize(.small)
                            .fixedSize()
                    }
                }
            }
            .card()
        }
    }
}

/// «Вид в строке меню»: what stands in the menu bar while a timer runs, the tomato, the time or both. A menu as in the
/// language row. Whatever is chosen, the tomato stands there at rest.
private struct MenuBarStyleRow: View {
    @AppStorage(TimerSettings.menuBarStyleKey) private var stored = ""

    var body: some View {
        let style = MenuBarStyle.resolved(stored: stored.isEmpty ? nil : stored,
                                          legacyShowTime: UserDefaults.standard.object(forKey: TimerSettings.showTimeKey) as? Bool)
        Row(title: L("Вид в строке меню"),
            help: L("Что стоит в строке меню, пока идёт таймер: только помидор, только время или помидор вместе со временем. Когда таймер не запущен, в строке меню помидор")) {
            MenuCapsule(title: style.title, help: L("Вид в строке меню"), makeMenu: { menu(current: style) })
        }
    }

    private func menu(current: MenuBarStyle) -> NSMenu {
        let menu = NSMenu()
        for option in MenuBarStyle.allCases {
            menu.addItem(ClosureMenuItem(option.title, checked: option == current) { stored = option.rawValue })
        }
        return menu
    }
}

extension MenuBarStyle {
    var title: String {
        switch self {
        case .tomatoOnly: return L("Только помидор")
        case .timerOnly: return L("Только таймер")
        case .both: return L("Помидор и таймер")
        }
    }
}

/// The user's own lengths as a line of minutes: «15, 45».
private struct PresetsRow: View {
    @AppStorage(TimerSettings.presetsKey) private var stored = ""
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        Row(title: L("Свои пресеты"),
            help: L("Минуты через запятую, от 1 до 60. Они появятся в меню «…» под линейкой")) {
            TextField("", text: $draft, prompt: Text("15, 45").foregroundStyle(Palette.secondary))
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .multilineTextAlignment(.center)
                .focused($focused)
                .accessibilityLabel(L("Свои пресеты"))
                .onSubmit(commit)
                .padding(.horizontal, 10)
                .frame(width: 130, height: 24)
                .background(Capsule().fill(focused ? Color.white.opacity(0.18) : Palette.control))
        }
        .onAppear { draft = Presets.normalized(stored) }
        // The menu of «…» always has what was typed, even when the window is closed in the middle of typing; the field
        // itself is tidied («45,15» becomes «15, 45») when the user leaves it.
        .onChange(of: draft) { _, text in stored = Presets.normalized(text) }
        .onChange(of: focused) { _, isFocused in
            if !isFocused { draft = stored }
        }
    }

    private func commit() {
        draft = Presets.normalized(draft)
    }
}

// MARK: - 4. The actions of the menu and 5. being busy

@MainActor
enum AppActions {
    /// Start, pause and stop in the menu of the icon, above «Настройки…».
    static func menuItems() -> [NSMenuItem] {
        let model = TimerController.shared
        switch model.timer.phase {
        case .idle:
            return [ClosureMenuItem(L("Старт на %@ мин", String(model.timer.minutes))) { model.start() }]
        case .running:
            return [ClosureMenuItem(L("Пауза")) { model.pause() }, ClosureMenuItem(L("Стоп")) { model.stop() }]
        case .paused:
            return [ClosureMenuItem(L("Продолжить")) { model.resume() }, ClosureMenuItem(L("Стоп")) { model.stop() }]
        }
    }

    /// A timer is running. An update that installs itself waits until it ends, and so does «Перезапустить» for a new
    /// interface language. Even a restart would not lose the timer, which is saved with its end, but it would interrupt
    /// the work.
    static var isBusy: Bool {
        TimerController.shared.isBusy
    }
}
