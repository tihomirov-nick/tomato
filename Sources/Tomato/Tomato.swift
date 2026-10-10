// Tomato (pomodoro timer), after the user's sample and a real kitchen timer: a solid tomato with a star-shaped calyx of five
// pointed sepals and a curved stem on top, cut across its belly by a thin slit into two halves. The lower half is the
// dial: twelve marks round its belt hang down from the slit. The upper half stands still with the calyx, the stem and one
// pointer cut into its bottom edge, at the front, pointing down at the marks. Turning the dial moves the marks along the
// belt; seen from the side they slide across, bunch up towards the edges, vanish round them and come back on the other side
// (`dial`). The calyx is parted from the fruit by a thin gap (black on the tile, transparent in the menu bar), like the
// slit, the pointer and the marks, so the whole mark is one white solid with transparent cuts. The menu bar shows the same
// mark, still at rest and with the dial turning steadily while a timer runs, and the time in a capsule beside it
// (`capsule`). Only the marks move, so `drawBase` (everything else) and `cutMarks` (the marks) are separate: the menu bar
// draws the base once and cuts the marks anew for every frame.
// `gap`: Glyph.iconGap or Glyph.menuGap. Box conventions: Glyph.swift.
import CoreGraphics
import Foundation

enum Tomato {
    /// The ink of the tomato in the box: the menu bar and the app icon fit it to their room (Glyph.swift).
    static let bounds = CGRect(x: 8, y: 2.8, width: 84, height: 92.2)

    static func body() -> CGPath {
        let p = Glyph.p
        let path = CGMutablePath()
        path.move(to: p(50, 22))
        path.addCurve(to: p(92, 60), control1: p(75, 20), control2: p(92, 38))
        path.addCurve(to: p(50, 95), control1: p(92, 82), control2: p(74, 95))
        path.addCurve(to: p(8, 60), control1: p(26, 95), control2: p(8, 82))
        path.addCurve(to: p(50, 22), control1: p(8, 38), control2: p(25, 20))
        path.closeSubpath()
        return path
    }

    static let center = Glyph.p(50, 30)

    /// A pointed sepal from the calyx's centre: a lens `length` long, `halfWidth` at its widest, bent by `curl`.
    static func sepal(degrees: CGFloat, length: CGFloat, halfWidth hw: CGFloat, curl: CGFloat) -> CGPath {
        let a = degrees * .pi / 180, dx = cos(a), dy = sin(a), nx = -dy, ny = dx
        let tip = Glyph.p(center.x + dx * length, center.y + dy * length)
        let mid = Glyph.p(center.x + dx * length * 0.45, center.y + dy * length * 0.45)
        let path = CGMutablePath()
        path.move(to: center)
        path.addQuadCurve(to: tip, control: Glyph.p(mid.x + nx * (2 * hw + curl), mid.y + ny * (2 * hw + curl)))
        path.addQuadCurve(to: center, control: Glyph.p(mid.x - nx * (2 * hw - curl), mid.y - ny * (2 * hw - curl)))
        path.closeSubpath()
        return path
    }

    static func calyx() -> CGPath {
        [sepal(degrees: 190, length: 27, halfWidth: 5.5, curl: -2), sepal(degrees: 350, length: 27, halfWidth: 5.5, curl: 2),
         sepal(degrees: 142, length: 23, halfWidth: 5, curl: -2), sepal(degrees: 38, length: 23, halfWidth: 5, curl: 2),
         sepal(degrees: 90, length: 18, halfWidth: 4.5, curl: 0)]
            .reduce(Glyph.disc(center, 7)) { $0.union($1) }
    }

    /// Where the slit lies: its middle line, across the belly a little under the widest part of the fruit, so that clear
    /// fruit is left between the calyx and the pointer over the slit, and so that on a Retina menu bar the slit fills a row
    /// of pixels.
    static let slit: CGFloat = 67.5
    /// The marks of the dial: twelve alike round the belt, `markHeight` long under the slit, on a belt of `beltRadius` (a
    /// little inside the fruit's edge).
    static let marks = 12
    static let markHeight: CGFloat = 8.5
    static let beltRadius: CGFloat = 38
    /// The pointer over the slit, the 1.0.0 one turned upside down: `pointerHeight` tall and `pointerWidth` wide.
    static let pointerHeight: CGFloat = 8
    static let pointerWidth: CGFloat = 11
    /// The dial's full turn, in degrees.
    static let turn: Double = 360

