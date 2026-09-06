import AppKit
import SwiftUI

final class SwitcherOverlayController {
    private let window: NSWindow
    private let materialView = NSVisualEffectView()
    private let hostingView = NSHostingView(rootView: SwitcherOverlayContentView(candidates: [], selectedIndex: 0))

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
        window.hasShadow = false

        materialView.material = .hudWindow
        materialView.blendingMode = .withinWindow
        materialView.state = .active
        materialView.wantsLayer = true
        materialView.layer?.cornerRadius = SwitcherOverlayContentView.metrics.backgroundCornerRadius
        materialView.layer?.cornerCurve = .continuous
        materialView.layer?.masksToBounds = true
        materialView.layer?.backgroundColor = NSColor.clear.cgColor

        hostingView.frame = materialView.bounds
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = SwitcherOverlayContentView.metrics.backgroundCornerRadius
        hostingView.layer?.cornerCurve = .continuous
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.layer?.masksToBounds = true
        materialView.addSubview(hostingView)
        window.contentView = materialView
    }

    /// Populates and centers the floating overlay for the current switcher session.
    func show(candidates: [WindowCandidate], selectedIndex: Int) {
        hostingView.rootView = SwitcherOverlayContentView(candidates: candidates, selectedIndex: selectedIndex)

        let frame = preferredFrame(candidates: candidates)
        window.setFrame(frame, display: true)
        window.makeKeyAndOrderFront(nil)
    }

    func updateSelection(_ selectedIndex: Int) {
        hostingView.rootView = SwitcherOverlayContentView(candidates: hostingView.rootView.candidates, selectedIndex: selectedIndex)
    }

    func hide() {
        window.orderOut(nil)
    }

    /// Sizes the overlay around up to seven visible items and centers it on the main screen.
    private func preferredFrame(candidates: [WindowCandidate]) -> CGRect {
        let screenFrame = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 900, height: 600)
        let metrics = SwitcherOverlayContentView.metrics
        let visibleCount = min(max(candidates.count, 1), metrics.maximumVisibleItems)
        let width = min(
            CGFloat(visibleCount) * metrics.iconSize + CGFloat(max(visibleCount - 1, 0)) * metrics.itemSpacing + metrics.contentInset * 2,
            screenFrame.width - metrics.screenMargin * 2
        )
        let height = metrics.itemHeight + metrics.contentInset * 2

        return CGRect(
            x: screenFrame.midX - width / 2,
            y: screenFrame.midY - height / 2,
            width: width,
            height: height
        ).integral
    }

}

private struct SwitcherOverlayContentView: View {
    struct Metrics {
        let maximumVisibleItems = 7
        let screenMargin: CGFloat = 28
        let iconSize: CGFloat = 130
        let selectorInset: CGFloat = 2
        let backgroundCornerRadius: CGFloat = 31
        let contentInset: CGFloat = 16
        let itemSpacing: CGFloat = 14
        let labelTopGap: CGFloat = 5
        let labelHeight: CGFloat = 10
        let labelFontSize: CGFloat = 13

        var selectorSize: CGFloat { iconSize - selectorInset * 2 }

        var itemHeight: CGFloat {
            iconSize + labelTopGap + labelHeight
        }
    }

    static let metrics = Metrics()

    let candidates: [WindowCandidate]
    let selectedIndex: Int

    var body: some View {
        let visibleRange = visibleCandidateRange()

        HStack(alignment: .top, spacing: Self.metrics.itemSpacing) {
            ForEach(Array(candidates[visibleRange].enumerated()), id: \.element.id) { offset, candidate in
                candidateView(candidate: candidate, index: visibleRange.lowerBound + offset)
            }
        }
        .padding(Self.metrics.contentInset)
        .background(
            RoundedRectangle(cornerRadius: Self.metrics.backgroundCornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
    }

    /// Chooses the contiguous slice of candidates to draw around the current selection.
    private func visibleCandidateRange() -> Range<Int> {
        let visibleCount = min(candidates.count, Self.metrics.maximumVisibleItems)
        let halfWindow = visibleCount / 2
        let lowerBound = min(
            max(selectedIndex - halfWindow, 0),
            max(candidates.count - visibleCount, 0)
        )

        return lowerBound..<(lowerBound + visibleCount)
    }

    private func duplicateWindowDetail(for candidate: WindowCandidate, at index: Int) -> String? {
        guard candidates.indices.contains(where: {
            $0 != index && sameApplication(candidates[$0], candidate)
        }) else {
            return nil
        }

        let title = candidate.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            return title
        }

        return "Window \(index + 1) - \(Int(candidate.frame.width))x\(Int(candidate.frame.height))"
    }

    private func selectedLabel(for candidate: WindowCandidate, at index: Int) -> String {
        if let detail = duplicateWindowDetail(for: candidate, at: index) {
            return "\(candidate.appName) - \(detail)"
        }

        return candidate.appName
    }

    private func sameApplication(_ first: WindowCandidate, _ second: WindowCandidate) -> Bool {
        if let firstBundleIdentifier = first.bundleIdentifier,
           let secondBundleIdentifier = second.bundleIdentifier {
            return firstBundleIdentifier == secondBundleIdentifier
        }

        return first.appName == second.appName
    }

    @ViewBuilder
    private func candidateView(candidate: WindowCandidate, index: Int) -> some View {
        let selected = index == selectedIndex
        VStack(spacing: Self.metrics.labelTopGap) {
            ZStack {
                if selected {
                    RoundedRectangle(cornerRadius: Self.metrics.backgroundCornerRadius, style: .continuous)
                        .fill(Color.white.opacity(0.20))
                        .overlay(
                            RoundedRectangle(cornerRadius: Self.metrics.backgroundCornerRadius, style: .continuous)
                                .stroke(Color.white.opacity(0.58), lineWidth: 2)
                        )
                        .frame(
                            width: Self.metrics.selectorSize,
                            height: Self.metrics.selectorSize
                        )
                }

                if let icon = candidate.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: Self.metrics.iconSize, height: Self.metrics.iconSize)
                }
            }
            .frame(
                width: Self.metrics.iconSize,
                height: Self.metrics.iconSize
            )

            if selected {
                Text(selectedLabel(for: candidate, at: index))
                    .font(.system(size: Self.metrics.labelFontSize, weight: .medium))
                    .foregroundStyle(.white.opacity(0.86))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(
                        width: Self.metrics.iconSize,
                        height: Self.metrics.labelHeight,
                        alignment: .center
                    )
            } else {
                Color.clear
                    .frame(height: Self.metrics.labelHeight)
            }
        }
        .frame(width: Self.metrics.iconSize, height: Self.metrics.itemHeight, alignment: .top)
        .accessibilityLabel(selectedLabel(for: candidate, at: index))
    }
}

private final class SwitcherOverlayPanel: NSPanel {
    override var canBecomeKey: Bool {
        // Local key monitors only receive session navigation keys while this panel can become key.
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}
