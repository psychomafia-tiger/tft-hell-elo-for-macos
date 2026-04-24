import SwiftUI

/// TFT Mac Companion — menu bar app entry point.
///
/// Phase 1 Task 1.1 bootstrap: minimal @main stub. Task 1.8 will replace the
/// `WindowGroup` with a `MenuBarExtra` scene wiring up `HotkeyRegistrar` and
/// the tier-list popover view. Keeping this file bare on purpose — the scope
/// guardrail for Task 1.1 is "project compiles", not "app functions".
@main
struct TFTMacApp: App {
    var body: some Scene {
        // Placeholder scene. Replaced in Task 1.8 by MenuBarExtra + popover content.
        WindowGroup {
            EmptyView()
        }
    }
}
