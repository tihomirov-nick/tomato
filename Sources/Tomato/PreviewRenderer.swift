import AppKit
import SwiftUI
import TomatoCore

/// `--render-previews <folder>`: the menu bar icon at rest and while the timer runs (the tomato's upper half turned a
/// little, the time in a capsule beside it), the panel under it in the states of the timer and Settings, all drawn into one
/// picture, <folder>/preview.png, through hosting views in windows that are never shown. A second picture,
/// <folder>/rotation.png, shows the turn frame by frame and the styles of the menu bar, a third, <folder>/motion.png, the
/// capsule coming in and going out. Nothing starts: no status item, no updater, no login item, no notification.
@MainActor
enum PreviewRenderer {
    private struct State {
        var name: String
        var phase: PomodoroTimer.Phase
        var minutes = 25
        /// The timer in the menu bar above the panel; nil is the tomato at rest.
        var icon: MenuBarIcon.TimerFace?
    }

    static func run(into folder: URL) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let saved = TimerController.shared
        defer { TimerController.shared = saved }
        // The panel with the timer idle, running and paused, and idle with a length of the user's own; the icon above
        // each in its state.
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let states = [
            State(name: "покой", phase: .idle),
            State(name: "идёт", phase: .running(endsAt: now.addingTimeInterval(24 * 60 + 13)),
                  icon: face(24 * 60 + 13, "24:13")),
            State(name: "пауза", phase: .paused(remaining: 14 * 60 + 20), icon: face(14 * 60 + 20, "14:20", outlined: true)),
            State(name: "своя длительность", phase: .idle, minutes: 37)]
        var panels: [(image: CGImage, size: NSSize)] = []
        for state in states {
            TimerController.shared = detachedController(state, now: now)
            guard let panel = snapshot(PanelView()) else {
                print("failed to draw the views")
                return
            }
            panels.append(panel)
        }
        guard let settings = snapshot(SettingsWindow.makeWindow()) else {
            print("failed to draw the views")
            return
        }
        let margin: CGFloat = 24, bar: CGFloat = 24, zoom: CGFloat = 3, column: CGFloat = 300, columns = 3, scale: CGFloat = 2
        let running = face(24 * 60 + 13, "24:13")
        var minutesOnly = face(24 * 60 + 13, "25 мин")
        minutesOnly.time.sample = "00 мин"
        var tomatoOnly = face(10 * 60, "10:00")
        tomatoOnly.style = .tomatoOnly
        // Drawn at the pixels they are shown in, so that the zoom does not blur them.
        func big(_ badge: Bool = false, _ face: MenuBarIcon.TimerFace? = nil) -> NSImage {
            MenuBarIcon.image(badge: badge, face: face, scales: [zoom * scale])
        }
        let zoomed: [(name: String, image: NSImage)] = [
            ("покой", big()), ("с точкой", big(true)),
            ("идёт", big(false, running)), ("с точкой", big(true, running)),
            ("пауза", big(false, face(14 * 60 + 20, "14:20", outlined: true))),
            ("без секунд", big(false, minutesOnly)), ("только помидор", big(false, tomatoOnly))]
        // Three panels in the first row, the icons zoomed under them, the fourth panel in the third row.
        let firstRow = bar + 6 + (panels.prefix(columns).map(\.size.height).max() ?? 0)
        let zoomedRow = MenuBarIcon.canvas.height * zoom + 22
        let lastRow = bar + 6 + (panels.dropFirst(columns).map(\.size.height).max() ?? 0)
        let left = margin + CGFloat(columns) * (column + margin)
        let width = left + settings.size.width + margin
        let height = margin + max(firstRow + margin + zoomedRow + margin + lastRow, settings.size.height) + margin
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return }
        rep.size = NSSize(width: width, height: height)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor(white: 0.17, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()

        // A strip of menu bar with the icon at its real size for each state, and the panel under it.
        let top = height - margin
        for (index, state) in states.enumerated() {
            let rowTop = index < columns ? top : top - firstRow - margin - zoomedRow - margin
            let strip = NSRect(x: margin + CGFloat(index % columns) * (column + margin), y: rowTop - bar, width: column, height: bar)
            NSColor(white: 0.08, alpha: 1).setFill()
            NSBezierPath(roundedRect: strip, xRadius: 6, yRadius: 6).fill()
            let icon = white(MenuBarIcon.image(face: state.icon))
            icon.draw(in: NSRect(x: strip.midX - icon.size.width / 2, y: strip.midY - icon.size.height / 2,
                                 width: icon.size.width, height: icon.size.height))
            let panel = panels[index]
            let panelRect = NSRect(x: strip.midX - panel.size.width / 2, y: strip.minY - 6 - panel.size.height,
                                   width: panel.size.width, height: panel.size.height)
            NSGraphicsContext.current?.cgContext.draw(panel.image, in: panelRect)
            caption(state.name, at: NSPoint(x: strip.minX + 8, y: strip.midY - 6))
        }
        // The icons three times larger, with and without the dot of an update.
        var x = margin
        let zoomTop = top - firstRow - margin
        for item in zoomed {
            let size = NSSize(width: item.image.size.width * zoom, height: item.image.size.height * zoom)
            NSColor(white: 0.08, alpha: 1).setFill()
            NSBezierPath(roundedRect: NSRect(x: x - 6, y: zoomTop - size.height - 6, width: size.width + 12, height: size.height + 12),
                         xRadius: 8, yRadius: 8).fill()
            white(item.image).draw(in: NSRect(x: x, y: zoomTop - size.height, width: size.width, height: size.height))
            caption(item.name, at: NSPoint(x: x - 6, y: zoomTop - size.height - 24))
            x += size.width + 28
        }
        // Settings on the right.
        let settingsRect = NSRect(x: left, y: top - settings.size.height, width: settings.size.width, height: settings.size.height)
        NSGraphicsContext.current?.cgContext.draw(settings.image, in: settingsRect)
        NSGraphicsContext.restoreGraphicsState()

        let url = folder.appendingPathComponent("preview.png")
        if let data = rep.representation(using: .png, properties: [:]), (try? data.write(to: url)) != nil {
            print("wrote \(url.path)")
        } else {
            print("failed to write \(url.path)")
        }
        rotationSheet(into: folder)
        motionSheet(into: folder.appendingPathComponent("motion.png"))
    }

    /// <folder>/rotation.png: the tomato at eight moments, one second apart, with the angle of its upper half, and the three
    /// styles of the menu bar, at rest and while a timer runs. The icons are drawn at the pixels they are shown in, ten or six
    /// to the point.
    private static func rotationSheet(into folder: URL) {
        let big: CGFloat = 10, small: CGFloat = 6, margin: CGFloat = 28, gap: CGFloat = 18, pad: CGFloat = 12, label: CGFloat = 24
        func face(_ text: String, seconds: TimeInterval, style: MenuBarStyle) -> MenuBarIcon.TimerFace {
            .init(dial: TimerDisplay.dial(elapsed: seconds, reducesMotion: false), time: .init(text: text, sample: "00:00"), style: style)
        }
        typealias Item = (title: String, image: NSImage, zoom: CGFloat)
        let frames: [Item] = (0..<8).map { second in
            let image = MenuBarIcon.image(face: face("25:00", seconds: TimeInterval(second), style: .tomatoOnly), scales: [big])
            return ("\(second) с, \(Int(TimerDisplay.degreesPerSecond) * second)°", white(image), big)
        }
        var styles: [Item] = []
        for style in MenuBarStyle.allCases {
            styles.append(("\(style.title), в покое", white(MenuBarIcon.image(scales: [small])), small))
            styles.append(("\(style.title), идёт", white(MenuBarIcon.image(face: face("24:57", seconds: 3, style: style), scales: [small])), small))
        }
        let rows: [(title: String, items: [Item])] = [
            ("Верхушка целиком: один оборот в минуту, 6° в секунду. Кадры через секунду", frames),
            ("Вид в строке меню: только помидор, только таймер, помидор и таймер", styles)]
        func plate(_ item: Item) -> NSSize {
            NSSize(width: max(item.image.size.width * item.zoom + 2 * pad, 156), height: MenuBarIcon.canvas.height * item.zoom + 2 * pad)
        }
        let rowWidths = rows.map { row in row.items.reduce(0) { $0 + plate($1).width } + CGFloat(row.items.count - 1) * gap }
        let rowHeights = rows.map { row in (row.items.map { plate($0).height }.max() ?? 0) + label + 12 }
        let width = (rowWidths.max() ?? 0) + 2 * margin
        let height = margin * 2 + rows.indices.reduce(0) { $0 + rowHeights[$1] + 34 }
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width), pixelsHigh: Int(height), bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0) else { return }
        rep.size = NSSize(width: width, height: height)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor(white: 0.17, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        var top = height - margin
        for (index, row) in rows.enumerated() {
            caption(row.title, at: NSPoint(x: margin, y: top - 16), size: 14)
            top -= 34
            var x = margin
            for item in row.items {
                let size = plate(item)
                let rect = NSRect(x: x, y: top - size.height, width: size.width, height: size.height)
                NSColor(white: 0.08, alpha: 1).setFill()
                NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10).fill()
                let inner = item.image.size.width * item.zoom
                item.image.draw(in: NSRect(x: rect.minX + (size.width - inner) / 2, y: rect.minY + pad, width: inner,
                                           height: MenuBarIcon.canvas.height * item.zoom))
                caption(item.title, at: NSPoint(x: rect.minX, y: rect.minY - 17), size: 11.5)
                x += size.width + gap
            }
            top -= rowHeights[index]
        }
        NSGraphicsContext.restoreGraphicsState()
        let url = folder.appendingPathComponent("rotation.png")
        if let data = rep.representation(using: .png, properties: [:]), (try? data.write(to: url)) != nil {
            print("wrote \(url.path)")
        } else {
            print("failed to write \(url.path)")
        }
    }

    /// The capsule coming in and going out, eight frames from the start of each movement to its end, at two pixels to the
    /// point, as a Retina menu bar shows them: «Помидор и таймер» and «Только таймер», in and out, each on a dark menu bar
    /// (the template white) and on a light one (black). The frames are those the status item draws, on the clock of
    /// `IconPresence`. They stand on one right edge, as the menu bar keeps the item's right edge when its width changes, with
    /// the time of each frame under it. `--render-previews` writes it to <folder>/motion.png.
    static func motionSheet(into url: URL) {
        let scale: CGFloat = 2, steps = 7, margin: CGFloat = 16, gap: CGFloat = 8, pad: CGFloat = 6
        let strip = MenuBarIcon.canvas.height + 2 * pad, title: CGFloat = 22, label: CGFloat = 16
        typealias Frame = (time: TimeInterval, image: NSImage)
        func movement(_ style: MenuBarStyle, comingIn: Bool) -> [Frame] {
            // A timer that starts at 25:00, or one stopped at 12:34; either way the tomato is at rest while the capsule moves.
            let running = MenuBarIcon.TimerFace(dial: comingIn ? 0 : 0.3, time: .init(text: comingIn ? "25:00" : "12:34", sample: "00:00"),
                                                style: style)
            var presence = IconPresence()
            if !comingIn { presence.change(from: nil, to: running, at: -10, reducesMotion: false) }
            presence.change(from: comingIn ? nil : running, to: comingIn ? running : nil, at: 0, reducesMotion: false)
            let current = comingIn ? running : nil
            return (0...steps).map { step in
                let time = presence.end * Double(step) / Double(steps)
                if step == steps { presence.settle(at: time) }
                return (time, MenuBarIcon.image(face: presence.face(current, at: time), presence: presence.value(at: time),
                                                scales: [scale]))
            }
        }
        func milliseconds(_ seconds: TimeInterval) -> Int { Int((seconds * 1000).rounded()) }
        let rows: [(title: String, frames: [Frame])] = [
            ("Помидор и таймер: появление, \(milliseconds(Fade.inDuration)) мс", movement(.both, comingIn: true)),
            ("Помидор и таймер: исчезновение, \(milliseconds(Fade.outDuration)) мс", movement(.both, comingIn: false)),
            ("Только таймер: появление, \(milliseconds(Fade.inDuration)) мс", movement(.timerOnly, comingIn: true)),
            ("Только таймер: исчезновение, \(milliseconds(Fade.outDuration)) мс", movement(.timerOnly, comingIn: false))]
        let looks: [(bar: NSColor, ink: NSColor)] = [(NSColor(white: 0.1, alpha: 1), .white), (NSColor(white: 0.93, alpha: 1), .black)]
        let cell = (rows.flatMap { $0.frames.map(\.image.size.width) }.max() ?? 0) + 2 * pad
        let width = 2 * margin + CGFloat(steps + 1) * cell + CGFloat(steps) * gap
        let rowHeight = title + CGFloat(looks.count) * (strip + 4) + label + 10
        let height = 2 * margin + CGFloat(rows.count) * rowHeight
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return }
        rep.size = NSSize(width: width, height: height)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor(white: 0.17, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        var top = height - margin
        for row in rows {
            caption(row.title, at: NSPoint(x: margin, y: top - 15), size: 12)
            top -= title
            for look in looks {
                for (index, frame) in row.frames.enumerated() {
                    let rect = NSRect(x: margin + CGFloat(index) * (cell + gap), y: top - strip, width: cell, height: strip)
                    look.bar.setFill()
                    NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5).fill()
                    let image = tinted(frame.image, look.ink)
                    image.draw(in: NSRect(x: rect.maxX - pad - image.size.width, y: rect.minY + pad,
                                          width: image.size.width, height: image.size.height))
                }
                top -= strip + 4
            }
            for (index, frame) in row.frames.enumerated() {
                caption("\(milliseconds(frame.time)) мс", at: NSPoint(x: margin + CGFloat(index) * (cell + gap) + 2, y: top - 13))
            }
            top -= label + 10
        }
        NSGraphicsContext.restoreGraphicsState()
        if let data = rep.representation(using: .png, properties: [:]), (try? data.write(to: url)) != nil {
            print("wrote \(url.path)")
        } else {
            print("failed to write \(url.path)")
        }
    }

    /// The face of the menu bar icon for `remaining` seconds left of a 25-minute timer: the dial is turned as far as the
    /// time the timer has run takes it.
    private static func face(_ remaining: TimeInterval, _ text: String, outlined: Bool = false) -> MenuBarIcon.TimerFace {
        .init(dial: TimerDisplay.dial(elapsed: 25 * 60 - remaining, reducesMotion: false),
              time: .init(text: text, sample: "00:00", outlined: outlined))
    }

    /// A timer on a defaults domain of its own and a clock that stands still, so nothing of the user's changes and
    /// nothing ticks.
    private static func detachedController(_ state: State, now: Date) -> TimerController {
        let suite = "TomatoPreview"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PomodoroStore(defaults: defaults)
        store.save(PomodoroTimer(minutes: state.minutes, phase: state.phase))
        return TimerController(store: store, settings: TimerSettings(defaults: defaults), signals: .silent, now: { now },
                               ticking: false)
    }

    private static func caption(_ text: String, at point: NSPoint, size: CGFloat = 10.5) {
        NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: size),
                                                      .foregroundColor: NSColor(white: 1, alpha: 0.55)]).draw(at: point)
    }

    /// The view as drawn by a real hosting view, at its own size.
    private static func snapshot<V: View>(_ view: V) -> (image: CGImage, size: NSSize)? {
        let hosting = NSHostingView(rootView: view)
        let size = hosting.fittingSize
        hosting.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: hosting.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = .clear
        window.isOpaque = false
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return nil }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        return rep.cgImage.map { ($0, size) }
    }

    /// A window with its title bar, never ordered on screen.
    private static func snapshot(_ window: NSWindow) -> (image: CGImage, size: NSSize)? {
        window.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        guard let frame = window.contentView?.superview else { return nil }
        frame.layoutSubtreeIfNeeded()
        guard let rep = frame.bitmapImageRepForCachingDisplay(in: frame.bounds) else { return nil }
        frame.cacheDisplay(in: frame.bounds, to: rep)
        return rep.cgImage.map { ($0, frame.bounds.size) }
    }

    /// A template image in white, as the dark menu bar shows it.
    private static func white(_ image: NSImage) -> NSImage { tinted(image, .white) }

    /// A template image in `color`: white on a dark menu bar, black on a light one.
    private static func tinted(_ image: NSImage, _ color: NSColor) -> NSImage {
        NSImage(size: image.size, flipped: false) { rect in
            image.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
    }
}
