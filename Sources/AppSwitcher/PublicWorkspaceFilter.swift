import CoreGraphics

struct VisibleWindowSnapshot {
    let processIdentifier: pid_t
    let frame: CGRect
    let layer: Int
}

final class PublicWorkspaceFilter {
    /// Keeps candidates that appear in the public on-screen window list, ordered front-to-back.
    func filter(_ candidates: [WindowCandidate]) -> [WindowCandidate] {
        filter(candidates, visibleWindows: currentVisibleWindows())
    }

    /// Excludes elevated windows such as Picture-in-Picture after matching them to AX candidates.
    private func filter(
        _ candidates: [WindowCandidate],
        visibleWindows: [VisibleWindowSnapshot]
    ) -> [WindowCandidate] {
        var matchedCandidateIndexes = Set<Int>()

        return visibleWindows.compactMap { visibleWindow in
            guard let candidateIndex = bestCandidateIndex(
                for: visibleWindow,
                candidates: candidates,
                excluding: matchedCandidateIndexes
            ) else {
                return nil
            }

            matchedCandidateIndexes.insert(candidateIndex)
            guard visibleWindow.layer == 0 else {
                return nil
            }

            return candidates[candidateIndex]
        }
    }

    /// Reads the current workspace's visible windows from Core Graphics window-server metadata.
    private func currentVisibleWindows() -> [VisibleWindowSnapshot] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfo = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        return windowInfo.compactMap { info in
            guard
                let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
                let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
                let layer = info[kCGWindowLayer as String] as? Int
            else {
                return nil
            }

            let frame = CGRect(
                x: bounds["X"] ?? 0,
                y: bounds["Y"] ?? 0,
                width: bounds["Width"] ?? 0,
                height: bounds["Height"] ?? 0
            )

            guard !frame.isEmpty else {
                return nil
            }

            return VisibleWindowSnapshot(
                processIdentifier: ownerPID,
                frame: frame,
                layer: layer
            )
        }
    }

    /// Chooses the unmatched AX candidate whose frame most closely matches the Core Graphics window.
    private func bestCandidateIndex(
        for visibleWindow: VisibleWindowSnapshot,
        candidates: [WindowCandidate],
        excluding matchedCandidateIndexes: Set<Int>
    ) -> Int? {
        candidates.indices.compactMap { index -> (index: Int, score: CGFloat)? in
            guard !matchedCandidateIndexes.contains(index) else {
                return nil
            }

            guard let score = matchScore(
                candidate: candidates[index],
                visibleWindow: visibleWindow
            ) else {
                return nil
            }

            return (index, score)
        }.max { first, second in
            first.score < second.score
        }?.index
    }

    /// Scores same-process windows using intersection over union so containment cannot dominate.
    private func matchScore(
        candidate: WindowCandidate,
        visibleWindow: VisibleWindowSnapshot
    ) -> CGFloat? {
        guard candidate.processIdentifier == visibleWindow.processIdentifier else {
            return nil
        }

        let intersection = candidate.frame.intersection(visibleWindow.frame)
        guard !intersection.isNull, !intersection.isEmpty else {
            return nil
        }

        let candidateArea = candidate.frame.width * candidate.frame.height
        let visibleWindowArea = visibleWindow.frame.width * visibleWindow.frame.height
        let intersectionArea = intersection.width * intersection.height
        let unionArea = candidateArea + visibleWindowArea - intersectionArea

        guard unionArea > 0 else {
            return nil
        }

        let score = intersectionArea / unionArea
        return score > 0.5 ? score : nil
    }
}
