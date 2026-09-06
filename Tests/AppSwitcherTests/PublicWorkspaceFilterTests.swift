import ApplicationServices
import CoreGraphics
#if canImport(Testing)
import Testing
#elseif canImport(XCTest)
import XCTest
#else
#error("AppSwitcherTests requires Swift Testing or XCTest")
#endif
@testable import AppSwitcher

private let processIdentifier: pid_t = 42

#if canImport(Testing)
@Test func elevatedWindowCannotConsumeOrdinaryCandidate() {
    #expect(filteredIDsWhenElevatedPrecedesOrdinary() == ["vscode"])
}

@Test func elevatedWindowIsNotReturnedAsCandidate() {
    #expect(filteredIDsForElevatedWindow() == [])
}

@Test func layerZeroCandidatesPreserveFrontToBackOrder() {
    #expect(filteredIDsInVisibleWindowOrder() == ["back", "front"])
}

@Test func matchingUsesProcessAndStrongestOverlap() {
    #expect(filteredIDsForProcessAndOverlap() == ["strongest-same-process"])
}

@Test func equalMatchesPreserveCandidateOrderAndAreConsumedOnce() {
    #expect(filteredIDsForEqualMatches() == ["first", "second"])
}

@Test func matchingRequiresMoreThanHalfOverlap() {
    #expect(filteredIDsAtThreshold() == [])
}
#elseif canImport(XCTest)
final class PublicWorkspaceFilterTests: XCTestCase {
    func testElevatedWindowCannotConsumeOrdinaryCandidate() {
        XCTAssertEqual(filteredIDsWhenElevatedPrecedesOrdinary(), ["vscode"])
    }

    func testElevatedWindowIsNotReturnedAsCandidate() {
        XCTAssertEqual(filteredIDsForElevatedWindow(), [])
    }

    func testLayerZeroCandidatesPreserveFrontToBackOrder() {
        XCTAssertEqual(filteredIDsInVisibleWindowOrder(), ["back", "front"])
    }

    func testMatchingUsesProcessAndStrongestOverlap() {
        XCTAssertEqual(filteredIDsForProcessAndOverlap(), ["strongest-same-process"])
    }

    func testEqualMatchesPreserveCandidateOrderAndAreConsumedOnce() {
        XCTAssertEqual(filteredIDsForEqualMatches(), ["first", "second"])
    }

    func testMatchingRequiresMoreThanHalfOverlap() {
        XCTAssertEqual(filteredIDsAtThreshold(), [])
    }
}
#endif

private func filteredIDsWhenElevatedPrecedesOrdinary() -> [String] {
    let frame = CGRect(x: 10, y: 20, width: 800, height: 600)
    let candidate = makeCandidate(id: "vscode", frame: frame)
    let visibleWindows = [
        makeVisibleWindow(frame: frame, layer: 3),
        makeVisibleWindow(frame: frame, layer: 0)
    ]

    let result = PublicWorkspaceFilter().filter([candidate], visibleWindows: visibleWindows)
    return result.map(\.id)
}

private func filteredIDsForElevatedWindow() -> [String] {
    let pictureInPicture = makeCandidate(
        id: "picture-in-picture",
        frame: CGRect(x: 700, y: 20, width: 320, height: 180)
    )
    let visibleWindows = [
        makeVisibleWindow(frame: pictureInPicture.frame, layer: 3)
    ]

    let result = PublicWorkspaceFilter().filter([pictureInPicture], visibleWindows: visibleWindows)
    return result.map(\.id)
}

private func filteredIDsInVisibleWindowOrder() -> [String] {
    let front = makeCandidate(id: "front", frame: CGRect(x: 0, y: 0, width: 500, height: 500))
    let back = makeCandidate(id: "back", frame: CGRect(x: 600, y: 0, width: 500, height: 500))
    let visibleWindows = [
        makeVisibleWindow(frame: front.frame, layer: 5),
        makeVisibleWindow(frame: back.frame, layer: 0),
        makeVisibleWindow(frame: front.frame, layer: 0)
    ]

    let result = PublicWorkspaceFilter().filter([front, back], visibleWindows: visibleWindows)
    return result.map(\.id)
}

private func filteredIDsForProcessAndOverlap() -> [String] {
    let visibleFrame = CGRect(x: 0, y: 0, width: 100, height: 100)
    let candidates = [
        makeCandidate(id: "perfect-other-process", frame: visibleFrame, processID: 7),
        makeCandidate(id: "weaker-same-process", frame: CGRect(x: 10, y: 0, width: 100, height: 100)),
        makeCandidate(id: "strongest-same-process", frame: visibleFrame)
    ]

    let result = PublicWorkspaceFilter().filter(
        candidates,
        visibleWindows: [makeVisibleWindow(frame: visibleFrame, layer: 0)]
    )
    return result.map(\.id)
}

private func filteredIDsForEqualMatches() -> [String] {
    let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    let candidates = [
        makeCandidate(id: "first", frame: frame),
        makeCandidate(id: "second", frame: frame)
    ]
    let visibleWindows = [
        makeVisibleWindow(frame: frame, layer: 0),
        makeVisibleWindow(frame: frame, layer: 0)
    ]

    let result = PublicWorkspaceFilter().filter(candidates, visibleWindows: visibleWindows)
    return result.map(\.id)
}

private func filteredIDsAtThreshold() -> [String] {
    let candidate = makeCandidate(
        id: "half-overlap",
        frame: CGRect(x: 0, y: 0, width: 100, height: 100)
    )
    let visibleWindow = makeVisibleWindow(
        frame: CGRect(x: 0, y: 0, width: 200, height: 100),
        layer: 0
    )

    let result = PublicWorkspaceFilter().filter([candidate], visibleWindows: [visibleWindow])
    return result.map(\.id)
}

private func makeCandidate(
    id: String,
    frame: CGRect,
    processID: pid_t = processIdentifier
) -> WindowCandidate {
    WindowCandidate(
        id: id,
        processIdentifier: processID,
        appName: "Test App",
        bundleIdentifier: "com.example.test",
        title: id,
        frame: frame,
        appIcon: nil,
        axWindow: AXUIElementCreateApplication(processID)
    )
}

private func makeVisibleWindow(frame: CGRect, layer: Int) -> VisibleWindowSnapshot {
    VisibleWindowSnapshot(
        processIdentifier: processIdentifier,
        frame: frame,
        layer: layer
    )
}
