// Tomato (pomodoro timer), after the user's sample and a real kitchen timer: a solid tomato with a calyx of ten pointed
// sepals and a stem on top, cut across its belly by a thin slit into two halves. The upper half is the dial: it turns as a
// whole about the stem, which stands on the axis. Twelve marks round its belt and the sepals of the calyx go round with it;
// seen from the side they slide across, bunch up towards the edges, vanish behind the fruit and come back on the other side
// (`dial`). The lower half stands still and has one pointer cut into its top edge, at the front.
// The sepals are parted from the fruit by a thin gap (black on the tile, transparent in the menu bar), like the slit and the
// marks, so the whole mark is one white solid with transparent cuts. The menu bar shows the same mark, still at rest and
// with the upper half turning steadily while a timer runs, and the time in a capsule beside it (`capsule`). Only the upper
// half moves, so `drawBase` (the lower half and the fruit under the sepals) and `drawTop` (sepals, stem and marks) are
// separate: the menu bar draws the base once and the top anew for every frame.
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

    /// Where the stem stands: the axis the upper half turns about, on the crown of the fruit.
    static let center = Glyph.p(50, 30)
    static let stemTop = Glyph.p(50, 7)

    /// Where the slit lies: its middle line, across the widest part of the fruit.
    static let slit: CGFloat = 64
    /// The marks of the dial: twelve alike round the belt, `markHeight` tall above the slit, on a belt of `beltRadius` (a
    /// little inside the fruit's edge).
    static let marks = 12
    static let markHeight: CGFloat = 8.5
    static let beltRadius: CGFloat = 38
    /// The dial's full turn, in degrees.
    static let turn: Double = 360

    /// The marks in the dial's position: each as a vertical strip, wider where it faces us, narrower towards the edge,
    /// none on the far side. `dial` is the part of the full turn (0...1) that the upper half is turned from zero: at 0 a
    /// mark stands over the pointer, and so it does at every twelfth of a turn, the marks being twelve and alike. As the
    /// dial grows the marks go to the right.
    static func markStrips(dial: Double, gap: CGFloat) -> [CGRect] {
        let top = slit - gap / 2
        var strips: [CGRect] = []
        for k in 0..<marks {
            let angle = (Double(k) * turn / Double(marks) + dial * turn) * .pi / 180
            let facing = CGFloat(cos(angle))
            guard facing > 0.08 else { continue }
            let x = 50 + beltRadius * CGFloat(sin(angle)), width = gap * facing
            strips.append(CGRect(x: x - width / 2, y: top - markHeight, width: width, height: markHeight + 1))
        }
        return strips
    }

    /// The pointer on the lower half: a notch cut into its top edge, at the front, pointing up at the dial.
    static func pointer(gap: CGFloat) -> CGPath {
        let bottom = slit + gap / 2, p = Glyph.p
        let path = CGMutablePath()
        path.move(to: p(50, bottom - 0.5))
        path.addLine(to: p(55.5, bottom + 8))
        path.addLine(to: p(44.5, bottom + 8))
        path.closeSubpath()
        return path
    }

    // MARK: The sepals

    /// The calyx: `sepals` alike, evenly spaced round the stem. At rest one points at us, so the calyx is the same turned by a
    /// tenth of a turn, as the row of marks is turned by a twelfth.
    static let sepals = 10
    /// A sepal starts at `sepalRoot`, under the disc round the stem, runs `sepalLength` box units to its tip at `sepalTip`,
    /// and is `sepalHalfWidth` wide at its widest. The two positions are colatitudes in radians: 0 at the stem, growing
    /// down the crown.
    static let sepalRoot = 0.14
    static let sepalTip = 1.0
    static let sepalLength = 28.0
    static let sepalHalfWidth = 6.0
    /// The disc the sepals grow from, round the foot of the stem.
    static let discRadius: CGFloat = 7

    /// The sepals radiate from the stem, each a flat blade, and droop over the crown, seen from the side. A blade that points
    /// `azimuth` (0 towards us, growing to the right, as the marks do) lies `reach` times `sin v` from the axis at the
    /// colatitude `v`; its height in the picture is `drop` times `1 - cos v`, how far down the crown it has gone, plus `lean`
    /// times `sin v` when it points at us, so the near side of the crown is a little lower in the picture than the far one.
    /// Its width is as the blade is seen: the width across it times the cosine of the azimuth.
    static let reach = 38.0, drop = 28.0, lean = 4.0
    /// A sepal that turns edge-on to us, and then away, is gone: it is behind the fruit.
    static let leastFacing = 0.02

    /// The sepal in its own flat measure, along it and across it: a lens pointed at both ends, up one side and down the other.
    private static func lens(steps n: Int) -> [CGPoint] {
        var points: [CGPoint] = []
        for i in 0...n {
            let t = Double(i) / Double(n)
            points.append(CGPoint(x: sepalLength * t, y: -sepalHalfWidth * 4 * t * (1 - t)))
        }
        for i in stride(from: n - 1, to: 0, by: -1) {
            let t = Double(i) / Double(n)
            points.append(CGPoint(x: sepalLength * t, y: sepalHalfWidth * 4 * t * (1 - t)))
        }
        return points
    }

    /// A convex polygon, counter-clockwise, grown by `m` all round, its corners rounded.
    private static func grown(_ polygon: [CGPoint], by m: Double) -> [CGPoint] {
        guard m > 0 else { return polygon }
        let n = polygon.count
        func normal(_ a: CGPoint, _ b: CGPoint) -> (Double, Double) {
            let dx = Double(b.x - a.x), dy = Double(b.y - a.y), length = max(hypot(dx, dy), 1e-9)
            return (dy / length, -dx / length)
        }
        var out: [CGPoint] = []
        for i in 0..<n {
            let before = normal(polygon[(i + n - 1) % n], polygon[i]), after = normal(polygon[i], polygon[(i + 1) % n])
            let turn = atan2(before.0 * after.1 - before.1 * after.0, before.0 * after.0 + before.1 * after.1)
            let steps = max(1, Int((abs(turn) / 0.4).rounded(.up)))
            for k in 0...steps {
                let a = turn * Double(k) / Double(steps), c = cos(a), s = sin(a)
                out.append(CGPoint(x: Double(polygon[i].x) + m * (before.0 * c - before.1 * s),
                                   y: Double(polygon[i].y) + m * (before.0 * s + before.1 * c)))
            }
        }
        return out
    }

    /// A sepal's outline reduced to what does not change as the dial turns, so that a frame needs only the azimuth: for every
    /// point of the outline how far from the axis it lies along the sepal and across it, and how low it lies on the crown and
    /// how much lower still when the sepal points at us.
    struct SepalShape {
        fileprivate var out: [Double] = [], across: [Double] = [], down: [Double] = [], near: [Double] = []

        /// The outline in the picture when the sepal points `azimuth` radians; nothing once it has turned away from us.
        func outline(azimuth: Double) -> [CGPoint] {
            let facing = cos(azimuth)
            guard facing > leastFacing else { return [] }
            let side = sin(azimuth), x = Double(center.x), y = Double(center.y)
            return (0..<out.count).map { CGPoint(x: x + out[$0] * side + across[$0] * facing, y: y + down[$0] + near[$0] * facing) }
        }
    }

    /// The shape of a sepal `margin` wider all round: 0 for the sepal itself, the gap for the cut round it.
    static func sepalShape(margin: Double) -> SepalShape {
        let perUnit = (sepalTip - sepalRoot) / sepalLength
        var shape = SepalShape()
        for local in grown(lens(steps: 10), by: margin) {
            let v = max(0.02, sepalRoot + Double(local.x) * perUnit)
            shape.out.append(reach * sin(v))
            shape.across.append(Double(local.y))
            shape.down.append(drop * (1 - cos(v)))
            shape.near.append(lean * sin(v))
        }
        return shape
    }

    /// One sepal in the picture, `margin` wider all round, when it points `azimuth` radians; nothing once it has turned away.
    static func sepalOutline(azimuth: Double, margin: Double) -> [CGPoint] {
        sepalShape(margin: margin).outline(azimuth: azimuth)
    }

    private static func fill(_ ctx: CGContext, polygon: [CGPoint]) {
        guard polygon.count > 2 else { return }
        ctx.addLines(between: polygon)
        ctx.closePath()
        ctx.fillPath()
    }

    // MARK: Drawing

    /// The lower half with its pointer, and the fruit of the upper half with nothing on it. It stands still while the upper
    /// half turns, so the menu bar draws it once and keeps the picture (`IconFrames`).
    static func drawBase(_ ctx: CGContext, gap: CGFloat) {
        let top = slit - gap / 2, bottom = slit + gap / 2
        // The lower half stands still.
        ctx.saveGState()
        ctx.clip(to: CGRect(x: -50, y: bottom, width: 200, height: 200))
        Glyph.fill(ctx, body())
        ctx.restoreGState()
        Glyph.cut(ctx) { Glyph.fill(ctx, pointer(gap: gap)) }
        // The upper half: the fruit above the slit.
        ctx.saveGState()
        ctx.clip(to: CGRect(x: -50, y: -50, width: 200, height: 50 + top))
        Glyph.fill(ctx, body())
        ctx.restoreGState()
    }

    /// What turns with the dial, over what `drawBase` has drawn: the gaps cut round the sepals and the disc, the sepals, the
    /// disc, the stem on the axis, and last the marks cut into the belt. The sepals and the marks lie apart (the sepals and
    /// the gap round them end above y = 52, the marks begin at 54), so cutting the marks last changes nothing else. `dial`
    /// as above.
    static func drawTop(_ ctx: CGContext, line w: CGFloat, gap: CGFloat, dial: Double) {
        let top = slit - gap / 2
        ctx.saveGState()
        ctx.clip(to: CGRect(x: -50, y: -50, width: 200, height: 50 + top))
        let azimuths = (0..<sepals).map { (dial + Double($0) / Double(sepals)) * 2 * .pi }
        let sepal = sepalShape(margin: 0), cut = sepalShape(margin: Double(gap))
        Glyph.cut(ctx) {
            for azimuth in azimuths { fill(ctx, polygon: cut.outline(azimuth: azimuth)) }
            Glyph.fill(ctx, Glyph.disc(center, discRadius + gap))
        }
        for azimuth in azimuths { fill(ctx, polygon: sepal.outline(azimuth: azimuth)) }
        Glyph.fill(ctx, Glyph.disc(center, discRadius))
        Glyph.stroke(ctx, Glyph.line([center, stemTop]), w)
        Glyph.cut(ctx) { for strip in markStrips(dial: dial, gap: gap) { ctx.fill(strip) } }
        ctx.restoreGState()
    }

    /// The whole mark: `drawBase` and the top in the position of `dial`; 0 is the mark at rest, and the app icon's.
    static func draw(_ ctx: CGContext, line w: CGFloat, gap: CGFloat, dial: Double = 0) {
        drawBase(ctx, gap: gap)
        drawTop(ctx, line: w, gap: gap, dial: dial)
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
