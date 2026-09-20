import AppKit
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
}
#endif
