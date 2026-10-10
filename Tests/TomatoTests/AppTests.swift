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

    private func face(_ text: String, dial: Double = 0.4, outlined: Bool = false, showsTime: Bool = true) -> MenuBarIcon.TimerFace {
        .init(dial: dial, time: .init(text: text, sample: "00:00", outlined: outlined), showsTime: showsTime)
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
        let hidden = icon(face: face("24:13", showsTime: false))
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
        let shifted = icon(face: face("24:13", dial: 1.0 / 24, showsTime: false))
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

    /// The opacity of every pixel of the image's picture, row by row.
    private func alphas(_ image: NSImage) throws -> [UInt8] {
        let rep = try XCTUnwrap(image.representations.first as? NSBitmapImageRep)
        let data = try XCTUnwrap(rep.bitmapData)
        var bytes: [UInt8] = []
        for y in 0..<rep.pixelsHigh { for x in 0..<rep.pixelsWide { bytes.append(data[y * rep.bytesPerRow + x * 4 + 3]) } }
        return bytes
    }

    /// The icon drawn straight into one bitmap, nothing kept: the tomato in one go, the capsule, the dot of an update.
    private func drawnAnew(badge: Bool, face: MenuBarIcon.TimerFace?, scale: CGFloat) throws -> [UInt8] {
        let layout = MenuBarIcon.capsuleLayout(face?.capsule)
        let size = layout?.size ?? MenuBarIcon.canvas
        let width = Int(size.width * scale), height = Int(size.height * scale)
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
        ctx.saveGState()
        Glyph.enterMenuBox(ctx, bounds: Tomato.bounds, scale: scale)
        Tomato.draw(ctx, line: Glyph.menuLine, gap: Glyph.menuGap, dial: face?.dial ?? 0)
        ctx.restoreGState()
        if let capsule = face?.capsule, let layout { MenuBarIcon.drawCapsule(capsule, rect: layout.rect, in: ctx) }
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

    /// The kept pictures and the marks cut into them are the picture that drawing everything anew gives, at every position of
    /// the dial, with the capsule as a plate or an outline, and with the dot.
    func testTheFramesAreThePictureOfDrawingEverythingAnew() throws {
        let frames = IconFrames()
        let cases: [(String, MenuBarIcon.TimerFace?, Bool)] = [
            ("rest", nil, false), ("rest with the dot", nil, true),
            ("running", face("24:13", dial: 0.37), false), ("running, dial 0", face("24:13", dial: 0), false),
            ("running, dial 0.99", face("08:08", dial: 0.99), false), ("running with the dot", face("24:13", dial: 0.5), true),
            ("paused", face("12:00", dial: 0.2, outlined: true), false), ("without the time", face("24:13", dial: 0.7, showsTime: false), false)]
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

    /// A frame draws only the marks: the tomato is drawn once for each scale, the capsule once for each time.
    func testAFrameDrawsOnlyTheMarksAnew() {
        let frames = IconFrames()
        for step in 0..<60 {
            _ = frames.image(badge: false, face: face("24:13", dial: Double(step) / 1200), scales: [2])
        }
        XCTAssertEqual(frames.tomatoDrawings, 1, "the tomato without its marks is drawn once")
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
        _ = frames.image(badge: false, face: face("24:12", dial: 0.5, outlined: true), scales: [1, 2])
        XCTAssertEqual(frames.tomatoDrawings, 2, "a scale of its own")
    }

    /// The turn looks smooth because a frame moves the marks by a fraction of a pixel: no pixel changes by more than half
    /// its ink from one frame to the next, at the pace the tomato really turns.
    func testNoPixelJumpsFromOneFrameToTheNext() throws {
        let frames = IconFrames()
        let step = 1 / (TimerDisplay.framesPerSecond * TimerDisplay.turnSeconds)
        var previous: [UInt8]?
        var worst = 0
        for i in 0..<Int(1 / step / 6) {   // a sixth of a turn: two marks go by
            let now = try alphas(frames.image(badge: false, face: face("24:13", dial: Double(i) * step, showsTime: false), scales: [2]))
            if let previous { worst = max(worst, zip(now, previous).map { abs(Int($0) - Int($1)) }.max() ?? 0) }
            previous = now
        }
        XCTAssertGreaterThan(worst, 0, "the marks do move")
        XCTAssertLessThan(worst, 128, "and never by more than half a pixel's ink in a frame")
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
