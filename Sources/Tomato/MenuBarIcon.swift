import AppKit

/// The menu bar icon: the app's glyph as a template image, so macOS tints it for the menu bar and its selection. The
/// canvas is 22 pt high, as much as the 24 pt menu bar leaves, with the tomato 16 pt tall in the middle, as tall as the system's own icons, and as wide as the
/// tomato's proportions ask (Glyph.swift); the status item is `variableLength`, as wide as the image plus the menu bar's own
/// margins. The glyph itself is the app's: `drawGlyphBase` and `drawGlyphDial` in AppParts.swift. While a timer runs the image
/// grows to the right by the capsule with the time (MenuBarCapsule.swift).
enum MenuBarIcon {
    static let canvas = NSSize(width: Glyph.menuCanvas(for: Tomato.bounds).width, height: Glyph.menuCanvasHeight)
    /// The glyph's ink in the canvas.
    static let box = CGRect(x: (canvas.width - Tomato.bounds.width * Glyph.menuScale(for: Tomato.bounds)) / 2,
                            y: (Glyph.menuCanvasHeight - Glyph.menuMarkHeight) / 2,
                            width: Tomato.bounds.width * Glyph.menuScale(for: Tomato.bounds), height: Glyph.menuMarkHeight)
    /// The thickest line of the glyph in points: Glyph.menuLine in box units, grown with the glyph. The capsule's outline
    /// has the same line.
    static let lineWidth = Glyph.menuLine * Glyph.menuScale(for: Tomato.bounds)
    /// The dot of a new version waiting for the user, in the top right corner, and the gap round it.
    static let badge = CGRect(x: canvas.width - 6.5, y: 0.5, width: 6, height: 6)
    static let badgeGap: CGFloat = 1.6

    /// The pixels per point the pictures are made in ahead of time: a standard screen and a Retina one.
    static let scales: [CGFloat] = [1, 2]

    /// The icon; `badge` adds the dot of an update the user has not answered yet. `face` is the timer while it runs, waits
    /// or has just run out: the tomato with its dial turned and, unless Settings hide it, the time in a capsule beside it.
    /// Without it the tomato stands still. The tomato turns about fifteen times a second, so the image is made from pictures
    /// kept for the purpose, with only the marks drawn anew (`IconFrames`), as a bitmap for each of `scales`.
    @MainActor
    static func image(badge: Bool = false, face: TimerFace? = nil, scales: [CGFloat] = MenuBarIcon.scales) -> NSImage {
        IconFrames.shared.image(badge: badge, face: face, scales: scales)
    }
}
