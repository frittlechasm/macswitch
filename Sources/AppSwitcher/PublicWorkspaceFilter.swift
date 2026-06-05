import CoreGraphics

struct VisibleWindowSnapshot {
    let processIdentifier: pid_t
    let title: String
    let frame: CGRect
}

final class PublicWorkspaceFilter {
    func filter(_ candidates: [WindowCandidate]) -> [WindowCandidate] {
        let visibleWindows = currentVisibleWindows()

        return candidates.filter { candidate in
            visibleWindows.contains { visibleWindow in
                isVisibleMatch(candidate: candidate, visibleWindow: visibleWindow)
            }
        }
    }

    private func currentVisibleWindows() -> [VisibleWindowSnapshot] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfo = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        return windowInfo.compactMap { info in
            guard
                let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
                let bounds = info[kCGWindowBounds as String] as? [String: CGFloat]
            else {
                return nil
            }

            let title = info[kCGWindowName as String] as? String ?? ""
            let frame = CGRect(
                x: bounds["X"] ?? 0,
                y: bounds["Y"] ?? 0,
                width: bounds["Width"] ?? 0,
                height: bounds["Height"] ?? 0
            )

            guard !frame.isEmpty else {
                return nil
            }

            return VisibleWindowSnapshot(processIdentifier: ownerPID, title: title, frame: frame)
        }
    }

    private func isVisibleMatch(candidate: WindowCandidate, visibleWindow: VisibleWindowSnapshot) -> Bool {
        guard candidate.processIdentifier == visibleWindow.processIdentifier else {
            return false
        }

        if !visibleWindow.title.isEmpty {
            let candidateTitle = candidate.title.lowercased()
            let visibleTitle = visibleWindow.title.lowercased()

            if candidateTitle == visibleTitle ||
                candidateTitle.contains(visibleTitle) ||
                visibleTitle.contains(candidateTitle) {
                return true
            }
        }

        let intersection = candidate.frame.intersection(visibleWindow.frame)
        guard !intersection.isNull, !intersection.isEmpty else {
            return false
        }

        let candidateArea = candidate.frame.width * candidate.frame.height
        guard candidateArea > 0 else {
            return false
        }

        return (intersection.width * intersection.height) / candidateArea > 0.5
    }
}
