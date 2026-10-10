import AppKit
import XCTest
import TomatoCore
@testable import Tomato

/// How the tomato fills its room: the 22 pt menu bar canvas and the tile of the app icon. Both come from the mark's bounds,
/// the rectangle its ink covers in the glyph's box, so that rectangle must be what the drawing really covers.
@MainActor
final class GlyphTests: XCTestCase {
    /// The ink of `draw` in box units, from a bitmap of 8 pixels per unit.
    private func ink(_ draw: (CGContext) -> Void) throws -> CGRect {
        let ppu: CGFloat = 8, origin: CGFloat = 20, side = Int(140 * ppu)
        let ctx = try XCTUnwrap(CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.translateBy(x: 0, y: CGFloat(side))
        ctx.scaleBy(x: ppu, y: -ppu)
        ctx.translateBy(x: origin, y: origin)
        ctx.setFillColor(.black)
        ctx.setStrokeColor(.black)
        Glyph.prepare(ctx)
        draw(ctx)
        let data = try XCTUnwrap(ctx.data).assumingMemoryBound(to: UInt8.self)
        var minX = side, minY = side, maxX = -1, maxY = -1
        for y in 0..<side {
            for x in 0..<side where data[y * ctx.bytesPerRow + x * 4 + 3] >= 8 {
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        return CGRect(x: CGFloat(minX) / ppu - origin, y: CGFloat(minY) / ppu - origin,
                      width: CGFloat(maxX + 1 - minX) / ppu, height: CGFloat(maxY + 1 - minY) / ppu)
    }

    /// The icon drawn at four pixels to the point, which is how the tests below measure it.
    private func icon(badge: Bool = false, face: MenuBarIcon.TimerFace? = nil) -> NSImage {
        MenuBarIcon.image(badge: badge, face: face, scales: [4])
    }

    private func assertSame(_ a: CGRect, _ b: CGRect, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        for (x, y) in [(a.minX, b.minX), (a.minY, b.minY), (a.maxX, b.maxX), (a.maxY, b.maxY)] {
            XCTAssertEqual(x, y, accuracy: 0.3, message, file: file, line: line)
        }
    }

    func testTheBoundsAreTheInkOfTheTomatoAtEveryPositionOfTheDial() throws {
        for dial in [0.0, 1.0 / 24, 0.4, 0.99] {
            assertSame(try ink { Tomato.draw($0, line: Glyph.menuLine, gap: Glyph.menuGap, dial: dial) }, Tomato.bounds,
                       "bounds of the tomato in Tomato.swift are out of date (dial \(dial))")
        }
    }

    /// A minute for a turn: six degrees a second, the upper half and everything on it. That is slow (the marks cross the
    /// middle of the belt at about 0.7 pt a second), and a frame moves them by a small fraction of a pixel.
    func testTheUpperHalfTurnsSixDegreesASecondInStepsTooSmallToSee() {
        XCTAssertEqual(TimerDisplay.turnSeconds, 60)
        XCTAssertEqual(TimerDisplay.degreesPerSecond, 6)
        let rim = 2 * Double.pi * Double(Tomato.beltRadius * Glyph.menuScale(for: Tomato.bounds))
        let speed = rim / TimerDisplay.turnSeconds
        XCTAssertGreaterThan(speed, 0.5, "points a second: slow, but the marks are seen to go")
        XCTAssertLessThan(speed / TimerDisplay.framesPerSecond, 0.25, "points a frame: a fraction of a pixel on a Retina screen")
        XCTAssertEqual(TimerDisplay.angle(elapsed: 10, reducesMotion: false), 60, accuracy: 1e-9)
        XCTAssertEqual(TimerDisplay.angle(elapsed: 61, reducesMotion: false), 6, accuracy: 1e-9, "a full turn, and round again")
        XCTAssertEqual(TimerDisplay.angle(elapsed: 10, reducesMotion: true), 0, "no turning with reduced motion")
    }

    // MARK: The upper half as a whole

    /// The tomato at a position of the dial as a grid of opacities, `ppu` pixels to a box unit.
    private struct Raster {
        let ppu: CGFloat = 4, origin: CGFloat = 20, side = 560
        var data: [UInt8] = []

        /// The opacity (0...255) of the pixel that holds the box point (`x`, `y`).
        func alpha(_ x: CGFloat, _ y: CGFloat) -> Int {
            Int(data[Int((y + origin) * ppu) * side + Int((x + origin) * ppu)])
        }

        /// How many pixels of the box rectangle differ by more than half from `other`'s.
        func differences(from other: Raster, x: ClosedRange<CGFloat>, y: ClosedRange<CGFloat>) -> Int {
            var count = 0
            for row in Int((y.lowerBound + origin) * ppu)...Int((y.upperBound + origin) * ppu) {
                for column in Int((x.lowerBound + origin) * ppu)...Int((x.upperBound + origin) * ppu)
                where abs(Int(data[row * side + column]) - Int(other.data[row * side + column])) > 127 { count += 1 }
            }
            return count
        }
    }

    private func raster(dial: Double, line: CGFloat = Glyph.menuLine, gap: CGFloat = Glyph.menuGap) throws -> Raster {
        var result = Raster()
        let ctx = try XCTUnwrap(CGContext(data: nil, width: result.side, height: result.side, bitsPerComponent: 8, bytesPerRow: 0,
                                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.translateBy(x: 0, y: CGFloat(result.side))
        ctx.scaleBy(x: result.ppu, y: -result.ppu)
        ctx.translateBy(x: result.origin, y: result.origin)
        ctx.setFillColor(.black)
        ctx.setStrokeColor(.black)
        Glyph.prepare(ctx)
        Tomato.draw(ctx, line: line, gap: gap, dial: dial)
        let data = try XCTUnwrap(ctx.data).assumingMemoryBound(to: UInt8.self)
        for y in 0..<result.side { for x in 0..<result.side { result.data.append(data[y * ctx.bytesPerRow + x * 4 + 3]) } }
        return result
    }

    /// Not only the marks crawl: the whole upper half turns, the calyx with them, and what does not belong to it stands: the
    /// lower half with its pointer, and the stem, which is on the axis the half turns about.
    func testTheCalyxTurnsWithTheMarksAndTheStemAndTheLowerHalfStandStill() throws {
        let rest = try raster(dial: 0), turned = try raster(dial: 0.03)   // 10.8 degrees
        let lower = rest.differences(from: turned, x: 0...100, y: (Tomato.slit + 4)...100)
        XCTAssertEqual(lower, 0, "the lower half stands still")
        XCTAssertEqual(Tomato.stemTop.x, Tomato.center.x, "the stem stands on the axis")
        XCTAssertEqual(rest.differences(from: turned, x: 46.5...53.5, y: 8...19), 0, "so it does not move when the half turns")
        // The calyx, left and right of the stem: well over a hundred pixels (a sixth of a unit square each) change.
        let calyx = rest.differences(from: turned, x: 10...43, y: 24...52) + rest.differences(from: turned, x: 57...90, y: 24...52)
        XCTAssertGreaterThan(calyx, 400, "the sepals move")
        XCTAssertGreaterThan(rest.differences(from: turned, x: 0...100, y: 54...63), 50, "and the marks")
    }

    /// The sepals are alike and evenly spaced, so the calyx at a turn of one sepal's share is the calyx at rest; the marks,
    /// twelve of them, are as alike, and the two come round together after half a turn (ten sepals and twelve marks: the
    /// least common multiple of 36 and 30 degrees is 180).
    func testTheCalyxRepeatsAfterTheShareOfOneSepalAndTheWholePictureAfterHalfATurn() throws {
        let rest = try raster(dial: 0)
        let share = try raster(dial: 1 / Double(Tomato.sepals))
        XCTAssertEqual(rest.differences(from: share, x: 0...100, y: 8...52), 0, "the calyx: the same sepals in the same places")
        XCTAssertGreaterThan(rest.differences(from: try raster(dial: 0.5 / Double(Tomato.sepals)), x: 0...100, y: 24...52), 100,
                             "half a share is another picture")
        XCTAssertEqual(rest.differences(from: try raster(dial: 0.5), x: 0...100, y: 0...100), 0, "half a turn: all of it")
        XCTAssertGreaterThan(rest.differences(from: try raster(dial: 0.25), x: 0...100, y: 0...100), 100, "a quarter is not")
    }

    /// The sepals go to the right as the dial grows, as the marks do: the tip of the one that points at us, the lowest point
    /// of the gap round the calyx, is on the axis at rest and moves to the right with the dial, to the left when it has
    /// turned almost all the way round.
    func testTheSepalsGoToTheRight() throws {
        func tip(dial: Double) throws -> Double {
            let r = try raster(dial: dial)
            for y in stride(from: 53.0, to: 36.0, by: -0.25) {
                let xs = stride(from: 38.0, to: 62.0, by: 0.25).filter { r.alpha(CGFloat($0), CGFloat(y)) < 128 }
                if !xs.isEmpty { return xs.map { $0 + 0.125 }.reduce(0, +) / Double(xs.count) }
            }
            return -1
        }
        XCTAssertEqual(try tip(dial: 0), 50, accuracy: 0.3, "at rest the sepal stands on the axis")
        XCTAssertGreaterThan(try tip(dial: 0.01), 51, "3.6 degrees on, it has gone to the right")
        XCTAssertLessThan(try tip(dial: 0.99), 49, "and 3.6 degrees short of a turn, to the left")
    }

    /// A sepal that comes to the side is seen from its edge and gets narrow, as the marks do, and one that has turned away
    /// is gone behind the fruit; the sepal that points at us is whole and stands on the axis.
    func testASepalNarrowsTowardTheEdgeAndIsGoneBehindTheFruit() {
        func area(_ polygon: [CGPoint]) -> CGFloat {
            var sum: CGFloat = 0
            for (i, a) in polygon.enumerated() { let b = polygon[(i + 1) % polygon.count]; sum += a.x * b.y - b.x * a.y }
            return abs(sum) / 2
        }
        func degrees(_ d: Double) -> [CGPoint] { Tomato.sepalOutline(azimuth: d * .pi / 180, margin: 0) }
        let front = degrees(0)
        XCTAssertFalse(front.isEmpty)
        XCTAssertEqual((front.map(\.x).min() ?? 0) + (front.map(\.x).max() ?? 0), 100, accuracy: 0.01, "symmetric about the axis")
        let areas = [0.0, 30, 60, 80, 89].map { area(degrees($0)) }
        XCTAssertEqual(areas, areas.sorted(by: >), "narrower and narrower")
        XCTAssertLessThan(areas[4], areas[0] * 0.05, "a sliver at the edge, so that it goes without a jump")
        for behind in [90.0, 120, 180, 270, -90] { XCTAssertTrue(degrees(behind).isEmpty, "\(behind) degrees: behind the fruit") }
        XCTAssertGreaterThan(degrees(30).map(\.x).max() ?? 0, front.map(\.x).max() ?? 0, "and the sepals go to the right")
    }

    func testTheIconInkIsInsideTheBounds() throws {
        // The icon's lines are thinner: its ink is inside the bounds and takes nearly all of them.
        let icon = try ink { Tomato.draw($0, line: Glyph.iconLine, gap: Glyph.iconGap) }
        XCTAssertTrue(Tomato.bounds.insetBy(dx: -0.3, dy: -0.3).contains(icon))
        XCTAssertGreaterThan(icon.height, Tomato.bounds.height - 1.5)
        XCTAssertGreaterThan(icon.width, Tomato.bounds.width - 0.5)
    }

    func testTheCanvasIs22PointsTallAndTheMarkIs16() throws {
        XCTAssertEqual(MenuBarIcon.canvas.height, 22)
        XCTAssertEqual(MenuBarIcon.canvas.width, Glyph.menuCanvas(for: Tomato.bounds).width)
        XCTAssertEqual(Glyph.menuScale(for: Tomato.bounds) * Tomato.bounds.height, 16, accuracy: 0.001, "as tall as the system's own icons")
        let running = MenuBarIcon.TimerFace(dial: 0.4, time: .init(text: "24:13", sample: "00:00"))
        var hidden = running
        hidden.style = .tomatoOnly
        var alone = running
        alone.style = .timerOnly
        let paused = MenuBarIcon.TimerFace(dial: 0.2, time: .init(text: "12:00", sample: "00:00", outlined: true))
        let pictures: [(String, NSImage, Bool)] = [
            ("rest", icon(), false), ("rest with the dot", icon(badge: true), true),
            ("running", icon(face: running), false), ("running with the dot", icon(badge: true, face: running), true),
            ("paused", icon(face: paused), false), ("without the time", icon(face: hidden), false),
            ("the time alone", icon(face: alone), false)]
        for (name, image, badge) in pictures {
            let width = Int(image.size.width * 4), height = Int(image.size.height * 4)
            let rep = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                                                     samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                                     bytesPerRow: 0, bitsPerPixel: 0))
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            image.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
            NSGraphicsContext.restoreGraphicsState()
            var rows = (min: height, max: -1), columns = (min: width, max: -1)
            for y in 0..<height {
                for x in 0..<width where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.05 {
                    rows = (min(rows.min, y), max(rows.max, y)); columns = (min(columns.min, x), max(columns.max, x))
                }
            }
            // 3 pt (12 px) of room above and below, the tomato being centred, and the margin at the sides: nothing reaches an
            // edge of the canvas. The dot of an update goes up to 0.5 pt from the top and the right edge.
            XCTAssertGreaterThanOrEqual(rows.min, badge ? 0 : 11, name)
            XCTAssertGreaterThanOrEqual(columns.min, 3, name)
            XCTAssertLessThanOrEqual(columns.max, width - (badge ? 1 : 4), name)
            XCTAssertLessThanOrEqual(rows.max, height - 12, name)
            if !badge {
                XCTAssertEqual(CGFloat(rows.max - rows.min + 1) / 4, 16, accuracy: 0.6, "the tomato and its capsule are 16 pt tall: \(name)")
            }
        }
    }

    func testTheMarkTakesEightyPercentOfTheTileAndStaysClearOfItsCorners() {
        for bounds in [Tomato.bounds] {
            let long = max(bounds.width, bounds.height)
            XCTAssertEqual(Glyph.iconScale(for: bounds) * long, 0.8 * 824, accuracy: 0.001)
            // The corners of the ink's rectangle lie well inside the tile's rounded corners (the squircle of exponent 5).
            let half = 824 / 2 as CGFloat
            let w = Glyph.iconScale(for: bounds) * bounds.width / 2, h = Glyph.iconScale(for: bounds) * bounds.height / 2
            XCTAssertLessThan(pow(w / half, 5) + pow(h / half, 5), 0.7)
        }
    }
}
