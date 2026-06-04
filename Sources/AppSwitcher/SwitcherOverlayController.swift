import AppKit

final class SwitcherOverlayController {
    private let window: NSWindow
    private let overlayView = SwitcherOverlayView()

    var isVisible: Bool {
        window.isVisible
    }

    init() {
        window = SwitcherOverlayPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hasShadow = true
        window.contentView = overlayView
    }

    func show(candidates: [WindowCandidate], selectedIndex: Int) {
        overlayView.candidates = candidates
        overlayView.selectedIndex = selectedIndex

        let frame = preferredFrame(candidateCount: candidates.count)
        window.setFrame(frame, display: true)
        window.makeKeyAndOrderFront(nil)
    }

    func updateSelection(_ selectedIndex: Int) {
        overlayView.selectedIndex = selectedIndex
    }

    func hide() {
        window.orderOut(nil)
    }

    private func preferredFrame(candidateCount: Int) -> CGRect {
        let screenFrame = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 900, height: 600)
        let itemWidth: CGFloat = 112
        let itemHeight: CGFloat = 118
        let horizontalPadding: CGFloat = 28
        let verticalPadding: CGFloat = 24
        let visibleCount = min(max(candidateCount, 1), 7)
        let width = CGFloat(visibleCount) * itemWidth + horizontalPadding * 2
        let height = itemHeight + verticalPadding * 2

        return CGRect(
            x: screenFrame.midX - width / 2,
            y: screenFrame.midY - height / 2,
            width: width,
            height: height
        )
    }
}

private final class SwitcherOverlayPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}

final class SwitcherOverlayView: NSView {
    var candidates: [WindowCandidate] = [] {
        didSet { needsDisplay = true }
    }

    var selectedIndex: Int = 0 {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let backgroundPath = NSBezierPath(roundedRect: bounds, xRadius: 18, yRadius: 18)
        NSColor.windowBackgroundColor.withAlphaComponent(0.86).setFill()
        backgroundPath.fill()

        NSColor.separatorColor.withAlphaComponent(0.4).setStroke()
        backgroundPath.lineWidth = 1
        backgroundPath.stroke()

        guard !candidates.isEmpty else {
            return
        }

        let itemWidth: CGFloat = 112
        let visibleRange = visibleCandidateRange()
        let visibleCandidates = candidates[visibleRange]
        let startX = (bounds.width - CGFloat(visibleCandidates.count) * itemWidth) / 2

        for (offset, candidate) in visibleCandidates.enumerated() {
            draw(candidate: candidate, index: visibleRange.lowerBound + offset, in: CGRect(
                x: startX + CGFloat(offset) * itemWidth,
                y: 24,
                width: itemWidth,
                height: bounds.height - 48
            ))
        }
    }

    private func visibleCandidateRange() -> Range<Int> {
        let visibleCount = min(candidates.count, 7)
        let halfWindow = visibleCount / 2
        let lowerBound = min(
            max(selectedIndex - halfWindow, 0),
            max(candidates.count - visibleCount, 0)
        )

        return lowerBound..<(lowerBound + visibleCount)
    }

    private func draw(candidate: WindowCandidate, index: Int, in rect: CGRect) {
        let selected = index == selectedIndex
        let selectionRect = rect.insetBy(dx: 8, dy: 0)

        if selected {
            let selectionPath = NSBezierPath(roundedRect: selectionRect, xRadius: 12, yRadius: 12)
            NSColor.controlAccentColor.withAlphaComponent(0.20).setFill()
            selectionPath.fill()
            NSColor.controlAccentColor.withAlphaComponent(0.85).setStroke()
            selectionPath.lineWidth = 2
            selectionPath.stroke()
        }

        let iconRect = CGRect(x: rect.midX - 24, y: rect.minY + 12, width: 48, height: 48)
        if let icon = candidate.appIcon {
            icon.draw(in: iconRect)
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byTruncatingTail

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: selected ? .semibold : .regular),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ]

        let appAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraphStyle
        ]

        let titleRect = CGRect(x: rect.minX + 10, y: iconRect.maxY + 12, width: rect.width - 20, height: 18)
        candidate.displayTitle.draw(with: titleRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: titleAttributes)

        let appRect = CGRect(x: rect.minX + 10, y: titleRect.maxY + 4, width: rect.width - 20, height: 16)
        candidate.appName.draw(with: appRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: appAttributes)
    }
}
