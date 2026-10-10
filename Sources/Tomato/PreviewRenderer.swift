import AppKit
import SwiftUI
import TomatoCore

/// `--render-previews <folder>`: the menu bar icon at rest and while the timer runs (the marks of the tomato's dial moved
/// on a little, the time in a capsule beside it), the panel under it in the states of the timer and Settings, all drawn
/// into one picture, <folder>/preview.png, through hosting views in windows that are never shown. A second picture,
/// <folder>/icon.png, shows the tomato itself: the app icon, the menu bar icon at its real size, the marks frame by frame
/// and the styles of the menu bar (`iconSheet`). Nothing starts: no status item, no updater, no login item, no notification.
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
            ("идёт", big(false, running)), ("пауза", big(false, face(14 * 60 + 20, "14:20", outlined: true))),
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
        // The icons three times larger, at rest with and without the dot of an update, and while a timer runs.
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
        iconSheet(into: folder.appendingPathComponent("icon.png"))
    }

    /// <folder>/icon.png: the tomato for review, every picture at the pixels it is shown in. The app icon at 256 px, as
    /// scripts/make_icon.swift draws it; the menu bar icon pixel for pixel at 2x and 1x, on a dark and a light menu bar
    /// beside the system's Wi-Fi symbol; the marks at eight moments over one period of the dial, after which the picture is
    /// the same again; and the menu bar while a timer runs, in the three styles and paused.
    static func iconSheet(into url: URL) {
        let margin = 32, gap = 28, iconSide = 256
        let bars: [(bar: CGFloat, ink: CGFloat)] = [(0.12, 1), (0.93, 0)]
        let canvas = MenuBarIcon.canvas
        let wifi: [CGFloat: CGImage] = [1: wifiSymbol(scale: 1), 2: wifiSymbol(scale: 2)].compactMapValues { $0 }
        // A strip of menu bar, in points: the tomato's canvas, the space between two items, the Wi-Fi symbol.
        let wifiWidth = wifi[1].map { $0.width } ?? 0
        let stripPoints = 10 + Int(canvas.width) + 14 + wifiWidth + 10
        // The frames: a period of the dial in eight steps, each drawn six pixels to the point.
        let frameZoom: CGFloat = 6, steps = 8
        let frameW = Int(canvas.width * frameZoom) + 24, frameH = Int(canvas.height * frameZoom) + 12
        // The styles: a timer at 24:13 (and one paused at 14:20), three pixels to the point, and pixel for pixel at 2x.
        let running = face(24 * 60 + 13, "24:13")
        var tomatoOnly = running, timerOnly = running
        tomatoOnly.style = .tomatoOnly
        timerOnly.style = .timerOnly
        let styles: [(title: String, face: MenuBarIcon.TimerFace)] = [
            ("Помидор и таймер", running), ("Только помидор", tomatoOnly), ("Только таймер", timerOnly),
            ("Пауза", face(14 * 60 + 20, "14:20", outlined: true))]
        let styleZoom: CGFloat = 3
        let styleWidths = styles.map { style in
            max(Int(MenuBarIcon.image(face: style.face, scales: [1]).size.width * styleZoom) + 24,
                SheetCanvas.width(of: style.title, size: 12, weight: .medium) + 12)
        }
        let styleH = Int(canvas.height * styleZoom) + 12

        let framesWidth = steps * frameW + (steps - 1) * 10
        let stylesWidth = styleWidths.reduce(0, +) + (styles.count - 1) * 18
        let width = 2 * margin + max(framesWidth, stylesWidth, iconSide + gap + stripPoints * 2)
        let rowTitle = 26
        let firstRow = 70 + iconSide
        let secondRow = rowTitle + frameH + 24
        let thirdRow = rowTitle + 18 + styleH + 10 + 2 * (24 * 2 + 6)
        let height = margin + firstRow + gap + secondRow + gap + thirdRow + margin
        guard let sheet = SheetCanvas(width: width, height: height) else { return }
        sheet.rect(x: 0, top: 0, w: width, h: height, gray: 0.17)
        sheet.text("Tomato: помидор с засечками на нижней половине", x: margin, top: margin, size: 22, weight: .semibold, alpha: 0.9)
        sheet.text("Иконка 256 px · значок строки меню в настоящем размере рядом с системным Wi-Fi · засечки идут по линии: оборот в минуту, 6° в секунду, 15 кадров в секунду",
                   x: margin, top: margin + 34, size: 13, alpha: 0.55)

        // The app icon, and the menu bar pixel for pixel: 2x, then 1x, each on a dark and a light bar.
        var top = margin + 70
        if let icon = appIcon(side: iconSide) { sheet.image(icon, x: margin, top: top, w: iconSide, h: iconSide, smooth: true) }
        let stripX = margin + iconSide + gap
        let stripsHeight = 2 * (48 + 8) + 2 * (24 + 8) + 16
        var y = top + (iconSide - stripsHeight) / 2
        for scale in [CGFloat(2), 1] {
            let s = Int(scale)
            for look in bars {
                sheet.rect(x: stripX, top: y, w: stripPoints * s, h: 24 * s, gray: look.bar)
                if let tomato = picture(nil, scale: scale) {
                    sheet.image(tinted(tomato, look.ink), x: stripX + 10 * s, top: y + s)
                }
                if let symbol = wifi[scale] {
                    sheet.image(tinted(symbol, look.ink), x: stripX + (10 + Int(canvas.width) + 14) * s, top: y + s)
                }
                y += 24 * s + 8
            }
        }
        sheet.text("строка меню 2x и 1x, пиксель в пиксель", x: stripX, top: y + 4, size: 11, alpha: 0.45)
        let legend = [
            "Помидор как кухонный таймер, разрезанный поперёк линией.",
            "На верхней половине изогнутый хвостик, венчик из пяти листьев",
            "и указатель над линией, остриём вниз. Они стоят на месте.",
            "С линии в нижнюю половину свисают двенадцать засечек.",
            "Пока идёт таймер, они скользят по линии: оборот в минуту.",
            "Капсула с временем появляется и исчезает сразу."]
        let legendX = stripX + stripPoints * 2 + 48
        for (index, line) in legend.enumerated() {
            sheet.text(line, x: legendX, top: top + (iconSide - legend.count * 22) / 2 + index * 22, size: 13, alpha: 0.7)
        }

        // The marks over one period of the dial.
        top += iconSide + gap
        let period = Double(TimerDisplay.turnSeconds) / Double(Tomato.marks)
        sheet.text("Восемь кадров за период: засечки повторяются через \(ru(360 / Double(Tomato.marks)))°, за \(ru(period)) с",
                   x: margin, top: top, size: 12, alpha: 0.55)
        for k in 0..<steps {
            let seconds = period * Double(k) / Double(steps)
            var turning = running
            turning.style = .tomatoOnly
            turning.dial = TimerDisplay.dial(elapsed: seconds, reducesMotion: false)
            let x = margin + k * (frameW + 10), frameTop = top + rowTitle
            sheet.rect(x: x, top: frameTop, w: frameW, h: frameH, gray: 0.08, radius: 8)
            if let frame = picture(turning, scale: frameZoom) {
                sheet.image(tinted(frame, 1), x: x + (frameW - frame.width) / 2, top: frameTop + 6)
            }
            sheet.text("\(ru(seconds * TimerDisplay.degreesPerSecond))° · \(ru(seconds)) с", x: x + 4, top: frameTop + frameH + 4,
                       size: 11, alpha: 0.5)
        }

        // The menu bar while a timer runs: enlarged, then pixel for pixel at 2x on a dark and a light bar.
        top += secondRow + gap
        sheet.text("Строка меню, пока идёт таймер: три вида из настроек и пауза. Таймер появляется сразу, без анимации",
                   x: margin, top: top, size: 12, alpha: 0.55)
        var x = margin
        for (index, style) in styles.enumerated() {
            let itemTop = top + rowTitle
            sheet.text(style.title, x: x, top: itemTop, size: 12, weight: .medium, alpha: 0.8)
            let boxTop = itemTop + 18
            sheet.rect(x: x, top: boxTop, w: styleWidths[index], h: styleH, gray: 0.08, radius: 8)
            if let big = picture(style.face, scale: styleZoom) {
                sheet.image(tinted(big, 1), x: x + (styleWidths[index] - big.width) / 2, top: boxTop + 6)
            }
            var stripTop = boxTop + styleH + 10
            for look in bars {
                if let real = picture(style.face, scale: 2) {
                    sheet.rect(x: x, top: stripTop, w: styleWidths[index], h: 48, gray: look.bar)
                    sheet.image(tinted(real, look.ink), x: x + (styleWidths[index] - real.width) / 2, top: stripTop + 2)
                }
                stripTop += 48 + 6
            }
            x += styleWidths[index] + 18
        }

        guard let image = sheet.image(), let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]),
              (try? data.write(to: url)) != nil else {
            print("failed to write \(url.path)")
            return
        }
        print("wrote \(url.path)")
    }

    /// A drawing in pixels, y down from the top left corner, for `iconSheet`.
    private struct SheetCanvas {
        let ctx: CGContext
        let height: Int

        init?(width: Int, height: Int) {
            guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            self.ctx = ctx
            self.height = height
        }

        func image() -> CGImage? { ctx.makeImage() }

        /// `picture` with its top left corner at (`x`, `top`), as big as it is or `w` by `h`; enlarged pixel for pixel
        /// unless `smooth`.
        func image(_ picture: CGImage, x: Int, top: Int, w: Int? = nil, h: Int? = nil, smooth: Bool = false) {
            let w = w ?? picture.width, h = h ?? picture.height
            ctx.interpolationQuality = smooth ? .high : .none
            ctx.draw(picture, in: CGRect(x: x, y: height - top - h, width: w, height: h))
        }

        func rect(x: Int, top: Int, w: Int, h: Int, gray: CGFloat, radius: CGFloat = 0) {
            ctx.setFillColor(CGColor(gray: gray, alpha: 1))
            ctx.addPath(CGPath(roundedRect: CGRect(x: x, y: height - top - h, width: w, height: h), cornerWidth: radius,
                               cornerHeight: radius, transform: nil))
            ctx.fillPath()
        }

        /// How wide `string` is in whole pixels.
        static func width(of string: String, size: CGFloat, weight: NSFont.Weight = .regular) -> Int {
            Int(ceil(NSAttributedString(string: string, attributes: [.font: NSFont.systemFont(ofSize: size, weight: weight)]).size().width))
        }

        func text(_ string: String, x: Int, top: Int, size: CGFloat, weight: NSFont.Weight = .regular, alpha: CGFloat) {
            let text = NSAttributedString(string: string, attributes: [.font: NSFont.systemFont(ofSize: size, weight: weight),
                                                                       .foregroundColor: NSColor(white: 1, alpha: alpha)])
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
            let line = ceil(text.size().height)
            text.draw(at: NSPoint(x: CGFloat(x), y: CGFloat(height - top) - line))
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    /// The menu bar icon for `face` at `scale` pixels to the point: the template picture the menu bar is given.
    private static func picture(_ face: MenuBarIcon.TimerFace?, scale: CGFloat) -> CGImage? {
        (MenuBarIcon.image(face: face, scales: [scale]).representations.first as? NSBitmapImageRep)?.cgImage
    }

    /// The app icon as make_icon.swift draws Resources/AppIcon-1024.png: the black tile, a squircle 100 px in from each edge
    /// of 1024, and the white mark on it, `side` pixels square.
    private static func appIcon(side: Int) -> CGImage? {
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        func layer() -> CGContext? {
            let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            ctx?.scaleBy(x: CGFloat(side) / 1024, y: CGFloat(side) / 1024)
            return ctx
        }
        // The mark goes into a layer of its own: its gaps are cut out.
        guard let mark = layer(), let tile = layer() else { return nil }
        mark.setFillColor(.white)
        mark.setStrokeColor(.white)
        Glyph.enterIconBody(mark, bounds: Tomato.bounds)
        Tomato.draw(mark, line: Glyph.iconLine, gap: Glyph.iconGap)
        let body = CGMutablePath()
        for i in 0...720 {
            let t = CGFloat(i) / 720 * 2 * .pi, c = cos(t), s = sin(t)
            let point = CGPoint(x: 512 + 412 * (c < 0 ? -1 : 1) * pow(abs(c), 0.4), y: 512 + 412 * (s < 0 ? -1 : 1) * pow(abs(s), 0.4))
            if i == 0 { body.move(to: point) } else { body.addLine(to: point) }
        }
        body.closeSubpath()
        tile.addPath(body)
        tile.setFillColor(.black)
        tile.fillPath()
        guard let markImage = mark.makeImage() else { return nil }
        tile.draw(markImage, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
        return tile.makeImage()
    }

    /// The system's Wi-Fi symbol as a status item shows it (15 pt, regular), on a canvas 22 pt tall with a point of margin
    /// each side, `scale` pixels to the point.
    private static func wifiSymbol(scale: CGFloat) -> CGImage? {
        guard let symbol = NSImage(systemSymbolName: "wifi", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)) else { return nil }
        let size = CGSize(width: ceil(symbol.size.width) + 2, height: 22)
        guard let ctx = CGContext(data: nil, width: Int(size.width * scale), height: Int(size.height * scale), bitsPerComponent: 8,
                                  bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.scaleBy(x: scale, y: scale)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        symbol.draw(in: NSRect(x: 1, y: (size.height - symbol.size.height) / 2, width: symbol.size.width, height: symbol.size.height),
                    from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        return ctx.makeImage()
    }

    /// A template picture in one grey, keeping its alpha: white on a dark menu bar, black on a light one.
    private static func tinted(_ picture: CGImage, _ gray: CGFloat) -> CGImage {
        let rect = CGRect(x: 0, y: 0, width: picture.width, height: picture.height)
        guard let ctx = CGContext(data: nil, width: picture.width, height: picture.height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return picture }
        ctx.clip(to: rect, mask: picture)
        ctx.setFillColor(CGColor(gray: gray, alpha: 1))
        ctx.fill(rect)
        return ctx.makeImage() ?? picture
    }

    /// A number as Russian writes it: whole, or with as many decimals after a comma as it needs, up to three.
    private static func ru(_ value: Double) -> String {
        var text = String(format: "%.3f", value)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text.replacingOccurrences(of: ".", with: ",")
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
