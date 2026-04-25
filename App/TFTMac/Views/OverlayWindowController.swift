import AppKit
import SwiftUI

/// Lifecycle owner of the fullscreen overlay `OverlayPanel`.
///
/// Wave 5b (F1): eager-instantiate the panel at app launch (D2 decision) so the
/// first Cmd+Shift+T shows in <50ms — lazy init on first hotkey would add
/// ~150-300ms for NSPanel + NSHostingView construction, perceived as "laggy"
/// during decision windows (2-1 augment, shop-reroll).
///
/// Plain-language cost of eager init: +15-20MB RSS (panel shell + SwiftUI tree).
/// Analogy — on a 16GB Mac, +15MB = like opening 1 extra Chrome tab,
/// negligible. On an 8GB Mac under memory pressure, monitor via Instruments
/// (Wave 5b manual gate: total RSS ≤ 45MB after init).
///
/// **Published `isVisible`** lets SwiftUI views observe (future Settings toggle
/// to hide overlay without killing instance). Mirrors panel's actual on-screen
/// state via `show` / `hide` / `toggle` entry points — tests assert 10+
/// consecutive toggles remain idempotent (no orphan window).
///
/// **Threading**: AppKit window ops must run on main thread. Callers are
/// responsible for main-thread dispatch; production hotkey path already runs
/// on main (HotKey package invokes Carbon on main run loop).
final class OverlayWindowController: ObservableObject {

    @Published private(set) var isVisible: Bool = false

    /// Held strongly — `orderOut(nil)` hides but doesn't dealloc, so ARC keeps
    /// the panel alive between show/hide cycles. Losing this reference would
    /// require re-instantiation on every show, nullifying the eager-init win.
    private var panel: OverlayPanel?

    /// Default overlay size (width matches D4 decision: 520px for overlay, 440 popover).
    /// Height matches popover 600; dynamic card heights inside CompListView scroll.
    static let defaultSize = NSSize(width: 520, height: 600)

    /// Injected tier list used to render `CompListView` inside the panel.
    /// Optional so tests (and Wave 5b skip-init path) can construct a
    /// controller without tier data. Production wiring in `TFTMacApp`
    /// passes the loaded bundle snapshot.
    private let tierList: TierList?

    init(tierList: TierList? = nil, skipPanelInstantiation: Bool = false) {
        self.tierList = tierList
        // Tests pass `skipPanelInstantiation: true` to avoid creating a real NSPanel
        // when only verifying state machine logic. Production always instantiates.
        guard !skipPanelInstantiation else { return }
        instantiatePanel()
    }

    /// Build the NSPanel + SwiftUI content. Wave 5c wires the shared
    /// `CompListView(width: 520)` so overlay and popover render identical
    /// card layout. If no tier list is injected (test / pre-data init),
    /// renders the Wave 5b placeholder.
    private func instantiatePanel() {
        let hosting: NSHostingView<AnyView>
        if let tierList = tierList {
            let content = AnyView(CompListView(tierList: tierList, width: Self.defaultSize.width))
            hosting = NSHostingView(rootView: content)
        } else {
            hosting = NSHostingView(rootView: AnyView(OverlayPlaceholderContent()))
        }
        hosting.frame = NSRect(origin: .zero, size: Self.defaultSize)

        // Initial position: top-right quadrant of CURSOR screen (not NSScreen.main).
        //
        // Wave 5d hotfix: NSScreen.main = screen có key window — trên multi-monitor
        // setup, key window thường ở Screen B (Finder/desktop), trong khi anh chơi
        // TFT trên Screen A. Result: panel default hiện sang screen sai, anh phải
        // drag thủ công.
        //
        // Plain-language: hình dung 2 màn hình (Screen A trái + Screen B phải).
        // Game TFT trên Screen A. Cursor anh đang ở Screen A để play. Trước fix:
        // panel show ở Screen B (NSScreen.main = key window screen) → anh phải
        // drag panel sang trái. Sau fix: panel show ở Screen A (cursor screen),
        // top-right corner — nơi stats dashboards thường nằm trong TFT layout.
        //
        // Fallback: nếu cursor không ở screen nào (edge case khi disconnect
        // monitor), dùng NSScreen.main, rồi `screens.first`, rồi origin (100,100).
        let targetScreen = Self.screenContainingCursor()
            ?? NSScreen.main
            ?? NSScreen.screens.first
        let origin: NSPoint
        if let screen = targetScreen {
            let frame = screen.visibleFrame
            origin = NSPoint(
                x: frame.maxX - Self.defaultSize.width - 40,
                y: frame.maxY - Self.defaultSize.height - 40
            )
        } else {
            origin = NSPoint(x: 100, y: 100)
        }
        let rect = NSRect(origin: origin, size: Self.defaultSize)

        panel = OverlayPanel(contentRect: rect, contentView: hosting)
    }

    /// Show the panel above TFT. Safe to call when already visible (no-op orderFront).
    func show() {
        panel?.orderFrontRegardless()
        isVisible = true
    }

    /// Hide without releasing the panel instance. Next `show()` is near-instant.
    func hide() {
        panel?.orderOut(nil)
        isVisible = false
    }

    /// Idempotent toggle used by the hotkey dual-route.
    /// Tests assert 10+ consecutive calls leave state consistent (no orphan panel).
    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    /// Wave 5d helper — locate the NSScreen containing the current mouse cursor.
    ///
    /// Why: `NSScreen.main` returns the screen with the **key window** (focused),
    /// which on multi-monitor + game scenario = wrong screen (key window often
    /// is Finder on Screen B while anh chơi TFT trên Screen A). Cursor screen
    /// = where anh đang nhìn → correct screen for overlay default position.
    ///
    /// Concrete example: anh có 2 màn hình ngang. Cursor ở (1500, 400) khi
    /// anh đang play game. Screens: A = NSRect(0, 0, 1920, 1080), B = NSRect
    /// (1920, 0, 1920, 1080). NSMouseInRect((1500,400), screenA.frame) = true
    /// → returns Screen A (đúng game screen). NSScreen.main lúc đó có thể
    /// trả về Screen B nếu key window ở đó.
    static func screenContainingCursor() -> NSScreen? {
        let cursor = NSEvent.mouseLocation  // global coordinate (Cocoa: origin bottom-left)
        return NSScreen.screens.first { NSMouseInRect(cursor, $0.frame, false) }
    }
}

/// Placeholder body for Wave 5b. Wave 5c replaces with `CompListView(width: 520)`.
/// Kept deliberately minimal so Wave 5b ships isolatable — if overlay show/hide
/// breaks, the regression is in panel config, not CompCard layout.
private struct OverlayPlaceholderContent: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("TFT Hell Elo — Overlay")
                .font(.system(size: 16, weight: .semibold))
            Text("Wave 5b placeholder. Wave 5c wires CompListView.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
}
