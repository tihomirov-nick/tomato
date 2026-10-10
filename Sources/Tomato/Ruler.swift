import AppKit
import SwiftUI
import TomatoCore

/// The length of the timer as a ruler: a tick for every minute from 1 to 60, a taller one every five and the tallest
/// every ten with its number, and a mark where the length is. The ticks up to the mark are bright. A drag with the mouse
/// puts the mark under the pointer, the wheel and a swipe of two fingers move it a minute at a time.
final class RulerView: NSView {
    var minutes = PomodoroTimer.defaultMinutes {
        didSet { if minutes != oldValue { needsDisplay = true } }
    }
    /// Dimmed and deaf to the pointer while the timer runs.
    var isActive = true {
        didSet { if isActive != oldValue { needsDisplay = true } }
    }
    var onChange: (Int) -> Void = { _ in }

    private let range = PomodoroTimer.minutesRange
    /// Room at both ends for the head of the mark and the number 60.
    private let inset: CGFloat = 9
    /// The line the ticks stand on, in the flipped view.
    private let baseline: CGFloat = 32
    private var scrolled: CGFloat = 0

    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private var track: CGFloat { bounds.width - 2 * inset }

    private func x(of minutes: Int) -> CGFloat {
        inset + CGFloat(minutes - range.lowerBound) / CGFloat(range.count - 1) * track
    }

    private func minutes(atX x: CGFloat) -> Int {
        let place = track > 0 ? (x - inset) / track : 0
        return PomodoroTimer.clamped(range.lowerBound + Int((place * CGFloat(range.count - 1)).rounded()))
    }

    private func choose(_ new: Int) {
        let new = PomodoroTimer.clamped(new)
        guard isActive, new != minutes else { return }
        minutes = new
        Haptics.tap()
        onChange(new)
    }

    // MARK: Pointer

    override func mouseDown(with event: NSEvent) {
        choose(minutes(atX: convert(event.locationInWindow, from: nil).x))
    }

    override func mouseDragged(with event: NSEvent) {
        choose(minutes(atX: convert(event.locationInWindow, from: nil).x))
    }

    override func scrollWheel(with event: NSEvent) {
        guard isActive else { return }
        // The momentum after a swipe would run to the end of the ruler: only the fingers count.
        guard event.momentumPhase.isEmpty else { return }
        let step: CGFloat
        if event.hasPreciseScrollingDeltas {
            // A trackpad: one minute for every 6 pt of the fingers' travel, along the longer way.
            let along = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) ? event.scrollingDeltaX : event.scrollingDeltaY
            step = along / 6
        } else {
            // A wheel: one minute for a notch.
            step = abs(event.deltaX) > abs(event.deltaY) ? event.deltaX : event.deltaY
        }
        scrolled += step
        let whole = Int(scrolled)
        if whole != 0 {
            scrolled -= CGFloat(whole)
            choose(minutes + whole)
        }
        if event.phase == .ended || event.phase == .cancelled { scrolled = 0 }
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let dim: CGFloat = isActive ? 1 : 0.4
        ctx.setLineCap(.round)
        ctx.setLineWidth(1.2)
        for m in range {
            let height: CGFloat = m % 10 == 0 ? 17 : (m % 5 == 0 ? 12 : 8)
            ctx.setStrokeColor(NSColor(white: 1, alpha: (m <= minutes ? 0.85 : 0.22) * dim).cgColor)
            ctx.move(to: CGPoint(x: x(of: m), y: baseline))
            ctx.addLine(to: CGPoint(x: x(of: m), y: baseline - height))
            ctx.strokePath()
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 9.5, weight: .medium),
            .foregroundColor: NSColor(white: 1, alpha: 0.5 * dim)]
        for m in stride(from: 10, through: range.upperBound, by: 10) {
            let number = NSAttributedString(string: String(m), attributes: attributes)
            number.draw(at: NSPoint(x: x(of: m) - number.size().width / 2, y: baseline + 3))
        }
        // The mark: a head and a line down to the ticks, in the brand colour.
        let mark = NSColor(red: 0.96, green: 0.96, blue: 0.98, alpha: dim).cgColor
        let markX = x(of: minutes)
        ctx.setStrokeColor(mark)
        ctx.setFillColor(mark)
        ctx.setLineWidth(2)
        ctx.move(to: CGPoint(x: markX, y: 9))
        ctx.addLine(to: CGPoint(x: markX, y: baseline + 1))
        ctx.strokePath()
        ctx.fillEllipse(in: CGRect(x: markX - 4.5, y: 2, width: 9, height: 9))
    }

    // MARK: VoiceOver: a slider in minutes

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .slider }
    override func accessibilityLabel() -> String? { L("Длительность") }
    override func accessibilityValue() -> Any? { minutes }
    override func accessibilityMinValue() -> Any? { range.lowerBound }
    override func accessibilityMaxValue() -> Any? { range.upperBound }
    override func accessibilityValueDescription() -> String? { L("%@ мин", String(minutes)) }

    override func accessibilityPerformIncrement() -> Bool {
        choose(minutes + 1)
        return isActive
    }

    override func accessibilityPerformDecrement() -> Bool {
        choose(minutes - 1)
        return isActive
    }
}

struct Ruler: NSViewRepresentable {
    var minutes: Int
    var isActive: Bool
    var onChange: (Int) -> Void

    func makeNSView(context: Context) -> RulerView {
        let view = RulerView()
        update(view)
        return view
    }

    func updateNSView(_ view: RulerView, context: Context) {
        update(view)
    }

    private func update(_ view: RulerView) {
        view.onChange = onChange
        view.minutes = minutes
        view.isActive = isActive
    }
}
