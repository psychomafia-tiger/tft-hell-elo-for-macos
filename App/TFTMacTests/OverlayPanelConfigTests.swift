import XCTest
import AppKit
@testable import TFTMac

/// Wave 5b invariants test — OverlayPanel must satisfy fullscreen-overlay contract.
///
/// Each assertion maps to a concrete dogfood failure we're protecting against:
/// - `canBecomeKey=false` → mid-game "ff" typing stays in TFT (not panel)
/// - `level == screenSaver` → renders above borderless TFT (Wave 5d hotfix:
///   bumped from `.overlayWindow` (102) → `.screenSaver` (1000) sau khi anh test
///   confirm panel ở layer dưới TFT borderless trên cùng monitor)
/// - `collectionBehavior.fullScreenAuxiliary` → shows on native-fullscreen Space
/// - `hidesOnDeactivate=false` → doesn't vanish when TFT grabs focus
/// - `.nonactivatingPanel` styleMask → showing panel doesn't app-switch away from TFT
///
/// If any of these drifts, dogfood Wave 5e will fail silently — test catches it
/// at the unit level before the founder loses 1-2 h of manual debugging time.
final class OverlayPanelConfigTests: XCTestCase {

    private var panel: OverlayPanel!

    override func setUp() {
        super.setUp()
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        panel = OverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 600),
            contentView: host
        )
    }

    override func tearDown() {
        panel = nil
        super.tearDown()
    }

    func testPanelLevelMatchesScreenSaverLevel() {
        // Wave 5d hotfix — bumped from overlayWindow (102) → screenSaver (1000).
        // Verified: ở level 102, panel rơi xuống dưới TFT borderless trên cùng
        // monitor. screenSaver level = bulletproof always-on-top.
        XCTAssertEqual(panel.level, NSWindow.Level.screenSaver,
                       "Panel must sit at screenSaver level (1000) to render above ALL "
                       + "frontmost-app windows including TFT borderless game window")
    }

    func testCollectionBehaviorIncludesFullScreenAuxiliary() {
        XCTAssertTrue(panel.collectionBehavior.contains(.fullScreenAuxiliary),
                      "fullScreenAuxiliary required so panel shows on native-fullscreen TFT Space")
    }

    func testCollectionBehaviorIncludesCanJoinAllSpaces() {
        XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces),
                      "canJoinAllSpaces required so user switching desktop preserves panel visibility")
    }

    func testCollectionBehaviorIncludesStationary() {
        XCTAssertTrue(panel.collectionBehavior.contains(.stationary),
                      "stationary prevents Mission Control animating panel during desktop switch")
    }

    func testCanBecomeKeyReturnsFalse() {
        XCTAssertFalse(panel.canBecomeKey,
                       "canBecomeKey MUST be false — mid-game TFT keystrokes must not route to overlay")
    }

    func testCanBecomeMainReturnsFalse() {
        XCTAssertFalse(panel.canBecomeMain,
                       "canBecomeMain MUST be false — panel is auxiliary, never primary window")
    }

    func testHidesOnDeactivateIsFalse() {
        XCTAssertFalse(panel.hidesOnDeactivate,
                       "hidesOnDeactivate MUST be false — TFT grabbing focus must not hide overlay")
    }

    func testIsFloatingPanelIsTrue() {
        XCTAssertTrue(panel.isFloatingPanel,
                      "isFloatingPanel true signals NSPanel auxiliary role to macOS window manager")
    }

    func testStyleMaskContainsNonactivatingPanel() {
        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel),
                      ".nonactivatingPanel styleMask prevents app-switch when panel shows (TFT stays foreground)")
    }
}
