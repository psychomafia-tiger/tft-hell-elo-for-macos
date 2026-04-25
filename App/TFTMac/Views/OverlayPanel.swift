import AppKit

/// Fullscreen-capable overlay panel for TFT Hell Elo.
///
/// Wave 5b (F1 dogfood fix) — popover alone does not render above TFT's fullscreen /
/// borderless window. `NSPanel` with `overlayWindowLevel` + `fullScreenAuxiliary`
/// collection behavior breaks out of Space restrictions, matching how Stream Deck,
/// Rectangle, and Alfred render on top of exclusive-fullscreen apps.
///
/// **Critical invariants** (enforced by `OverlayPanelConfigTests`):
/// - `canBecomeKey == false` — mid-game typing ("ff" to surrender, chat) MUST go
///   to TFT, not the panel. If the panel accidentally becomes key, user loses
///   input and the overlay is unshippable.
/// - `level == overlayWindowLevel` — sits above NSStatusWindowLevel (25),
///   below screenSaver (1000). Survives `CGWindowLevelForKey` lookup on current
///   macOS; hardcoded literals drift between releases.
/// - `collectionBehavior` includes `.fullScreenAuxiliary` — allows panel to appear
///   on a Space that hosts a native-fullscreen window (TFT exclusive fullscreen).
///   `.canJoinAllSpaces` means no re-show needed when user switches desktop.
///   `.stationary` prevents Mission Control from animating the panel.
/// - `hidesOnDeactivate == false` — default NSPanel hides when app loses focus;
///   TFT grabbing focus would hide the overlay immediately, defeating the point.
///
/// **Styling rationale**: `.nonactivatingPanel` keeps TFT active when panel shows
/// (no app-switch blip); `.resizable` + `.titled` give the user a drag handle +
/// close button; title is hidden via empty-string `title`.
///
/// Plain-language: analogy — overlay panel giống như 1 HUD (heads-up display) nổi
/// trên màn hình game, user nhìn thấy nhưng game engine không cảm nhận nó. Khi
/// user bấm "ff" → keystroke đi thẳng vào TFT, overlay chỉ hiển thị.
final class OverlayPanel: NSPanel {

    init(contentRect: NSRect, contentView: NSView) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .resizable, .titled],
            backing: .buffered,
            defer: false
        )
        // Order matters: `isFloatingPanel = true` internally writes `level = .floating`
        // (rawValue 3), so we must set level AFTER isFloatingPanel. Otherwise the
        // screenSaver level silently downgrades to floating — dogfood-breaking
        // regression that `testPanelLevelMatchesScreenSaverLevel` guards against.
        self.isFloatingPanel = true
        // Level: `screenSaver` (rawValue 1000). Wave 5d hotfix bumped from
        // `.overlayWindow` (102) → `.screenSaver` (1000) sau khi anh test multi-monitor:
        // ở level 102 panel rơi xuống LAYER DƯỚI TFT borderless trên cùng màn hình.
        // Plain-language: window level giống "tầng" trong tòa nhà —
        //   - level 0 = tầng trệt (TFT borderless game window)
        //   - level 24 = tầng menu bar macOS
        //   - level 102 = overlayWindow (mình ban đầu, không đủ với cross-app frontmost)
        //   - level 1000 = screenSaver (bulletproof always-on-top)
        // Tradeoff: panel sẽ overlap menu bar macOS. Đó là feature mong muốn cho
        // game overlay (giống TFTactics Win — overlay che mọi thứ phía dưới).
        self.level = .screenSaver
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.hidesOnDeactivate = false
        self.isMovableByWindowBackground = true
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.title = ""
        self.contentView = contentView
    }

    /// Override: panel must NEVER become key window. Guarantees TFT retains keyboard
    /// input when overlay is visible. NSPanel's default returns true when titled;
    /// forcing false here is the one invariant the focus-steal test asserts against.
    override var canBecomeKey: Bool { false }

    /// Override: panel is auxiliary, never the main window. Prevents macOS window
    /// management from promoting it (e.g. Cmd+` cycle treats it as primary).
    override var canBecomeMain: Bool { false }
}
