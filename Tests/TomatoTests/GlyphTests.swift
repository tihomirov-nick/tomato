import AppKit
import XCTest
import TomatoCore
@testable import Tomato

/// How the tomato fills its room, the 22 pt menu bar canvas and the tile of the app icon, and how its dial turns. The room
/// comes from the mark's bounds, the rectangle its ink covers in the glyph's box, so that rectangle must be what the drawing
/// really covers, at every turn of the dial.
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
        for dial in [0.0, 1.0 / 48, 1.0 / 24, 0.07, 0.25, 0.4, 0.5, 0.77, 0.99] {
            assertSame(try ink { Tomato.draw($0, line: Glyph.menuLine, gap: Glyph.menuGap, dial: dial) }, Tomato.bounds,
                       "bounds of the tomato in Tomato.swift are out of date (dial \(dial))")
        }
    }

    /// A minute for a turn: six degrees a second. That is slow (the marks cross the middle of the belt at about 0.7 pt a
    /// second), and a frame moves them by a small fraction of a pixel.
    func testTheDialTurnsSixDegreesASecondInStepsTooSmallToSee() {
        XCTAssertEqual(TimerDisplay.turnSeconds, 60)
        XCTAssertEqual(TimerDisplay.degreesPerSecond, 6)
        XCTAssertEqual(TimerDisplay.framesPerSecond, 15)
        let rim = 2 * Double.pi * Double(Tomato.beltRadius * Glyph.menuScale(for: Tomato.bounds))
        let speed = rim / TimerDisplay.turnSeconds
        XCTAssertGreaterThan(speed, 0.5, "points a second: slow, but the marks are seen to go")
        XCTAssertLessThan(speed / TimerDisplay.framesPerSecond, 0.25, "points a frame: a fraction of a pixel on a Retina screen")
        XCTAssertEqual(TimerDisplay.angle(elapsed: 10, reducesMotion: false), 60, accuracy: 1e-9)
        XCTAssertEqual(TimerDisplay.angle(elapsed: 61, reducesMotion: false), 6, accuracy: 1e-9, "a full turn, and round again")
        XCTAssertEqual(TimerDisplay.angle(elapsed: 10, reducesMotion: true), 0, "no turning with reduced motion")
    }

    // MARK: The dial in pictures

    /// The tomato at a position of the dial as a grid of opacities, `ppu` pixels to a box unit.
    private struct Raster {
        let ppu: CGFloat = 4, origin: CGFloat = 20, side = 560
        var data: [UInt8] = []

        /// The opacity (0...255) of the pixel that holds the box point (`x`, `y`).
        func alpha(_ x: CGFloat, _ y: CGFloat) -> Int {
            Int(data[Int((y + origin) * ppu) * side + Int((x + origin) * ppu)])
        }

        /// The rows of pixels that lie wholly within the box's `y` range.
        func rows(_ y: ClosedRange<CGFloat>) -> ClosedRange<Int> {
            Int(((y.lowerBound + origin) * ppu).rounded(.up))...(Int(((y.upperBound + origin) * ppu).rounded(.down)) - 1)
        }

        /// How many pixels of those rows differ from `other`'s by more than `by`.
        func differences(from other: Raster, y: ClosedRange<CGFloat>, by: Int = 1) -> Int {
            var count = 0
            for row in rows(y) {
                for column in 0..<side where abs(Int(data[row * side + column]) - Int(other.data[row * side + column])) > by {
                    count += 1
                }
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

    /// Only the marks move. Everything over the middle of the slit, the upper half with the calyx, the stem and the pointer,
    /// is the same picture at every position of the dial, pixel for pixel, and so is the lower half under the marks.
    func testOnlyTheMarksMoveTheUpperHalfIsTheSameInEveryFrame() throws {
        let rest = try raster(dial: 0)
        let gap = Glyph.menuGap
        let underMarks = Tomato.slit + gap / 2 + Tomato.markHeight
        var moved = 0
        for dial in [0.01, 1.0 / 24, 0.2, 0.37, 0.5, 0.83, 0.999] {
            let turned = try raster(dial: dial)
            XCTAssertEqual(turned.differences(from: rest, y: -20...Tomato.slit, by: 0), 0, "dial \(dial): the upper half stands still")
            XCTAssertEqual(turned.differences(from: rest, y: underMarks...118, by: 0), 0, "dial \(dial): so does the lower half under the marks")
            moved += turned.differences(from: rest, y: Tomato.slit...underMarks, by: 127)
        }
        XCTAssertGreaterThan(moved, 100, "while the marks do move")
    }

    /// The marks are twelve and alike, so the picture is the same again after a twelfth of a turn, thirty degrees, five
    /// seconds; and round the full turn, where the dial goes back from 1 to 0, there is no seam either. Half a twelfth on,
    /// it is another picture.
    func testThePictureComesRoundAfterATwelfthOfATurnWithoutASeam() throws {
        XCTAssertEqual(Tomato.marks, 12)
        XCTAssertEqual(TimerDisplay.flashDial(true), 0.5 / Double(Tomato.marks), "the flash shakes the marks by half a step")
        for dial in [0.0, 0.013, 0.3, 0.9] {
            let picture = try raster(dial: dial)
            XCTAssertEqual(picture.differences(from: try raster(dial: dial + 1 / 12), y: -20...118), 0, "\(dial) and a twelfth on")
            XCTAssertGreaterThan(picture.differences(from: try raster(dial: dial + 1 / 24), y: -20...118, by: 127), 50,
                                 "\(dial) and half a twelfth on")
        }
        // The last frames of a turn and the first of the next one: the dial of a timer that has run for 59.9 s and 60.1 s.
        let before = TimerDisplay.dial(elapsed: 59.9, reducesMotion: false), after = TimerDisplay.dial(elapsed: 60.1, reducesMotion: false)
        XCTAssertGreaterThan(before, 0.99)
        XCTAssertLessThan(after, 0.01)
        XCTAssertEqual(try raster(dial: before + 1.0 / 600).differences(from: try raster(dial: after - 1.0 / 600), y: -20...118), 0)
    }

    /// The marks hang down from the slit into the lower half, each as wide as the slit where it faces us and narrower towards
    /// the edge, none on the far side. At rest one stands right under the pointer; as the dial grows they go to the right.
    func testTheMarksHangFromTheSlitAndGoToTheRight() {
        let gap = Glyph.menuGap
        let rest = Tomato.markStrips(dial: 0, gap: gap)
        XCTAssertEqual(rest.count, 5, "five of the twelve face us: at 0, 30 and 60 degrees either side")
        for strip in rest {
            XCTAssertGreaterThan(strip.minY, Tomato.slit, "it begins in the slit's lower half")
            XCTAssertLessThan(strip.minY, Tomato.slit + gap / 2, "and opens into the slit")
            XCTAssertEqual(strip.maxY, Tomato.slit + gap / 2 + Tomato.markHeight, accuracy: 1e-9, "it hangs down from it")
            XCTAssertTrue(Tomato.body().contains(CGPoint(x: strip.midX, y: strip.maxY)), "inside the fruit")
        }
        let front = rest.min { abs($0.midX - 50) < abs($1.midX - 50) }
        XCTAssertEqual(front?.midX ?? 0, 50, accuracy: 1e-9, "a mark under the pointer")
        XCTAssertEqual(front?.width ?? 0, gap, accuracy: 1e-9, "as wide as the slit")
        let widths = rest.sorted { abs($0.midX - 50) < abs($1.midX - 50) }.map(\.width)
        XCTAssertEqual(widths, widths.sorted(by: >), "narrower towards the edges")
        let moved = Tomato.markStrips(dial: 0.01, gap: gap).min { abs($0.midX - 50) < abs($1.midX - 50) }
        XCTAssertGreaterThan(moved?.midX ?? 0, 51, "3.6 degrees on, it has gone to the right")
    }

    /// The pointer is a notch in the upper half, its tip in the slit and pointing down at the marks, its base clear of the
    /// calyx: between the gap round the calyx and the pointer there is solid fruit, so the two do not run together.
    func testThePointerPointsDownAtTheMarksClearOfTheCalyx() throws {
        for (line, gap) in [(Glyph.menuLine, Glyph.menuGap), (Glyph.iconLine, Glyph.iconGap)] {
            let pointer = Tomato.pointer(gap: gap).boundingBoxOfPath
            XCTAssertEqual(pointer.midX, 50, accuracy: 1e-9, "in the middle")
            XCTAssertGreaterThan(pointer.maxY, Tomato.slit - gap / 2, "its tip in the slit")
            XCTAssertLessThan(pointer.maxY, Tomato.slit)
            XCTAssertEqual(pointer.height, Tomato.pointerHeight + 0.5, accuracy: 1e-9)
            XCTAssertEqual(pointer.width, Tomato.pointerWidth, accuracy: 1e-9)
            XCTAssertTrue(Tomato.pointer(gap: gap).contains(CGPoint(x: 50, y: pointer.maxY - 1)), "the tip is at the bottom")
            XCTAssertFalse(Tomato.pointer(gap: gap).contains(CGPoint(x: 50 + Tomato.pointerWidth / 2 - 0.5, y: pointer.maxY - 1)))
            let calyx = Tomato.calyx().boundingBoxOfPath
            XCTAssertGreaterThanOrEqual(pointer.minY - (calyx.maxY + gap), 4, "clear of the gap round the calyx")
            let picture = try raster(dial: 0, line: line, gap: gap)
            for y in stride(from: calyx.maxY + gap + 1, through: pointer.minY - 1, by: 0.25) {
                XCTAssertEqual(picture.alpha(50, y), 255, "solid fruit at \(y) between the calyx and the pointer")
            }
            XCTAssertEqual(picture.alpha(50, pointer.minY + 2), 0, "the pointer is cut out")
            XCTAssertEqual(picture.alpha(50, Tomato.slit), 0, "and so is the slit")
        }
    }

    func testTheIconInkIsInsideTheBounds() throws {
        // The icon's lines are thinner: its ink is inside the bounds and takes nearly all of them.
        let icon = try ink { Tomato.draw($0, line: Glyph.iconLine, gap: Glyph.iconGap) }
        XCTAssertTrue(Tomato.bounds.insetBy(dx: -0.3, dy: -0.3).contains(icon))
        XCTAssertGreaterThan(icon.height, Tomato.bounds.height - 1.5)
        XCTAssertGreaterThan(icon.width, Tomato.bounds.width - 0.5)
    }

    /// The family's size: the tomato 16 pt tall and no wider than 20 pt, on a canvas 22 pt tall.
    func testTheCanvasIs22PointsTallAndTheMarkIs16() throws {
        XCTAssertEqual(MenuBarIcon.canvas.height, 22)
        XCTAssertEqual(MenuBarIcon.canvas.width, Glyph.menuCanvas(for: Tomato.bounds).width)
        XCTAssertEqual(Glyph.menuScale(for: Tomato.bounds) * Tomato.bounds.height, 16, accuracy: 0.001, "as tall as the system's own icons")
        XCTAssertLessThanOrEqual(Glyph.menuScale(for: Tomato.bounds) * Tomato.bounds.width, 20)
        XCTAssertLessThanOrEqual(MenuBarIcon.canvas.width, 20)
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
