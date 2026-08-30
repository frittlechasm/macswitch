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

private func makeCandidate(id: String, frame: CGRect) -> WindowCandidate {
    WindowCandidate(
        id: id,
        processIdentifier: processIdentifier,
        appName: "Test App",
        bundleIdentifier: "com.example.test",
        title: id,
        frame: frame,
        appIcon: nil,
        axWindow: AXUIElementCreateApplication(processIdentifier)
    )
}

private func makeVisibleWindow(frame: CGRect, layer: Int) -> VisibleWindowSnapshot {
    VisibleWindowSnapshot(
        processIdentifier: processIdentifier,
        frame: frame,
        layer: layer
    )
}
