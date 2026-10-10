import AppKit

/// The frames of the menu bar icon, made cheaply. While a timer runs the tomato turns about fifteen times a second, and
/// drawing everything anew for each frame (the calyx alone is a union of six paths, the digits are laid out by CoreText)
/// would be most of what the app does. So what stays the same from one frame to the next is drawn once and kept as a
/// bitmap for each scale: the tomato without its marks, and the capsule with the time in it, which changes once a second.
/// A frame copies the two pictures and cuts the marks into the tomato, a handful of thin strips, nothing else.
@MainActor
final class IconFrames {
    static let shared = IconFrames()

    typealias Layout = (rect: CGRect, size: NSSize)

    /// How many times the tomato and the capsule have been drawn from scratch. The tests count them to see that a frame
    /// does not do it.
    private(set) var tomatoDrawings = 0
    private(set) var capsuleDrawings = 0

    private let space = CGColorSpaceCreateDeviceRGB()
    /// The pictures kept, by scale: the tomato without the marks, and the capsule last drawn.
    private var tomatoes: [CGFloat: CGImage] = [:]
    private var capsules: [CGFloat: (capsule: MenuBarIcon.TimeCapsule, image: CGImage)] = [:]
    /// Where the capsule stands, by the widest text of its format (the capsule's width follows it, not the digits).
    private var layouts: [String: Layout] = [:]

    /// The icon as an image with a picture for each of `scales` (pixels per point), a template for the menu bar.
    func image(badge: Bool, face: MenuBarIcon.TimerFace?, scales: [CGFloat]) -> NSImage {
        let layout = layout(of: face?.capsule)
        let size = layout?.size ?? MenuBarIcon.canvas
        let image = NSImage(size: size)
        for scale in scales {
            guard let frame = frame(face, badge: badge, layout: layout, size: size, scale: scale) else { continue }
            let rep = NSBitmapImageRep(cgImage: frame)
            rep.size = size
            image.addRepresentation(rep)
        }
        image.isTemplate = true
        image.accessibilityDescription = face?.time.text ?? "Tomato"
        return image
    }

    // MARK: A frame

    private func frame(_ face: MenuBarIcon.TimerFace?, badge: Bool, layout: Layout?, size: NSSize, scale: CGFloat) -> CGImage? {
        let width = pixels(size.width, scale), height = pixels(size.height, scale)
        guard let ctx = context(width: width, height: height), let tomato = tomato(scale: scale) else { return nil }
        // The pictures kept are copied pixel for pixel, in device space, where y goes up.
        ctx.interpolationQuality = .none
        let top = CGFloat(height)
        ctx.draw(tomato, in: CGRect(x: 0, y: top - CGFloat(tomato.height), width: CGFloat(tomato.width), height: CGFloat(tomato.height)))
        if let capsule = face?.capsule, let layout, let layer = capsuleLayer(capsule, rect: layout.rect, scale: scale) {
            ctx.draw(layer, in: CGRect(x: layout.rect.minX * scale, y: top - layout.rect.maxY * scale,
                                       width: CGFloat(layer.width), height: CGFloat(layer.height)))
        }
        // The rest in points with y down, as in a flipped image: the marks over the tomato, then the dot of an update.
        pointsFromTop(ctx, height: height, scale: scale)
        MenuBarIcon.drawGlyphDial(in: ctx, scale: scale, dial: face?.dial ?? 0)
        if badge {
            // The dot sits in the top right corner of the whole image, with a gap round it so it stays apart from what is
            // under it.
            let dot = MenuBarIcon.badge.offsetBy(dx: size.width - MenuBarIcon.canvas.width, dy: 0)
            ctx.setBlendMode(.clear)
            ctx.fillEllipse(in: dot.insetBy(dx: -MenuBarIcon.badgeGap, dy: -MenuBarIcon.badgeGap))
            ctx.setBlendMode(.normal)
            ctx.fillEllipse(in: dot)
        }
        return ctx.makeImage()
    }

    // MARK: The pictures kept

    /// The tomato without its marks on its canvas, drawn once for a scale.
    private func tomato(scale: CGFloat) -> CGImage? {
        if let kept = tomatoes[scale] { return kept }
        let size = MenuBarIcon.canvas
        let height = pixels(size.height, scale)
        guard let ctx = context(width: pixels(size.width, scale), height: height) else { return nil }
        pointsFromTop(ctx, height: height, scale: scale)
        MenuBarIcon.drawGlyphBase(in: ctx, scale: scale)
        tomatoDrawings += 1
        tomatoes[scale] = ctx.makeImage()
        return tomatoes[scale]
    }

    /// The capsule with its time, drawn once for a time and a scale. It covers exactly `rect`, a whole number of pixels, so
    /// copying it into a frame gives what drawing it there would.
    private func capsuleLayer(_ capsule: MenuBarIcon.TimeCapsule, rect: CGRect, scale: CGFloat) -> CGImage? {
        if let kept = capsules[scale], kept.capsule == capsule { return kept.image }
        let height = pixels(rect.height, scale)
        guard let ctx = context(width: pixels(rect.width, scale), height: height) else { return nil }
        pointsFromTop(ctx, height: height, scale: scale)
        ctx.translateBy(x: -rect.minX, y: -rect.minY)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        MenuBarIcon.drawCapsule(capsule, rect: rect, in: ctx)
        capsuleDrawings += 1
        guard let image = ctx.makeImage() else { return nil }
        capsules[scale] = (capsule, image)
        return image
    }

    private func layout(of capsule: MenuBarIcon.TimeCapsule?) -> Layout? {
        guard let capsule else { return nil }
        if let kept = layouts[capsule.sample] { return kept }
        let made = MenuBarIcon.capsuleLayout(capsule)
        layouts[capsule.sample] = made
        return made
    }

    // MARK: Bitmaps

    private func pixels(_ points: CGFloat, _ scale: CGFloat) -> Int { Int((points * scale).rounded()) }

    private func context(width: Int, height: Int) -> CGContext? {
        CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    }

    /// Counts in points from the top left corner, y down, drawing in black.
    private func pointsFromTop(_ ctx: CGContext, height: Int, scale: CGFloat) {
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: scale, y: -scale)
        ctx.setFillColor(.black)
        ctx.setStrokeColor(.black)
    }
}
