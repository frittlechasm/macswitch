import AppKit
import Carbon
import CoreGraphics
#if canImport(Testing)
import Testing
#elseif canImport(XCTest)
import XCTest
#else
#error("AppSwitcherTests requires Swift Testing or XCTest")
#endif
@testable import AppSwitcher

#if canImport(Testing)
@Test func commandTabUsesCommandModifier() {
    #expect(SwitcherShortcut.commandTab.displayName == "Command-Tab")
    #expect(SwitcherShortcut.commandTab.eventModifierFlags == [.command])
}

@Test func commandTabIsNotAnAutomaticFallback() {
    #expect(!SwitcherShortcut.automaticFallbacks.contains(.commandTab))
    #expect(SwitcherShortcut.automaticFallbacks.contains(.defaultShortcut))
}

@Test func commandTabEventFilterMatchesForwardAndReverseChords() {
    #expect(CommandTabEventFilter.shouldIntercept(type: .keyDown, keyCode: CGKeyCode(kVK_Tab), flags: [.maskCommand]))
    #expect(CommandTabEventFilter.shouldIntercept(type: .keyUp, keyCode: CGKeyCode(kVK_Tab), flags: [.maskCommand, .maskShift]))
}

@Test func commandTabEventFilterLeavesOtherChordsAlone() {
    #expect(!CommandTabEventFilter.shouldIntercept(type: .keyDown, keyCode: CGKeyCode(kVK_Tab), flags: []))
    #expect(!CommandTabEventFilter.shouldIntercept(type: .keyDown, keyCode: CGKeyCode(kVK_Tab), flags: [.maskCommand, .maskAlternate]))
    #expect(!CommandTabEventFilter.shouldIntercept(type: .flagsChanged, keyCode: CGKeyCode(kVK_Tab), flags: [.maskCommand]))
    #expect(!CommandTabEventFilter.shouldIntercept(type: .keyDown, keyCode: CGKeyCode(kVK_ANSI_A), flags: [.maskCommand]))
}
#elseif canImport(XCTest)
final class SwitcherShortcutTests: XCTestCase {
    func testCommandTabUsesCommandModifier() {
        XCTAssertEqual(SwitcherShortcut.commandTab.displayName, "Command-Tab")
        XCTAssertEqual(SwitcherShortcut.commandTab.eventModifierFlags, [.command])
    }

    func testCommandTabIsNotAnAutomaticFallback() {
        XCTAssertFalse(SwitcherShortcut.automaticFallbacks.contains(.commandTab))
        XCTAssertTrue(SwitcherShortcut.automaticFallbacks.contains(.defaultShortcut))
    }

    func testCommandTabEventFilterMatchesForwardAndReverseChords() {
        XCTAssertTrue(CommandTabEventFilter.shouldIntercept(type: .keyDown, keyCode: CGKeyCode(kVK_Tab), flags: [.maskCommand]))
        XCTAssertTrue(CommandTabEventFilter.shouldIntercept(type: .keyUp, keyCode: CGKeyCode(kVK_Tab), flags: [.maskCommand, .maskShift]))
    }

    func testCommandTabEventFilterLeavesOtherChordsAlone() {
        XCTAssertFalse(CommandTabEventFilter.shouldIntercept(type: .keyDown, keyCode: CGKeyCode(kVK_Tab), flags: []))
        XCTAssertFalse(CommandTabEventFilter.shouldIntercept(type: .keyDown, keyCode: CGKeyCode(kVK_Tab), flags: [.maskCommand, .maskAlternate]))
        XCTAssertFalse(CommandTabEventFilter.shouldIntercept(type: .flagsChanged, keyCode: CGKeyCode(kVK_Tab), flags: [.maskCommand]))
        XCTAssertFalse(CommandTabEventFilter.shouldIntercept(type: .keyDown, keyCode: CGKeyCode(kVK_ANSI_A), flags: [.maskCommand]))
    }
}
#endif
