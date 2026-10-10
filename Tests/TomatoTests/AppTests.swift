import AppKit
import XCTest
import TomatoCore
@testable import Tomato

/// The family's menu bar standard. Nothing here touches the menu bar: the menu is built, never shown.
@MainActor
final class AppTests: XCTestCase {
    func testTheIconIsATemplateImage22PointsHigh() {
        for badge in [false, true] {
            let image = MenuBarIcon.image(badge: badge)
            XCTAssertEqual(image.size.height, 22)
            XCTAssertEqual(image.representations.count, 2, "a picture for a standard screen and one for a Retina screen")
            XCTAssertEqual(image.size, MenuBarIcon.canvas)
            XCTAssertTrue(image.isTemplate)
        }
    }

    /// The icon drawn at four pixels to the point, which is how the tests below measure it.
    private func icon(badge: Bool = false, face: MenuBarIcon.TimerFace? = nil) -> NSImage {
        MenuBarIcon.image(badge: badge, face: face, scales: [4])
    }

    private func face(_ text: String, dial: Double = 0.4, outlined: Bool = false,
                      style: MenuBarStyle = .both) -> MenuBarIcon.TimerFace {
        .init(dial: dial, time: .init(text: text, sample: "00:00", outlined: outlined), style: style)
    }

    func testTheCapsuleKeepsItsWidthWhateverTheDigits() {
        func width(_ text: String, outlined: Bool = false, badge: Bool = false) -> CGFloat {
            icon(badge: badge, face: face(text, outlined: outlined)).size.width
        }
        let widths = ["00:00", "08:08", "11:11", "23:59", "60:00"].map { width($0) }
        XCTAssertEqual(Set(widths).count, 1)
        XCTAssertEqual(widths[0], widths[0].rounded(), "a whole number of points")
        XCTAssertGreaterThan(widths[0], MenuBarIcon.canvas.width, "the capsule stands beside the tomato")
        XCTAssertEqual(width("24:13", outlined: true), widths[0])
        XCTAssertEqual(width("24:13", badge: true), widths[0])
        let image = icon(face: face("24:13"))
        XCTAssertEqual(image.size.height, MenuBarIcon.canvas.height)
        XCTAssertTrue(image.isTemplate)
        // What keeps the digits from changing the width inside the capsule: they are all as wide as the zero.
        let digits = (0...9).map { NSAttributedString(string: String($0), attributes: [.font: MenuBarIcon.capsuleFont]).size().width }
        XCTAssertEqual(Set(digits).count, 1)
    }

    func testWithoutTheTimeOnlyTheTomatoIsDrawn() {
        let hidden = icon(face: face("24:13", style: .tomatoOnly))
        XCTAssertEqual(hidden.size, MenuBarIcon.canvas, "the same canvas as at rest")
        XCTAssertEqual(hidden.accessibilityDescription, "24:13", "VoiceOver still reads the time")
    }

    /// The time reads like the system clock beside it: the digits are as big as the menu bar's own text.
    func testTheDigitsAreAsTallAsTheDigitsOfTheSystemClock() {
        let system = NSFont.menuBarFont(ofSize: 0)
        XCTAssertEqual(MenuBarIcon.capsuleFont.pointSize, system.pointSize)
        XCTAssertEqual(MenuBarIcon.capsuleFont.capHeight, system.capHeight, accuracy: 0.05, "the same cap height, in points")
    }

    func testThePlateIsSolidAndTheOutlineIsHollow() throws {
        let plate = icon(face: face("24:13"))
        let outline = icon(face: face("24:13", outlined: true))
        let rect = try XCTUnwrap(MenuBarIcon.capsuleLayout(.init(text: "24:13", sample: "00:00"))).rect
        XCTAssertEqual(rect.height, 16, "as tall as the tomato, and as the system's text line")
        XCTAssertEqual(rect.height, Glyph.menuMarkHeight)
        // 3 pt from the left end, in the middle: inside the round end, left of the digits.
        XCTAssertEqual(alpha(of: plate, x: rect.minX + 3, y: rect.midY), 1, accuracy: 0.01)
        XCTAssertEqual(alpha(of: outline, x: rect.minX + 3, y: rect.midY), 0, accuracy: 0.01)
        // The outline's line itself is on the edge.
        XCTAssertGreaterThan(alpha(of: outline, x: rect.midX, y: rect.minY + 0.8), 0.5)
    }

