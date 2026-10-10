import AppKit

/// The menu bar icon: the app's glyph as a template image, so macOS tints it for the menu bar and its selection. The
/// canvas is 22 pt high, as much as the 24 pt menu bar leaves, with the tomato 16 pt tall in the middle, as tall as the system's own icons, and as wide as the
/// tomato's proportions ask (Glyph.swift); the status item is `variableLength`, as wide as the image plus the menu bar's own
/// margins. The glyph itself is the app's: `drawGlyphBase` and `drawGlyphTop` in AppParts.swift. While a timer runs the image
/// is wider by the capsule with the time beside the tomato, or, when Settings ask for the time alone, as wide as the capsule
/// that takes the tomato's place (MenuBarCapsule.swift). It changes its width in one step, when the timer starts and when
/// the capsule has gone: a status item cannot widen smoothly, since macOS lays out the menu bar anew for every width, out
/// of step with the picture. So the capsule comes in and goes inside the image's final width (`composition`).
enum MenuBarIcon {
    static let canvas = NSSize(width: Glyph.menuCanvas(for: Tomato.bounds).width, height: Glyph.menuCanvasHeight)
    /// The glyph's ink in the canvas.
    static let box = CGRect(x: (canvas.width - Tomato.bounds.width * Glyph.menuScale(for: Tomato.bounds)) / 2,
                            y: (Glyph.menuCanvasHeight - Glyph.menuMarkHeight) / 2,
                            width: Tomato.bounds.width * Glyph.menuScale(for: Tomato.bounds), height: Glyph.menuMarkHeight)
    /// The thickest line of the glyph in points: Glyph.menuLine in box units, grown with the glyph. The capsule's outline
    /// has the same line.
    static let lineWidth = Glyph.menuLine * Glyph.menuScale(for: Tomato.bounds)
    /// The clear space between the tomato's ink and the capsule beside it: about 4 pt, as between the system's neighbouring
    /// icons.
    static let gapToTomato = canvas.width + Tomato.capsuleGap - box.maxX
    /// The dot of a new version waiting for the user, in the top right corner, and the gap round it.
    static let badge = CGRect(x: canvas.width - 6.5, y: 0.5, width: 6, height: 6)
    static let badgeGap: CGFloat = 1.6

    /// The pixels per point the pictures are made in ahead of time: a standard screen and a Retina one.
    static let scales: [CGFloat] = [1, 2]

    /// The icon; `badge` adds the dot of an update the user has not answered yet. `face` is the timer while it runs, waits
    /// or has just run out: the tomato with its upper half turned and, as Settings choose, the time in a capsule beside it or
    /// instead of it. Without it the tomato stands still. `presence` is how far the capsule has come in (0 to 1, see
    /// `composition`): the status item animates it when a timer starts and stops. The tomato turns about fifteen times a
    /// second, so the image is made from pictures kept for the purpose, with only the upper half drawn anew (`IconFrames`), as a
    /// bitmap for each of `scales`.
    @MainActor
    static func image(badge: Bool = false, face: TimerFace? = nil, presence: Double = 1,
                      scales: [CGFloat] = MenuBarIcon.scales) -> NSImage {
        IconFrames.shared.image(badge: badge, face: face, presence: presence, scales: scales)
    }
}
