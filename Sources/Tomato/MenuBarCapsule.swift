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

    /// The tomato in the image: where its canvas stands and how opaque it is. While the tomato turns into the capsule its
    /// canvas is smaller than `canvas` and its cuts (the slit, the marks, the gaps round the calyx) narrower, `cuts` of their
    /// width, down to none: a solid ball.
    struct Placed: Equatable {
        var rect: CGRect
        var alpha: CGFloat
        var cuts: CGFloat = 1
    }

    /// The capsule in the image: where it stands once it is in, and how much of it shows while it comes in or goes.
    struct CapsulePlace: Equatable {
        /// The capsule once it is in: beside the tomato, or at the margin when the time stands alone. The digits stand in it.
        var home: CGRect
        /// The plate as it is now: `home`, or, while the capsule grows out of the tomato, a shorter capsule inside it.
        var plate: CGRect
        var alpha: CGFloat
        /// How much the digits show, 0 to 1.
        var digits: CGFloat = 1
        /// Where the capsule begins to show: left of it lie the tomato's ink and the clear space beside it, which hide
        /// the capsule as the tomato goes over it. Nil when all of it shows.
        var shownFrom: CGFloat?

        /// The capsule as it stands at rest, the picture kept for its time (`IconFrames`), whatever `alpha` and `shownFrom` say.
        var isWhole: Bool { plate == home && digits == 1 }
    }

    /// How the image is put together: its size, and the tomato and the capsule in it (nil: not drawn).
    struct Composition: Equatable {
        var size: NSSize
        var tomato: Placed?
        var capsule: CapsulePlace?
    }

    /// While the capsule grows out of the tomato (the time alone), the tomato turns into the plate over this part of the
    /// way, shrinking to `1 - tomatoShrink` of its size: over its first half the cuts close and the tomato becomes a solid
    /// ball, over its second half the ball fades into the plate, which has about its shape there. Into an outline it fades
    /// with its cuts. The digits show over the part from `digitsFrom` to the end.
    static let tomatoShare: CGFloat = 0.5
    static let tomatoShrink: CGFloat = 0.15
    static let digitsFrom: CGFloat = 0.5

    /// The image for a timer face, `presence` of the way from the tomato at rest (0) to the face as it runs (1). With a
    /// capsule the image has its full width whatever `presence` says: the status item changes its width only twice, at once
    /// when the timer starts and at once when the capsule is gone, so macOS lays out the menu bar twice, and everything that
    /// moves moves inside the image. The menu bar keeps the item's right edge and moves the icons on its left, so at 0 the
    /// tomato stands at the right end of the wide image, where it stood on the screen.
    ///  - The tomato and the time: as `presence` grows the tomato goes left to its place, and the capsule, which lay under
    ///    it at its own place, shows from behind it as it goes: only right of the tomato's ink and the clear space beside it
    ///    (`gapToTomato`), so the two never touch, and more and more opaque.
    ///  - The time alone: the capsule grows out of the tomato. At 0 it is a circle as tall as the capsule where the tomato
    ///    stands, and it lengthens to the left into the capsule, getting opaque. Over the first half of the way
    ///    (`tomatoShare`) the tomato shrinks a little, closes its cuts into a solid ball and fades into the plate, over the
    ///    second half (`digitsFrom`) the digits show.
    /// Going out is the same way back. Without a face, or when the time is not shown, it is the tomato alone. `layout` is
    /// where the capsule stands beside the tomato (`capsuleLayout`).
    static func composition(face: TimerFace?, presence: CGFloat, layout: (rect: CGRect, size: NSSize)?) -> Composition {
        let rest = Placed(rect: CGRect(origin: .zero, size: canvas), alpha: 1)
        guard let face, face.capsule != nil, let layout else {
            return Composition(size: canvas, tomato: rest, capsule: nil)
        }
        let p = min(max(presence, 0), 1)
        if face.showsTomato {
            let size = layout.size
            let tomato = rest.rect.offsetBy(dx: (1 - p) * (size.width - canvas.width), dy: 0)
            // The capsule's place begins where the tomato's ink and the clear space beside it end, at rest and on the way.
            let capsule = CapsulePlace(home: layout.rect, plate: layout.rect, alpha: p,
                                       shownFrom: p < 1 ? tomato.minX + layout.rect.minX : nil)
            return Composition(size: size, tomato: Placed(rect: tomato, alpha: 1), capsule: p > 0 ? capsule : nil)
        }
        // The time alone: the capsule takes the tomato's place, margin and all.
        let home = layout.rect.offsetBy(dx: Glyph.menuMargin - layout.rect.minX, dy: 0)
        let size = NSSize(width: home.width + 2 * Glyph.menuMargin, height: canvas.height)
        let place = rest.rect.offsetBy(dx: size.width - canvas.width, dy: 0)
        let turning = min(p / tomatoShare, 1)
        var tomato: Placed?
        if turning < 1 {
            // Smaller about the middle of its ink; solid, then fading. While the ball fades the plate under it comes, so
            // where the ball is the picture stays nearly opaque. An outline is hollow: inside it the tomato keeps its cuts.
            let k = 1 - tomatoShrink * turning
            let centre = CGPoint(x: place.minX + box.midX, y: place.minY + box.midY)
            tomato = Placed(rect: CGRect(x: centre.x - (centre.x - place.minX) * k, y: centre.y - (centre.y - place.minY) * k,
                                         width: place.width * k, height: place.height * k),
                            alpha: min(2 - 2 * turning, 1), cuts: face.time.outlined ? 1 : max(1 - 2 * turning, 0))
        }
        var plate = home
        if p < 1 {
            let circle = CGRect(x: place.minX + box.midX - home.height / 2, y: home.minY, width: home.height, height: home.height)
            let minX = circle.minX * (1 - p) + home.minX * p, maxX = circle.maxX * (1 - p) + home.maxX * p
            plate = CGRect(x: minX, y: home.minY, width: maxX - minX, height: home.height)
        }
        let capsule = CapsulePlace(home: home, plate: plate, alpha: turning, digits: max(p - digitsFrom, 0) / (1 - digitsFrom))
        return Composition(size: size, tomato: tomato, capsule: p > 0 ? capsule : nil)
    }

    /// The capsule as the approved sheet draws it: a plate with round ends and the time cut out of it, so macOS tints it for
    /// the menu bar like the glyph; or, for a timer that waits and for the flash, an outline with the time inside. The
    /// context counts in points with y down, as in a flipped image. While the capsule grows out of the tomato, its plate is
    /// `plate`, shorter than `rect`; the digits keep their place in `rect`, inside the plate, and show as much as `digits`
    /// says (0 to 1).
    static func drawCapsule(_ capsule: TimeCapsule, rect: CGRect, plate: CGRect? = nil, digits: CGFloat = 1, in ctx: CGContext) {
        let text = line(capsule.text)
        let plate = plate ?? rect
        // Round ends; the plate that grows out of the tomato starts as a circle, never narrower.
        func capsuleShape(_ rect: CGRect) -> CGPath {
            let radius = min(rect.width, rect.height) / 2
            return CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        }
        let shape = capsuleShape(plate)
        ctx.saveGState()
        if capsule.outlined {
            ctx.setLineWidth(lineWidth)
            ctx.addPath(capsuleShape(plate.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)))
            ctx.strokePath()
        } else {
            ctx.addPath(shape)
            ctx.fillPath()
            // Cut out of the plate: all the way, or, while they show up, as much as the digits show.
            ctx.setBlendMode(digits < 1 ? .destinationOut : .clear)
        }
        guard digits > 0 else {
            ctx.restoreGState()
            return
        }
        if plate != rect {
            ctx.addPath(shape)
            ctx.clip()
        }
        if digits < 1 { ctx.setAlpha(digits) }
        // The baseline is the system's; the context is flipped, so the text is flipped back.
        ctx.textMatrix = .identity
        ctx.translateBy(x: rect.minX + (rect.width - typographicWidth(text)) / 2, y: canvas.height - systemBaseline())
        ctx.scaleBy(x: 1, y: -1)
        ctx.textPosition = .zero
        CTLineDraw(text, ctx)
        ctx.restoreGState()
    }
}
