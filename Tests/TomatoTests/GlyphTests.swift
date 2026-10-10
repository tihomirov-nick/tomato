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

    /// The marks cross the middle of the belt at the speed of its rim. Slower than about two points a second, the eye takes a
    /// turn for standing still (a turn a minute is 0.9 pt/s); and a frame must move the marks by well under a pixel.
    func testTheMarksMoveFastEnoughToSeeAndInStepsTooSmallToSee() {
        let rim = 2 * Double.pi * Double(Tomato.beltRadius * Glyph.menuScale(for: Tomato.bounds))
        let speed = rim / TimerDisplay.turnSeconds
        XCTAssertGreaterThan(speed, 2, "points a second")
        XCTAssertLessThan(speed / TimerDisplay.framesPerSecond, 0.25, "points a frame: a fraction of a pixel on a Retina screen")
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
        hidden.showsTime = false
        let paused = MenuBarIcon.TimerFace(dial: 0.2, time: .init(text: "12:00", sample: "00:00", outlined: true))
        let pictures: [(String, NSImage, Bool)] = [
            ("rest", icon(), false), ("rest with the dot", icon(badge: true), true),
            ("running", icon(face: running), false), ("running with the dot", icon(badge: true, face: running), true),
            ("paused", icon(face: paused), false), ("without the time", icon(face: hidden), false)]
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
