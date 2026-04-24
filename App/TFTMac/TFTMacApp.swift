import SwiftUI

/// TFT Mac Companion — menu bar app entry point.
///
/// Phase 1 Task 1.1 bootstrap: minimal @main stub. Task 1.8 will replace the
/// `Settings` scene with a `MenuBarExtra` scene wiring up `HotkeyRegistrar` and
/// the tier-list popover view. Keeping this file bare on purpose — the scope
/// guardrail for Task 1.1 is "project compiles", not "app functions".
///
/// `Settings` is used here instead of `WindowGroup` so no window is created on
/// launch (Settings is invisible until explicitly opened). This preserves the
/// ≤500ms launch-metric baseline for Task 1.10.
@main
struct TFTMacApp: App {
    var body: some Scene {
        // Placeholder scene. Replaced in Task 1.8 by MenuBarExtra + popover content.
        // Settings creates no window on launch; WindowGroup would flash a phantom window.
        Settings {
            EmptyView()
        }
    }
}
