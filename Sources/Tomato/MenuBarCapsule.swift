import AppKit
import TomatoCore

extension MenuBarIcon {
    /// The running timer in the menu bar, besides the tomato itself.
    struct TimerFace: Equatable {
        /// Where the tomato's upper half is turned, as a part of its full turn (`TimerDisplay.dial`): it grows with the time
        /// the timer has run, 0 at the start, while the time left is in the capsule.
        var dial: Double
        /// The time left. It is drawn unless Settings ask for the tomato alone (`style`), and VoiceOver reads it either way.
        var time: TimeCapsule
        /// What the menu bar shows while the timer runs: the tomato, the time, or both (Settings).
        var style: MenuBarStyle = .default

        /// How far the upper half is turned, in degrees.
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

    /// A picture in the image: where it stands and how opaque it is.
    struct Placed: Equatable {
        var rect: CGRect
        var alpha: CGFloat
    }

    /// How the image is put together: its size, and the tomato and the capsule in it (nil: not drawn).
    struct Composition: Equatable {
        var size: NSSize
        var tomato: Placed?
        var capsule: Placed?
    }

    /// The image for a timer face, `presence` of the way from the tomato at rest (0) to the face as it runs (1): the capsule
    /// takes its place as `presence` grows, its width and its opacity with it, so the item widens and the capsule shows up. The
    /// tomato stays, or, when Settings ask for the time alone, gives way to the capsule. Without a face, or when the time is
    /// not shown, it is the tomato alone. `layout` is where the capsule stands beside the tomato (`capsuleLayout`).
    static func composition(face: TimerFace?, presence: CGFloat, layout: (rect: CGRect, size: NSSize)?) -> Composition {
        let tomato = Placed(rect: CGRect(origin: .zero, size: canvas), alpha: 1)
        guard let face, face.capsule != nil, let layout else {
            return Composition(size: canvas, tomato: tomato, capsule: nil)
        }
        let p = min(max(presence, 0), 1)
        func size(grownTo width: CGFloat) -> NSSize { NSSize(width: canvas.width + p * (width - canvas.width), height: canvas.height) }
        if face.showsTomato {
            return Composition(size: size(grownTo: layout.size.width), tomato: tomato,
                               capsule: p > 0 ? Placed(rect: layout.rect, alpha: p) : nil)
        }
        // The time alone: the capsule takes the tomato's place, margin and all.
        let alone = layout.rect.offsetBy(dx: Glyph.menuMargin - layout.rect.minX, dy: 0)
        return Composition(size: size(grownTo: alone.width + 2 * Glyph.menuMargin),
                           tomato: p < 1 ? Placed(rect: tomato.rect, alpha: 1 - p) : nil,
                           capsule: p > 0 ? Placed(rect: alone, alpha: p) : nil)
    }

    /// The capsule as the approved sheet draws it: a plate with round ends and the time cut out of it, so macOS tints it for
    /// the menu bar like the glyph; or, for a timer that waits and for the flash, an outline with the time inside. The
    /// context counts in points with y down, as in a flipped image.
    static func drawCapsule(_ capsule: TimeCapsule, rect: CGRect, in ctx: CGContext) {
        let text = line(capsule.text)
        let radius = rect.height / 2
        ctx.saveGState()
        if capsule.outlined {
            let inner = rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
            ctx.setLineWidth(lineWidth)
            ctx.addPath(CGPath(roundedRect: inner, cornerWidth: inner.height / 2, cornerHeight: inner.height / 2, transform: nil))
            ctx.strokePath()
        } else {
            ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
            ctx.fillPath()
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