    /// The marks in the dial's position: each as a vertical strip hanging from the slit, wider where it faces us, narrower
    /// towards the edge, none on the far side. `dial` is the part of the full turn (0...1) that the lower half is turned
    /// from zero: at 0 a mark stands under the pointer, and so it does at every twelfth of a turn, the marks being twelve
    /// and alike. As the dial grows the marks go to the right. Each begins a unit inside the slit, so it opens into it.
    static func markStrips(dial: Double, gap: CGFloat) -> [CGRect] {
        let bottom = slit + gap / 2
        var strips: [CGRect] = []
        for k in 0..<marks {
            let angle = (Double(k) * turn / Double(marks) + dial * turn) * .pi / 180
            let facing = CGFloat(cos(angle))
            guard facing > 0.08 else { continue }
            let x = 50 + beltRadius * CGFloat(sin(angle)), width = gap * facing
            strips.append(CGRect(x: x - width / 2, y: bottom - 1, width: width, height: markHeight + 1))
        }
        return strips
    }

    /// The pointer on the upper half: a notch cut into its bottom edge, at the front, pointing down at the dial.
    static func pointer(gap: CGFloat) -> CGPath {
        let top = slit - gap / 2, p = Glyph.p
        let path = CGMutablePath()
        path.move(to: p(50, top + 0.5))
        path.addLine(to: p(50 - pointerWidth / 2, top - pointerHeight))
        path.addLine(to: p(50 + pointerWidth / 2, top - pointerHeight))
        path.closeSubpath()
        return path
    }

    /// Everything but the marks: the lower half, and the upper half with its calyx, stem and pointer. It stands still while
    /// the dial turns, so the menu bar draws it once and keeps the picture (`IconFrames`).
    static func drawBase(_ ctx: CGContext, line w: CGFloat, gap: CGFloat) {
        let top = slit - gap / 2, bottom = slit + gap / 2
        let calyx = calyx()
        // The lower half, the dial; its marks are cut into it by `cutMarks`.
        ctx.saveGState()
        ctx.clip(to: CGRect(x: -50, y: bottom, width: 200, height: 200))
        Glyph.fill(ctx, body())
        ctx.restoreGState()
        // The upper half: the fruit above the slit, the calyx and the stem.
        ctx.saveGState()
        ctx.clip(to: CGRect(x: -50, y: -50, width: 200, height: 50 + top))
        Glyph.fill(ctx, body())
        Glyph.cut(ctx) {
            Glyph.stroke(ctx, calyx, 2 * gap)
            Glyph.fill(ctx, calyx)
        }
        Glyph.fill(ctx, calyx)
        let p = Glyph.p
        let stem = CGMutablePath()
        stem.move(to: center)
        stem.addCurve(to: p(59, 7), control1: p(50, 22), control2: p(53, 13))
        Glyph.stroke(ctx, stem, w)
        ctx.restoreGState()
        // The pointer opens into the slit at its tip.
        Glyph.cut(ctx) { Glyph.fill(ctx, pointer(gap: gap)) }
    }

    /// The dial's marks cut into the belt of the lower half, over what `drawBase` has drawn. They begin inside the slit and
    /// lie under it, so nothing over the slit changes as they move. `dial` as above.
    static func cutMarks(_ ctx: CGContext, gap: CGFloat, dial: Double) {
        Glyph.cut(ctx) { for strip in markStrips(dial: dial, gap: gap) { ctx.fill(strip) } }
    }

    /// The whole mark: `drawBase` and the marks in the position of `dial`; 0 is the mark at rest, and the app icon's.
    static func draw(_ ctx: CGContext, line w: CGFloat, gap: CGFloat, dial: Double = 0) {
        drawBase(ctx, line: w, gap: gap)
        cutMarks(ctx, gap: gap, dial: dial)
    }

    /// The time's capsule beside the tomato, in menu bar points: as tall as the mark (`Glyph.menuMarkHeight`), round ends, the
    /// digits `capsulePadding` from each end, `capsuleGap` from the tomato's canvas, which with the canvas's own margin
    /// leaves about 4 pt of clear space between the tomato and the capsule, as between the system's neighbouring icons.
    static let capsulePadding: CGFloat = 6
    static let capsuleGap: CGFloat = 3
    static func capsule(textWidth: CGFloat, after canvas: CGSize) -> CGRect {
        CGRect(x: canvas.width + capsuleGap, y: (canvas.height - Glyph.menuMarkHeight) / 2,
               width: textWidth + 2 * capsulePadding, height: Glyph.menuMarkHeight)
    }
}