    /// The digits are cut out of the plate. They stand on the baseline of the system's menu bar text, and their cap height
    /// is in the middle of the capsule.
    func testTheDigitsStandOnTheBaselineOfTheSystemTextInTheMiddleOfTheCapsule() throws {
        let image = icon(face: face("11:11"))
        let rect = try XCTUnwrap(MenuBarIcon.capsuleLayout(.init(text: "11:11", sample: "00:00"))).rect
        let rep = bitmap(of: image, scale: 4)
        var top = Int.max, bottom = -1
        for y in Int((rect.minY + 2.5) * 4)..<Int((rect.maxY - 2.5) * 4) {
            for x in Int((rect.minX + 6) * 4)..<Int((rect.maxX - 6) * 4) where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 1) < 0.5 {
                top = min(top, y); bottom = max(bottom, y)
            }
        }
        XCTAssertGreaterThan(bottom, 0, "the digits are cut out")
        XCTAssertEqual(CGFloat(bottom + 1) / 4, MenuBarIcon.canvas.height - MenuBarIcon.systemBaseline(), accuracy: 0.3)
        XCTAssertEqual(CGFloat(top + bottom + 1) / 8, rect.midY, accuracy: 0.45, "the cap height is in the middle")
    }

    /// The opacity at a point of the cup's box (100 units square), found through the same placement the icon draws with.
    private func alpha(of image: NSImage, unit x: CGFloat, _ y: CGFloat) -> CGFloat {
        let point = CGPoint(x: x, y: y).applying(Glyph.menuPlacement(bounds: Tomato.bounds, scale: 4))
        return alpha(of: image, x: point.x, y: point.y)
    }

    /// The kitchen timer: a slit across the belly parts a lower half with a pointer from an upper half with the marks of the
    /// dial. At rest a mark stands over the pointer; turned by half the distance between two marks, none does.
    func testTheTomatoIsCutInTwoWithMarksAndAPointer() {
        let rest = icon()
        let shifted = icon(face: face("24:13", dial: 1.0 / 24, style: .tomatoOnly))
        let slit = Tomato.slit, gap = Glyph.menuGap
        for (name, image) in [("rest", rest), ("shifted", shifted)] {
            XCTAssertEqual(alpha(of: image, unit: 25, slit), 0, accuracy: 0.01, "\(name): the slit goes across")
            XCTAssertEqual(alpha(of: image, unit: 75, slit), 0, accuracy: 0.01, "\(name): the slit goes across")
            XCTAssertEqual(alpha(of: image, unit: 45, slit - gap / 2 - 5), 1, accuracy: 0.01, "\(name): the upper half is solid between the marks")
            XCTAssertEqual(alpha(of: image, unit: 30, slit + gap / 2 + 6), 1, accuracy: 0.01, "\(name): the lower half is solid")
            XCTAssertEqual(alpha(of: image, unit: 50, slit + gap / 2 + 5), 0, accuracy: 0.01, "\(name): the pointer is cut into the lower half")
        }
        let markHeight = slit - gap / 2 - Tomato.markHeight / 2
        XCTAssertEqual(alpha(of: rest, unit: 50, markHeight), 0, accuracy: 0.01, "at rest a mark stands over the pointer")
        XCTAssertEqual(alpha(of: shifted, unit: 50, markHeight), 1, accuracy: 0.01, "turned half a step, the middle is between two marks")
        XCTAssertEqual(alpha(of: shifted, unit: 50 + Tomato.beltRadius * CGFloat(sin(Double.pi / 12)), markHeight), 0, accuracy: 0.01,
                       "the mark moved to the right")
    }

    func testTheDotOfAnUpdateSitsInTheTopRightCornerOfTheWholeIcon() throws {
        let rest = icon()
        let dotted = icon(badge: true)
        // The body of the tomato, below the slit.
        XCTAssertEqual(alpha(of: rest, unit: 50, 88), 1, accuracy: 0.01)
        XCTAssertEqual(alpha(of: dotted, unit: 50, 88), 1, accuracy: 0.01)
        // The corner is empty until the dot of an update comes.
        let centre = CGPoint(x: MenuBarIcon.badge.midX, y: MenuBarIcon.badge.midY)
        XCTAssertEqual(alpha(of: rest, x: centre.x, y: centre.y), 0, accuracy: 0.01)
        XCTAssertEqual(alpha(of: dotted, x: centre.x, y: centre.y), 1, accuracy: 0.01)
        // The dot has the same place beside a capsule: in its top right corner.
        let capsule = icon(badge: true, face: face("24:13"))
        XCTAssertEqual(alpha(of: capsule, x: capsule.size.width - 3.5, y: centre.y), 1, accuracy: 0.01)
        XCTAssertEqual(alpha(of: icon(face: face("24:13")), x: capsule.size.width - 3.5, y: centre.y), 0, accuracy: 0.01)
    }

    private func bitmap(of image: NSImage, scale: CGFloat) -> NSBitmapImageRep {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(image.size.width * scale),
                                   pixelsHigh: Int(image.size.height * scale), bitsPerSample: 8, samplesPerPixel: 4,
                                   hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = image.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(origin: .zero, size: image.size))
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    /// The opacity of the image at a point (from the top left), drawn at four pixels to the point.
    private func alpha(of image: NSImage, x: CGFloat, y: CGFloat) -> CGFloat {
        let scale: CGFloat = 4
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(image.size.width * scale),
                                         pixelsHigh: Int(image.size.height * scale), bitsPerSample: 8, samplesPerPixel: 4,
                                         hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0,
                                         bitsPerPixel: 0) else { return -1 }
        rep.size = image.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(origin: .zero, size: image.size))
        NSGraphicsContext.restoreGraphicsState()
        return rep.colorAt(x: Int(x * scale), y: Int(y * scale))?.alphaComponent ?? -1
    }

    // MARK: The frames of the turning tomato

    /// The opacity of every pixel of the image's picture (the first, or the one at `index`), row by row.
    private func alphas(_ image: NSImage, _ index: Int = 0) throws -> [UInt8] {
        let rep = try XCTUnwrap(image.representations[index] as? NSBitmapImageRep)
        let data = try XCTUnwrap(rep.bitmapData)
        var bytes: [UInt8] = []
        for y in 0..<rep.pixelsHigh { for x in 0..<rep.pixelsWide { bytes.append(data[y * rep.bytesPerRow + x * 4 + 3]) } }
        return bytes
    }

    /// The icon drawn straight into one bitmap, nothing kept: the tomato in one go, the capsule, the dot of an update, each
    /// with the opacity `presence` gives it (a picture drawn in a transparency layer, as one piece), where it gives it: the
    /// tomato whole on whole pixels or smaller about its middle, the capsule cut off left of where it shows, shorter, its
    /// digits faint.
    private func drawnAnew(badge: Bool, face: MenuBarIcon.TimerFace?, presence: Double = 1, scale: CGFloat) throws -> [UInt8] {
        let layout = MenuBarIcon.capsuleLayout(face?.capsule)
        let composition = MenuBarIcon.composition(face: face, presence: CGFloat(presence), layout: layout)
        let size = composition.size
        let width = Int((size.width * scale).rounded()), height = Int((size.height * scale).rounded())
        let ctx = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: scale, y: -scale)
        ctx.setStrokeColor(.black)
        ctx.setFillColor(.black)
        ctx.setLineWidth(MenuBarIcon.lineWidth)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        if let tomato = composition.tomato {
            ctx.saveGState()
            ctx.setAlpha(tomato.alpha)
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
            let whole = tomato.rect.size == MenuBarIcon.canvas && tomato.cuts == 1
            ctx.translateBy(x: whole ? (tomato.rect.minX * scale).rounded() / scale : tomato.rect.minX, y: tomato.rect.minY)
            ctx.scaleBy(x: tomato.rect.width / MenuBarIcon.canvas.width, y: tomato.rect.height / MenuBarIcon.canvas.height)
            Glyph.enterMenuBox(ctx, bounds: Tomato.bounds, scale: scale)
            Tomato.draw(ctx, line: Glyph.menuLine, gap: Glyph.menuGap * tomato.cuts, dial: face?.dial ?? 0)
            if tomato.cuts < 1 {
                // The fruit filled in as the cuts close.
                ctx.setAlpha(1 - tomato.cuts)
                ctx.addPath(Tomato.body())
                ctx.fillPath()
            }
            ctx.endTransparencyLayer()
            ctx.restoreGState()
        }
        if let placed = composition.capsule, let capsule = face?.capsule {
            ctx.saveGState()
            if let from = placed.shownFrom {
                let x = (from * scale).rounded() / scale
                ctx.clip(to: CGRect(x: x, y: 0, width: max(size.width - x, 0), height: size.height))
            }
            ctx.setAlpha(placed.alpha)
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
            MenuBarIcon.drawCapsule(capsule, rect: placed.home, plate: placed.plate, digits: placed.digits, in: ctx)
            ctx.endTransparencyLayer()
            ctx.restoreGState()
        }
        if badge {
            let dot = MenuBarIcon.badge.offsetBy(dx: size.width - MenuBarIcon.canvas.width, dy: 0)
            ctx.setBlendMode(.clear)
            ctx.fillEllipse(in: dot.insetBy(dx: -MenuBarIcon.badgeGap, dy: -MenuBarIcon.badgeGap))
            ctx.setBlendMode(.normal)
            ctx.fillEllipse(in: dot)
        }
        let data = try XCTUnwrap(ctx.data).assumingMemoryBound(to: UInt8.self)
        var bytes: [UInt8] = []
        for y in 0..<height { for x in 0..<width { bytes.append(data[y * ctx.bytesPerRow + x * 4 + 3]) } }
        return bytes
    }

    /// The kept pictures and what is drawn over them are the picture that drawing everything anew gives, at every position of
    /// the dial, in every style of the menu bar, with the capsule as a plate or an outline, and with the dot.
    func testTheFramesAreThePictureOfDrawingEverythingAnew() throws {
        let frames = IconFrames()
        let cases: [(String, MenuBarIcon.TimerFace?, Bool)] = [
            ("rest", nil, false), ("rest with the dot", nil, true),
            ("running", face("24:13", dial: 0.37), false), ("running, dial 0", face("24:13", dial: 0), false),
            ("running, dial 0.99", face("08:08", dial: 0.99), false), ("running with the dot", face("24:13", dial: 0.5), true),
            ("paused", face("12:00", dial: 0.2, outlined: true), false),
            ("the tomato alone", face("24:13", dial: 0.7, style: .tomatoOnly), false),
            ("the time alone", face("24:13", dial: 0.7, style: .timerOnly), false),
            ("the time alone with the dot", face("24:13", dial: 0.7, style: .timerOnly), true),
            ("the time alone, paused", face("12:00", dial: 0.2, outlined: true, style: .timerOnly), false)]
        for scale: CGFloat in [1, 2, 4] {
            for (name, face, badge) in cases {
                let kept = try alphas(frames.image(badge: badge, face: face, scales: [scale]))
                let anew = try drawnAnew(badge: badge, face: face, scale: scale)
                XCTAssertEqual(kept.count, anew.count, "\(name) at \(scale)x")
                let worst = zip(kept, anew).map { abs(Int($0) - Int($1)) }.max() ?? 255
                XCTAssertLessThanOrEqual(worst, 1, "\(name) at \(scale)x: the same picture, to a rounding")
            }
        }
    }

    /// While the capsule is on its way in or out, the pictures are the same too: the tomato where it is on the way and the
    /// capsule as much of it as shows, or, when the time stands alone, the plate growing out of the shrinking tomato and the
    /// digits coming, as a plate and as an outline.
    func testTheFramesOfTheCapsuleComingInAreThePictureOfDrawingEverythingAnew() throws {
        let frames = IconFrames()
        for style in [MenuBarStyle.both, .timerOnly] {
            for outlined in [false, true] {
                for presence in [0.0, 0.1, 0.23, 0.37, 0.5, 0.64, 0.8, 0.95, 1] {
                    let running = face("24:13", dial: 0.3, outlined: outlined, style: style)
                    for scale: CGFloat in [2, 4] {
                        let name = "\(style)\(outlined ? ", outlined," : "") at \(presence), \(scale)x"
                        let kept = try alphas(frames.image(badge: presence > 0.5, face: running, presence: presence, scales: [scale]))
                        let anew = try drawnAnew(badge: presence > 0.5, face: running, presence: presence, scale: scale)
                        XCTAssertEqual(kept.count, anew.count, name)
                        let worst = zip(kept, anew).map { abs(Int($0) - Int($1)) }.max() ?? 255
                        XCTAssertLessThanOrEqual(worst, 2, name)
                    }
                }
            }
        }
    }

    /// A frame draws only the upper half anew: the tomato's base is drawn once for each scale, the capsule once for each time.
    func testAFrameDrawsOnlyTheUpperHalfAnew() {
        let frames = IconFrames()
        for step in 0..<60 {
            _ = frames.image(badge: false, face: face("24:13", dial: Double(step) / 1200), scales: [2])
        }
        XCTAssertEqual(frames.tomatoDrawings, 1, "the tomato without its upper half's calyx and marks is drawn once")
        XCTAssertEqual(frames.capsuleDrawings, 1, "so is the capsule with the same time")
        for step in 0..<60 {
            _ = frames.image(badge: false, face: face("24:12", dial: Double(step) / 1200), scales: [2])
        }
        XCTAssertEqual(frames.tomatoDrawings, 1)
        XCTAssertEqual(frames.capsuleDrawings, 2, "a new time, a new capsule")
        _ = frames.image(badge: true, face: face("24:12", dial: 0.5), scales: [2])
        _ = frames.image(badge: false, face: face("24:12", dial: 0.5, outlined: true), scales: [2])
        XCTAssertEqual(frames.tomatoDrawings, 1, "the dot is not part of it")
        XCTAssertEqual(frames.capsuleDrawings, 3, "a paused capsule is another picture")
        for presence in [0.0, 0.3, 0.6, 1] {
            _ = frames.image(badge: false, face: face("24:12", dial: 0.5, outlined: true, style: .timerOnly), presence: presence, scales: [2])
        }
        XCTAssertEqual(frames.tomatoDrawings, 1, "the capsule appearing and the style do not redraw the base")
        XCTAssertEqual(frames.capsuleDrawings, 3, "and it is the same capsule")
        _ = frames.image(badge: false, face: face("24:12", dial: 0.5, outlined: true), scales: [1, 2])
        XCTAssertEqual(frames.tomatoDrawings, 2, "a scale of its own")
    }

    /// The turn looks smooth because a frame moves the upper half by a fraction of a pixel: no pixel changes by more than half
    /// its ink from one frame to the next, at the pace the tomato really turns, a sepal turning edge-on or away included.
    func testNoPixelJumpsFromOneFrameToTheNext() throws {
        let frames = IconFrames()
        let step = 1 / (TimerDisplay.framesPerSecond * TimerDisplay.turnSeconds)
        var previous: [UInt8]?
        var worst = 0
        for i in 0..<Int(1 / step / 4) {   // a quarter of a turn: the picture comes round to itself
            let now = try alphas(frames.image(badge: false, face: face("24:13", dial: Double(i) * step, style: .tomatoOnly), scales: [2]))
            if let previous { worst = max(worst, zip(now, previous).map { abs(Int($0) - Int($1)) }.max() ?? 0) }
            previous = now
        }
        XCTAssertGreaterThan(worst, 0, "the upper half does move")
        XCTAssertLessThan(worst, 128, "and never by more than half a pixel's ink in a frame")
    }

    // MARK: The styles of the menu bar, the gap and the capsule appearing

    /// The leftmost and rightmost columns of ink, at four pixels to the point, in the columns from `from` to `to` (points).
    private func inkColumns(_ image: NSImage, from: CGFloat, to: CGFloat) -> (first: Int, last: Int)? {
        let rep = bitmap(of: image, scale: 4)
        var first: Int?, last: Int?
        for x in Int(from * 4)..<min(Int(to * 4), rep.pixelsWide) {
            for y in 0..<rep.pixelsHigh where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.05 {
                first = first ?? x
                last = x
                break
            }
        }
        return first.map { ($0, last ?? $0) }
    }

    /// The capsule stands about 4.5 pt from the tomato, as neighbouring icons do, not the 3 pt it stood before.
    func testTheCapsuleStandsAboutFourAndAHalfPointsFromTheTomato() throws {
        let image = icon(face: face("24:13"))
        let rect = try XCTUnwrap(MenuBarIcon.capsuleLayout(.init(text: "24:13", sample: "00:00"))).rect
        let tomato = try XCTUnwrap(inkColumns(image, from: 0, to: rect.minX))
        let capsule = try XCTUnwrap(inkColumns(image, from: rect.minX, to: image.size.width))
        let gap = CGFloat(capsule.first - (tomato.last + 1)) / 4
        XCTAssertEqual(gap, 4.5, accuracy: 0.7, "points of clear space between the tomato and the capsule")
        XCTAssertGreaterThan(MenuBarIcon.gapToTomato, 4)
        XCTAssertLessThan(MenuBarIcon.gapToTomato, 5)
        XCTAssertEqual(MenuBarIcon.gapToTomato, gap, accuracy: 0.4, "and the figure the code states is the one drawn")
        XCTAssertEqual(rect.minX, rect.minX.rounded(), "on a whole point, so that it is sharp on every screen")
    }

    func testTheThreeStylesOfTheMenuBar() throws {
        let layout = try XCTUnwrap(MenuBarIcon.capsuleLayout(.init(text: "24:13", sample: "00:00")))
        let both = icon(face: face("24:13", style: .both)), tomato = icon(face: face("24:13", style: .tomatoOnly))
        let timer = icon(face: face("24:13", style: .timerOnly))
        XCTAssertEqual(tomato.size, MenuBarIcon.canvas, "the tomato alone: the tomato's canvas")
        XCTAssertEqual(both.size, layout.size, "the tomato and the capsule")
        XCTAssertEqual(timer.size.width, layout.rect.width + 2 * Glyph.menuMargin, "the time alone: the capsule and its margins")
        XCTAssertEqual(timer.size.height, MenuBarIcon.canvas.height)
        XCTAssertLessThan(timer.size.width, both.size.width)
        // The tomato is the same picture alone and beside the capsule.
        let columns = Int(MenuBarIcon.canvas.width) * 4, wide = Int(both.size.width) * 4
        let alone = try alphas(tomato), beside = try alphas(both)
        for row in 0..<Int(MenuBarIcon.canvas.height) * 4 {
            XCTAssertEqual(Array(alone[(row * columns)..<((row + 1) * columns)]), Array(beside[(row * wide)..<(row * wide + columns)]),
                           "row \(row)")
        }
        // At rest, in every style, the tomato is there: the menu bar item does not go.
        for style in MenuBarStyle.allCases { XCTAssertTrue(style.showsTomato(timerRunning: false), "\(style) at rest") }
        XCTAssertEqual(MenuBarIcon.composition(face: nil, presence: 1, layout: nil).tomato?.alpha, 1)
        // The time alone has no tomato: the capsule stands at the margin, and the first and last ink are its two ends.
        let composition = MenuBarIcon.composition(face: face("24:13", style: .timerOnly), presence: 1, layout: layout)
        XCTAssertNil(composition.tomato)
        XCTAssertEqual(composition.capsule?.home.minX, Glyph.menuMargin)
        XCTAssertEqual(composition.capsule?.home.width, layout.rect.width)
        XCTAssertEqual(composition.capsule?.plate, composition.capsule?.home, "the whole plate")
        XCTAssertEqual(composition.capsule?.digits, 1)
        let ink = try XCTUnwrap(inkColumns(timer, from: 0, to: timer.size.width))
        XCTAssertEqual(CGFloat(ink.first) / 4, Glyph.menuMargin, accuracy: 0.3)
        XCTAssertEqual(CGFloat(ink.last + 1) / 4, timer.size.width - Glyph.menuMargin, accuracy: 0.3)
        // The tomato and the capsule together: both are drawn whole, at full opacity.
        let both1 = MenuBarIcon.composition(face: face("24:13", style: .both), presence: 1, layout: layout)
        XCTAssertEqual(both1.tomato, MenuBarIcon.Placed(rect: CGRect(origin: .zero, size: MenuBarIcon.canvas), alpha: 1))
        XCTAssertEqual(both1.capsule, MenuBarIcon.CapsulePlace(home: layout.rect, plate: layout.rect, alpha: 1))
        XCTAssertNil(both1.capsule?.shownFrom, "nothing of it cut off")
        // Only the tomato: no capsule at all.
        XCTAssertNil(MenuBarIcon.composition(face: face("24:13", style: .tomatoOnly), presence: 1, layout: nil).capsule)
    }

    // MARK: The capsule coming in and going out

    /// The frames the status item draws while the capsule comes in (from nil to `running`) or goes out, at `rate` frames a
    /// second from the start of the movement to its end, the end included, with the time of each in seconds.
    private func movement(_ running: MenuBarIcon.TimerFace, comingIn: Bool, rate: Double = 120,
                          scales: [CGFloat] = [2]) -> [(time: TimeInterval, image: NSImage)] {
        var presence = IconPresence()
        if !comingIn { presence.change(from: nil, to: running, at: -10, reducesMotion: false) }
        presence.change(from: comingIn ? nil : running, to: comingIn ? running : nil, at: 0, reducesMotion: false)
        let current = comingIn ? running : nil
        var times = Array(stride(from: 0, to: presence.end, by: 1 / rate))
        times.append(presence.end)
        return times.map { time in
            if time >= presence.end { presence.settle(at: time) }
            return (time, MenuBarIcon.image(face: presence.face(current, at: time), presence: presence.value(at: time), scales: scales))
        }
    }

    /// The status item changes its width in one step: from the first frame of the way in the image is as wide as it will
    /// be, in whole points, and it stays so until the capsule is gone; then, in the last frame of the way out, it is as
    /// narrow as the tomato at once. No width between.
    func testWhileTheCapsuleMovesTheImageKeepsItsFinalWidthFromTheFirstFrame() {
        for style in [MenuBarStyle.both, .timerOnly] {
            for outlined in [false, true] {
                let running = face("25:00", dial: 0, outlined: outlined, style: style)
                let final = icon(face: running).size
                XCTAssertEqual(final.width, final.width.rounded(), "\(style): a whole number of points")
                XCTAssertGreaterThan(final.width, MenuBarIcon.canvas.width)
                let coming = movement(running, comingIn: true)
                XCTAssertGreaterThanOrEqual(coming.count, 42, "0.35 s at 120 frames a second")
                for (time, image) in coming {
                    XCTAssertEqual(image.size, final, "\(style) coming in, at \(time) s")
                }
                let going = movement(running, comingIn: false)
                for (time, image) in going.dropLast() {
                    XCTAssertEqual(image.size, final, "\(style) going out, at \(time) s")
                }
                XCTAssertEqual(going.last?.image.size, MenuBarIcon.canvas, "\(style): gone, the tomato's width")
                for (_, image) in coming + going { XCTAssertEqual(image.size.height, MenuBarIcon.canvas.height) }
            }
        }
    }

    /// The menu bar keeps the item's right edge and moves the icons on its left when the item widens. So in the first frame
    /// the tomato is at the right end of the wide image, the very picture of the tomato at rest, with nothing left of it;
    /// and in the last frame of the way out it is there again, so that the narrow image that follows has it in the same
    /// place on the screen.
    func testInTheFirstFrameTheTomatoStandsAtTheRightEdgeWhereItStoodOnTheScreen() throws {
        let rest = try alphas(icon())
        let narrow = Int(MenuBarIcon.canvas.width) * 4, rows = Int(MenuBarIcon.canvas.height) * 4
        for style in [MenuBarStyle.both, .timerOnly] {
            let running = face("25:00", dial: 0, style: style)
            let layout = MenuBarIcon.capsuleLayout(running.capsule)
            let first = MenuBarIcon.composition(face: running, presence: 0, layout: layout)
            XCTAssertEqual(first.tomato, MenuBarIcon.Placed(rect: CGRect(x: first.size.width - MenuBarIcon.canvas.width, y: 0,
                                                                         width: MenuBarIcon.canvas.width, height: MenuBarIcon.canvas.height),
                                                            alpha: 1), "\(style): whole, at the right edge")
            XCTAssertNil(first.capsule, "\(style): nothing of the capsule yet")
            let image = MenuBarIcon.image(face: running, presence: 0, scales: [4])
            let pixels = try alphas(image), wide = Int(image.size.width) * 4
            for row in 0..<rows {
                XCTAssertEqual(Array(pixels[(row * wide + wide - narrow)..<((row + 1) * wide)]), Array(rest[(row * narrow)..<((row + 1) * narrow)]),
                               "\(style), row \(row): the tomato at rest")
                XCTAssertTrue(pixels[(row * wide)..<(row * wide + wide - narrow)].allSatisfy { $0 == 0 }, "\(style), row \(row): nothing left of it")
            }
            // On the way out the tomato gets to the right edge as the capsule goes.
            let almostGone = MenuBarIcon.composition(face: running, presence: 0.001, layout: layout)
            XCTAssertEqual(almostGone.tomato?.rect.maxX ?? 0, first.size.width, accuracy: 0.1, "\(style)")
        }
    }

    /// The tomato goes over the capsule and the capsule shows only right of the tomato's ink and the clear space beside it:
    /// in no frame do the two share a pixel, and the clear space between them is never under 3 pt (4.2 at rest).
    func testTheCapsuleNeverTouchesTheTomatosInk() throws {
        let frames = IconFrames()
        func columns(_ alphas: [UInt8], width: Int) -> [Int] {
            (0..<width).filter { x in stride(from: x, to: alphas.count, by: width).contains { alphas[$0] > 0 } }
        }
        for outlined in [false, true] {
            let running = face("24:13", dial: 0.4, outlined: outlined)
            let layout = MenuBarIcon.capsuleLayout(running.capsule)
            var seen = 0
            for step in 0...60 {
                let whole = MenuBarIcon.composition(face: running, presence: CGFloat(step) / 60, layout: layout)
                guard whole.capsule != nil else { continue }
                var tomatoAlone = whole, capsuleAlone = whole
                tomatoAlone.capsule = nil
                capsuleAlone.tomato = nil
                for scale: CGFloat in [1, 2, 4] {
                    let name = "\(outlined ? "outlined, " : "")step \(step), \(scale)x"
                    let tomato = try alphas(frames.image(tomatoAlone, face: running, badge: false, scales: [scale]))
                    let capsule = try alphas(frames.image(capsuleAlone, face: running, badge: false, scales: [scale]))
                    XCTAssertFalse(zip(tomato, capsule).contains { $0 > 0 && $1 > 0 }, "\(name): a pixel of both")
                    let width = Int(whole.size.width * scale)
                    guard let tomatoRight = columns(tomato, width: width).max(),
                          let capsuleLeft = columns(capsule, width: width).min() else { continue }
                    XCTAssertGreaterThanOrEqual(CGFloat(capsuleLeft - tomatoRight - 1) / scale, 3, name)
                    seen += 1
                }
            }
            XCTAssertGreaterThan(seen, 100, "the capsule did show on the way")
        }
    }

    /// With the time alone the capsule grows out of a circle as tall as itself, where the tomato stands, to the left; the
    /// tomato is gone before the digits show.
    func testWithTheTimeAloneTheCapsuleGrowsFromACircleWhereTheTomatoStands() throws {
        let running = face("24:13", dial: 0, style: .timerOnly)
        let layout = MenuBarIcon.capsuleLayout(running.capsule)
        let final = MenuBarIcon.composition(face: running, presence: 1, layout: layout)
        let home = try XCTUnwrap(final.capsule?.home)
        let start = try XCTUnwrap(MenuBarIcon.composition(face: running, presence: 0.0001, layout: layout).capsule)
        let ink = MenuBarIcon.box.offsetBy(dx: final.size.width - MenuBarIcon.canvas.width, dy: 0)
        XCTAssertEqual(start.plate.height, Glyph.menuMarkHeight)
        XCTAssertEqual(start.plate.width, start.plate.height, accuracy: 0.05, "a circle")
        XCTAssertEqual(start.plate.midX, ink.midX, accuracy: 0.05, "on the tomato")
        XCTAssertEqual(start.plate.midY, ink.midY, accuracy: 0.001)
        XCTAssertEqual(start.alpha, 0, accuracy: 0.01, "and nothing of it yet")
        var previous = start.plate
        for step in 1...40 {
            let p = CGFloat(step) / 40
            let now = try XCTUnwrap(MenuBarIcon.composition(face: running, presence: p, layout: layout))
            let plate = try XCTUnwrap(now.capsule?.plate)
            XCTAssertLessThan(plate.minX, previous.minX, "it grows to the left")
            XCTAssertEqual(plate.maxX, home.maxX, accuracy: 0.6, "its right end stays")
            if now.tomato != nil { XCTAssertEqual(now.capsule?.digits, 0, "no digits beside the tomato, at \(p)") }
            previous = plate
        }
        XCTAssertEqual(previous, home)
    }

    /// The last frame of the way in is the picture of the running timer, and the last of the way out the tomato at rest,
    /// pixel for pixel, so nothing changes when the movement stops.
    func testTheLastFrameIsThePictureAtRestPixelForPixel() throws {
        for style in [MenuBarStyle.both, .timerOnly] {
            for outlined in [false, true] {
                for badge in [false, true] {
                    let running = face("24:13", dial: 0.3, outlined: outlined, style: style)
                    let name = "\(style)\(outlined ? ", outlined" : "")\(badge ? ", with the dot" : "")"
                    var presence = IconPresence()
                    presence.change(from: nil, to: running, at: 0, reducesMotion: false)
                    let inAt = presence.end
                    let last = MenuBarIcon.image(badge: badge, face: presence.face(running, at: inAt),
                                                 presence: presence.value(at: inAt), scales: [1, 2])
                    let still = IconFrames().image(badge: badge, face: running, scales: [1, 2])
                    presence.change(from: running, to: nil, at: 10, reducesMotion: false)
                    let goneAt = presence.end
                    presence.settle(at: goneAt)
                    let gone = MenuBarIcon.image(badge: badge, face: presence.face(nil, at: goneAt),
                                                 presence: presence.value(at: goneAt), scales: [1, 2])
                    let rest = IconFrames().image(badge: badge, face: nil, scales: [1, 2])
                    for index in 0..<2 {
                        XCTAssertEqual(try alphas(last, index), try alphas(still, index), "\(name): in, picture \(index)")
                        XCTAssertEqual(try alphas(gone, index), try alphas(rest, index), "\(name): gone, picture \(index)")
                    }
                }
            }
        }
    }

    func testTheMenuEndsWithTheFamilyItems() {
        let items = StatusItem.menu().items
        let tail = Array(items.suffix(5))
        XCTAssertEqual(tail.map(\.isSeparatorItem), [false, false, false, true, false])
        XCTAssertEqual(tail[0].action, #selector(AppDelegate.showSettings(_:)))
        XCTAssertEqual(tail[0].keyEquivalent, ",")
        XCTAssertEqual(tail[1].action, #selector(AppDelegate.checkForUpdates(_:)))
        XCTAssertEqual(tail[2].action, #selector(AppDelegate.showAbout(_:)))
        XCTAssertEqual(tail[4].action, #selector(NSApplication.terminate(_:)))
        XCTAssertEqual(tail[4].keyEquivalent, "q")
        // The app's own actions come first, a separator after them.
        let actions = AppActions.menuItems().count
        XCTAssertEqual(items.count, actions + (actions > 0 ? 1 : 0) + 5)
    }
}
