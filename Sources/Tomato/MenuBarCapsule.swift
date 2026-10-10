import AppKit
import TomatoCore

extension MenuBarIcon {
    /// The running timer in the menu bar, besides the tomato itself.
    struct TimerFace: Equatable {
        /// Where the tomato's lower half is turned, as a part of its full turn (`TimerDisplay.dial`): it grows with the time
        /// the timer has run, 0 at the start, while the time left is in the capsule.
        var dial: Double
        /// The time left. It is drawn unless Settings ask for the tomato alone (`style`), and VoiceOver reads it either way.
        var time: TimeCapsule
        /// What the menu bar shows while the timer runs: the tomato, the time, or both (Settings).
        var style: MenuBarStyle = .default

        /// How far the lower half is turned, in degrees.
        var angle: Double { dial * 360 }

        /// The capsule that is drawn: nil when Settings ask for the tomato alone.
        var capsule: TimeCapsule? { style.showsTimer ? time : nil }

        /// The tomato is drawn: not when Settings ask for the time alone.
        var showsTomato: Bool { style.showsTomato(timerRunning: true) }
    }

    /// The time in a capsule.
    struct TimeCapsule: Equatable {
        /// What the capsule says: «24:13» or «25 мин».
        var text: String
        /// The widest text of the same format. It sets the width, so the capsule keeps its size as the digits change.
        var sample: String
        /// An outline with the time inside, instead of a plate with the time cut out: a paused timer, and the flash at
        /// the end.
        var outlined = false
    }

    /// The digits: monospaced, semibold, as big as the menu bar's own text (13 pt), so they are as tall as the digits of
    /// the system clock. On the baseline of the system's menu bar text (below) their cap height sits in the middle of the
    /// 16 pt capsule, so the time reads where the clock's own text reads.
    static let capsuleFont = NSFont.monospacedDigitSystemFont(ofSize: NSFont.menuBarFont(ofSize: 0).pointSize, weight: .semibold)

    /// How high above the bottom of the canvas the baseline of the system's menu bar text lies: the line of the menu bar
    /// font (ascent and descent, each rounded up as AppKit lays text out) centred in the canvas. The button centres the image
    /// in the menu bar, so this is also where the system's own text stands.
    static func systemBaseline(height: CGFloat = canvas.height) -> CGFloat {
        let system = NSFont.menuBarFont(ofSize: 0)
        let descent = ceil(-system.descender)
        return (height - (ceil(system.ascender) + descent)) / 2 + descent
    }

    private static func typographicWidth(_ line: CTLine) -> CGFloat {
        CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    }

    private static func line(_ text: String) -> CTLine {
        CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: capsuleFont]))
    }

    /// Where the capsule stands beside the tomato and how big the whole image is then: the tomato's canvas, a gap of about
    /// 4 pt of clear space (`gapToTomato`), the capsule, as wide as the widest time of its format needs plus its padding on
    /// each side, in whole points, and the canvas's margin at the end.
    static func capsuleLayout(_ capsule: TimeCapsule?) -> (rect: CGRect, size: NSSize)? {
        guard let capsule else { return nil }
        let rect = Tomato.capsule(textWidth: typographicWidth(line(capsule.sample)).rounded(.up), after: canvas)
        return (rect, NSSize(width: rect.maxX + Glyph.menuMargin, height: canvas.height))
    }

    /// How the image is put together: its size, whether the tomato stands in it (on its canvas, at the left end) and
    /// where the capsule with the time stands (nil: no capsule).
    struct Composition: Equatable {
        var size: NSSize
        var showsTomato: Bool
        var capsule: CGRect?
    }

    /// The image for a timer face. Without a face, or when Settings ask for the tomato alone, it is the tomato on its
    /// canvas. With the time beside it, the image is wider by the capsule (`layout`, from `capsuleLayout`); with the time
    /// alone, the capsule takes the tomato's place, margin and all. The capsule is there or gone at once, so the image
    /// changes its width in one step when a timer starts and in one step when it stops, and macOS lays out the menu bar
    /// once each time.
    static func composition(face: TimerFace?, layout: (rect: CGRect, size: NSSize)?) -> Composition {
        guard let face, face.capsule != nil, let layout else {
            return Composition(size: canvas, showsTomato: true, capsule: nil)
        }
        if face.showsTomato { return Composition(size: layout.size, showsTomato: true, capsule: layout.rect) }
        let home = layout.rect.offsetBy(dx: Glyph.menuMargin - layout.rect.minX, dy: 0)
        return Composition(size: NSSize(width: home.width + 2 * Glyph.menuMargin, height: canvas.height), showsTomato: false,
                           capsule: home)
    }

    /// The capsule as the approved sheet draws it: a plate with round ends and the time cut out of it, so macOS tints it for
    /// the menu bar like the glyph; or, for a timer that waits and for the flash, an outline with the time inside. The
    /// context counts in points with y down, as in a flipped image.
    static func drawCapsule(_ capsule: TimeCapsule, rect: CGRect, in ctx: CGContext) {
        let text = line(capsule.text)
        func capsuleShape(_ rect: CGRect) -> CGPath {
            let radius = min(rect.width, rect.height) / 2
            return CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        }
        ctx.saveGState()
        if capsule.outlined {
            ctx.setLineWidth(lineWidth)
            ctx.addPath(capsuleShape(rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)))
            ctx.strokePath()
        } else {
            ctx.addPath(capsuleShape(rect))
            ctx.fillPath()
            // The digits are cut out of the plate.
            ctx.setBlendMode(.clear)
        }
        // The baseline is the system's; the context is flipped, so the text is flipped back.
        ctx.textMatrix = .identity
        ctx.translateBy(x: rect.minX + (rect.width - typographicWidth(text)) / 2, y: canvas.height - systemBaseline())
        ctx.scaleBy(x: 1, y: -1)
        ctx.textPosition = .zero
        CTLineDraw(text, ctx)
        ctx.restoreGState()
    }
}
