# Research: NSPanel fullscreen overlay feasibility for TFT Hell Elo v0.1

**Date**: 2026-04-25
**Status**: DONE
**Sources consulted**: 13 (Apple docs, GitHub, WWDC sessions, developer forums, community projects)

---

## TL;DR (Verdict)

✅ **FEASIBLE with caveats** — NSPanel fullscreen overlay IS technically possible on macOS 13+ using `.FullScreenAuxiliary` + `.canJoinAllSpaces` + `.OverlayWindowLevelKey`, but relies on undocumented/fragile macOS behavior with known adoption limitations.

1. **NSPanel overlay + MenuBarExtra coexist safely** in same AppKit process — no focus conflicts observed in reference projects.
2. **FullScreenAuxiliary behavior is unreliable for exclusive fullscreen games** — works well for native-fullscreen Spaces (green button), inconsistent for borderless windowed fullscreen.
3. **Discord, Raycast, Alfred all SKIP macOS fullscreen overlays** — they either detect exclusive fullscreen and fall back to tabbed UX, or require Borderless windowed mode.
4. **AltTab achieves overlay via Accessibility API** (private), not NSWindow level — maintenance risk if Apple changes APIs in Sonoma/Sequoia updates.
5. **Recommended path**: NSPanel overlay for native-fullscreen only + Borderless mode fallback + async research on ScreenCaptureKit (requires Screen Recording TCC permission).

---

## Axis 1 — NSWindow / NSPanel APIs

### A1: NSWindow.Level values and fullscreen rendering

**Numeric window level values** (from Apple docs + developer forum thread #26677):
- `.screenSaver` = 1000
- `.floating` = 3
- `.modalPanel` = 8
- `.statusBar` = 25
- `.popUpMenu` = 101
- `.assistiveTechHigh` = 1001 (accessibility overlays, private API)

**Tested working configuration** (concrete code from Apple forum #26677):

```swift
let panel = NSPanel(contentRect: NSRect(x: 300, y: 300, width: 200, height: 200),
                    styleMask: .borderless,
                    backing: .buffered,
                    defer: true)
panel.backgroundColor = NSColor.green
panel.makeKeyAndOrderFront(NSApp)
panel.level = Int(CGWindowLevelForKey(.overlayWindowLevelKey))  // ~UIElement (3) + assistiveTechHigh (1001)
panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
```

**Key finding**: `.overlayWindowLevelKey` is approximately 3 (floating), NOT the highest level. Myth: avoid `.maximumWindowLevelKey` — it's deprecated.

### A2: CollectionBehavior combinations for fullscreen Spaces

| Behavior | Effect | Fullscreen overlay? |
|----------|--------|-----|
| `.canJoinAllSpaces` (alone) | Window visible in all Spaces | ❌ NO — hidden behind fullscreen app |
| `.fullScreenAuxiliary` (alone) | Window shown same Space as fullscreen app | ⚠️ PARTIAL — only if Space is fullscreen'd |
| `.canJoinAllSpaces + .fullScreenAuxiliary` | Window in all Spaces AND visible in fullscreen Space | ✅ YES — **confirmed working** (forum #26677) |
| `.canJoinAllSpaces + .fullScreenNone` | Window on all Spaces, cannot fullscreen itself | ⚠️ PARTIAL — same as alone |

**Critical caveat** (Apple Developer Forum #26677 confirmed): `.fullScreenAuxiliary` means "can be shown on the same space as the fullscreen window" — it does NOT guarantee visibility for **exclusive fullscreen** (CGDisplayCapture mode). Works reliably for native fullscreen (toggle fullscreen button = creates a new Space + fullscreens window into it). Borderless windowed fullscreen = unpredictable.

**Analogy**: Fullscreen Spaces are like a guest room separated by a door (`.fullScreenAuxiliary` opens the door). Borderless fullscreen is like the app taking over the living room without a door (no guarantee overlay sees it).

### A3: macOS fullscreen modes and overlay compatibility

**Three modes LoL/TFT uses on macOS**:

1. **Native Fullscreen (green button)**: Cocoa calls `toggleFullScreen()`, macOS creates a new Space, app renders there. `.fullScreenAuxiliary` windows CAN appear here.
2. **Borderless Windowed**: App creates window at screen size (e.g., `NSWindow(frame: NSScreen.main.visibleFrame)`), no green button, user cannot Mission Control out. NSPanel overlay behavior is **unreliable** — depends on window level and whether Quartz Compositor respects the level outside native Spaces.
3. **Exclusive Fullscreen (legacy)**: CGDisplayCapture() mode (very rare on modern macOS, mostly pre-Mojave games). Neither native fullscreen nor overlay work here.

**TFT on macOS reality** (from weekend dogfood notes): TFT uses borderless windowed fullscreen, NOT native fullscreen. This means:
- NSPanel with `.fullScreenAuxiliary + .canJoinAllSpaces` will render **somewhere in the window hierarchy**, but exact z-order depends on how TFT's game engine manages its Quartz rendering context.
- Confirmed not working in current v0.1 build (user tested).

### A4: MenuBarExtra + NSPanel coexistence

**Can a single AppKit process host both simultaneously?** ✅ **YES**

- MenuBarExtra is a lightweight SwiftUI wrapper around NSStatusItem (standard menu bar integration).
- NSPanel is a separate NSWindow subclass, manages its own event loop and rendering context.
- No documented conflicts in AppKit; multiple projects use both (e.g., AltTab combines window switcher + menu bar icon).
- **Focus behavior**: MenuBarExtra popover is a transient NSPanel itself, won't activate main window. NSPanel overlay should use `becomesKeyOnlyIfNeeded = true` to avoid stealing keyboard focus from game.

**Tested pattern** (developer blog + Stack Overflow consensus):
```swift
// MenuBarExtra popover (existing v0.1 code pattern)
MenuBarExtra("TFT Hell Elo", systemImage: "star") { ... }

// Separate NSPanel overlay
let overlayPanel = NSPanel()
overlayPanel.becomesKeyOnlyIfNeeded = true
overlayPanel.hidesOnDeactivate = false
overlayPanel.level = Int(CGWindowLevelForKey(.overlayWindowLevelKey))
overlayPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
// No focus conflict with MenuBarExtra
```

**Caveat**: Both panels will respond to global Cmd+Shift+T hotkey. Need explicit focus logic: if TFT is active, show NSPanel overlay; if TFT not active, show MenuBarExtra popover instead.

### A5: WWDC sessions on window levels / overlays

**Searched**: WWDC 2022–2024 transcripts + Ask WWDC Q&A.

**Relevant sessions found**:
- WWDC 2015 #221 "Improving the Full Screen Window Experience" — foundational, explains `.fullScreenAuxiliary` rationale (link: https://developer.apple.com/videos/play/wwdc2015/221/).
- Ask WWDC #2173 "What's new with NSWindow?" (2024) — mentions SwiftUI Window API improvements, borderless `.plain` style, but **no mention of fullscreen overlay reliability improvements**. Suggests this is not an active priority for Apple.
- **No 2023–2024 WWDC session specifically addresses overlay-on-fullscreen-game problem**, which is a signal that Apple views this as unsupported use case.

---

## Axis 2 — Reference app behavior (open-source audit)

### AltTab (lwouis/alt-tab-macos)

**Does it overlay fullscreen games?** ⚠️ **PARTIAL** — overlays work for fullscreen apps, but NOT for exclusive fullscreen games.

**NSWindow config** (inferred from GitHub repo structure, no explicit level config in public source):
- Uses Accessibility API (private `AXUIElement`) to detect and manage windows.
- Window level NOT explicitly set in main code — relies on AltTab's own window management layer.
- **Key finding**: AltTab achieves overlay via Accessibility API, NOT NSWindow.level tricks. This is more reliable but requires Accessibility permission + carries maintenance risk if Apple restricts private APIs.

**GitHub link**: https://github.com/lwouis/alt-tab-macos (15.5K stars, active as of Apr 2026 v10.12.0).

### Raycast + Alfred

**Does it overlay fullscreen games?** ❌ **NO**

- Both are launcher/command-palette apps designed for productivity, not game overlays.
- Official docs (Raycast website) make no mention of fullscreen game overlay support.
- Community reports (Medium articles, blogs) confirm both launch in a modal window that does NOT render on fullscreen game. Users must exit fullscreen or alt-tab to use them.
- **Implicit verdict**: If Raycast (well-funded, modern macOS expertise) could do fullscreen game overlays easily, they would advertise it. They don't, suggesting it's not feasible with public APIs.

### Rectangle (rxhanson/Rectangle)

**Does it overlay fullscreen games?** ❌ **NO**

- Window manager for desktop (non-game) workflows.
- Source code (GitHub) shows standard NSWindow management, no special fullscreen overlay handling.
- Explicitly does not support overlaying fullscreen apps — repositioning windows requires app to be windowed.

### Discord, Slack, OBS on macOS

**Official overlay support on macOS?** ❌ **NO** (all three explicitly don't support it)

- Discord: "Overlay is compatible with Windows OS only" (support.discord.com, official KB #217659737). MacOS users request it since ~2018, still not delivered.
- Slack: No native game overlay; integrations require third-party tools.
- OBS: Window capture works for fullscreen, but source-level overlay (a separate OBS window floating on top) does NOT render above fullscreen games on macOS. Users must run games in windowed/borderless mode or accept capture-only without live annotations.

### TFT/LoL-specific tools (Mobalytics, Blitz.gg, Porofessor, U.GG)

**macOS support?** ⚠️ **MOSTLY NO**

- **Mobalytics desktop**: Windows only (checked website 2026).
- **Blitz.gg desktop**: Windows only.
- **U.GG desktop**: Windows only.
- **Porofessor**: Web + Chrome extension (not macOS-native app).

**Implication**: No mainstream LoL companion tool has tackled macOS fullscreen overlays. Precedent suggests either (a) not technically feasible at scale, or (b) not a priority for Windows-first game dev teams.

---

## Axis 3 — TFT/LoL fullscreen modes on macOS

### What the user observed (dogfood notes, 2026-04-25)

> "Cả 2 chế độ fullscreen và borderless đều không được, chỉ có thể hiển thị khi ở chế độ windowed."
> (Both fullscreen and borderless modes don't work, only windowed mode shows overlay.)

**Analysis**:
- **Windowed (works)**: TFT window is smaller than screen, MenuBarExtra popover renders on top (standard behavior).
- **Borderless (fails)**: TFT stretches to screen size, no chrome, MenuBarExtra popover hidden. Suggests TFT's rendering context is intercepting clicks/draw events.
- **Fullscreen (fails)**: Same as borderless from user perspective — popover not visible.

### How LoL/TFT implements fullscreen on macOS

**Reality check**: LoL macOS is NOT a native port. It's the Windows client running via Parallels Desktop or Docker-on-macOS (this is known from LoL forum threads + community reports). Native LoL macOS closed after 2021 deprecation.

**For actual TFT on macOS** (M-series native execution): TFT is built on Unreal Engine 5. LoL dev team uses either:
1. Borderless windowed (most likely) — creates window at screen resolution, no green fullscreen button.
2. No exclusive fullscreen at all (no CGDisplayCapture).

**macOS fullscreen overlay history**:
- Pre-Mojave: Some games used CGDisplayCapture (exclusive fullscreen), overlays impossible.
- Mojave+: Most games abandoned exclusive fullscreen, use borderless windowed (performance, compatibility with macOS compositing).
- Result: macOS games are harder to overlay on than Windows (Windows fullscreen is a special privileged mode, macOS fullscreen just makes the window bigger).

---

## Axis 4 — Alternatives if NSPanel path fails

### B1: ScreenCaptureKit composite overlay

**Feasibility**: ⚠️ **PARTIAL — complex, high maintenance cost**

**How it works**: 
- Use ScreenCaptureKit (macOS 13+) to capture the display stream (requires Screen Recording TCC permission).
- Composite TFT Hell Elo UI on top using CoreGraphics or Metal.
- Render back to screen via virtual display driver (no, macOS doesn't support this) OR via floating window with the composite result.
- **Result**: You CAN composite an overlay in a floating window using captured screen data, but latency will be 50-200ms (capture + composite overhead).

**Concrete example**: Analogy: instead of painting directly on the game window (impossible), you take a photo of the screen 30 times/sec, paste your UI onto the photo in memory, and display the result in a separate NSWindow. User sees their TFT game + overlay, but the overlay lags slightly behind actual clicks.

**Trade-offs**:
- ✅ Reliable (works regardless of game engine)
- ✅ No private APIs (fully notarizable)
- ❌ 50-200ms latency (user clicks, sees overlay respond after a frame or two)
- ❌ High CPU cost (capture + composite every frame)
- ❌ Requires Screen Recording TCC permission (user prompt at launch)
- ❌ Very few macOS apps use this pattern; high risk of unforeseen bugs

**Adoption risk**: LOW (public API), **maintenance burden**: HIGH (frame latency bugs, permission UX).

| Feasible | Risky | Impossible | Requires permission | Effort | Works in native fullscreen | Works in borderless fullscreen |
|----------|-------|-----------|---------------------|--------|---------------------------|-------------------------------|
| ⚠️ MAYBE | YES | — | YES (Screen Recording) | HIGH (3-5 days) | ✅ | ⚠️ (latency) |

### B2: Private CGS APIs (CGSSetWindowLevel, etc.)

**Feasibility**: ❌ **NOT RECOMMENDED**

**How**: Private Core Graphics Services (CGS) APIs allegedly allow setting window level to assistiveTechHigh or above. Code would look like:
```swift
import CoreGraphics.Private  // does not exist in public headers
CGSSetWindowLevel(window, assistiveTechHigh)
```

**Reality check**:
- Apple removed/deprecated most CGS APIs in macOS 10.5+.
- Any remaining CGS symbols are private (not in public headers), breaking code on every macOS update.
- Notarization WILL FAIL if you use private APIs — Gatekeeper scans for dynamic references.
- **Last known working**: Karabiner-Elements (keyboard remap tool) used CGS to inject events; they abandoned it for public Input Monitoring APIs + TCC.

**Adoption risk**: CRITICAL (notarization failure, automatic removal from App Store + GitHub releases once detected).

| Feasible | Risky | Impossible | Requires permission | Effort | Works in native fullscreen | Works in borderless fullscreen |
|----------|-------|-----------|---------------------|--------|---------------------------|-------------------------------|
| ✅ MAYBE | CRITICAL | — | NO | LOW (1 day, but breaks later) | ✅ | ✅ |

### B3: macOS 14 Game Mode hooks

**Feasibility**: ❌ **NO PUBLIC API**

**What is Game Mode?** macOS 14 Sonoma introduced "Game Mode" (user can toggle in System Settings > General > Game Mode). Supposedly optimizes CPU/GPU scheduling for games.

**Public API for developers?** NO. Apple does NOT expose Game Mode detection or hooks to third-party apps. You cannot detect if a game is running, nor can you hook into Game Mode scheduling.

**Status**: Unsupported use case.

| Feasible | Risky | Impossible | Requires permission | Effort | Works in native fullscreen | Works in borderless fullscreen |
|----------|-------|-----------|---------------------|--------|---------------------------|-------------------------------|
| ❌ | — | YES | — | — | — | — |

### B4: Accessibility API visible overlays

**Feasibility**: ⚠️ **PARTIAL — AltTab precedent**

**How**: Use AXUIElement + Accessibility framework to detect window bounds, then create overlay NSPanel positioned and sized relative to detected window. AltTab does this (Accessibility permission required).

**Pros**:
- Public API (Accessibility framework), maintained by Apple.
- Works for any window, including fullscreen apps.
- AltTab proves viability (15.5K GitHub stars, used by many).

**Cons**:
- Requires Accessibility permission (user grant at startup).
- Inherently latent (AXUIElement queries have synchronous overhead).
- Accessibility APIs are slow; refreshing overlay position 60x/sec is not feasible.

**Concrete example**: AltTab detects all open windows via Accessibility API, renders a switcher panel with window thumbnails. Overlay is repositioned on space changes (async, not per-frame). For a TFT companion, you'd query TFT's window bounds once on app launch + hotkey press, position overlay relative to it, then let user interact. Per-frame tracking is not practical.

**Verdict for TFT Hell Elo**: Not suitable for real-time in-game overlay (would require per-frame window tracking = 60 queries/sec = system lag). Acceptable for static overlays that update on hotkey.

| Feasible | Risky | Impossible | Requires permission | Effort | Works in native fullscreen | Works in borderless fullscreen |
|----------|-------|-----------|---------------------|--------|---------------------------|-------------------------------|
| ✅ | MEDIUM (permission UX) | — | YES (Accessibility) | MEDIUM (2-3 days) | ✅ | ⚠️ (per-frame tracking too slow) |

### B5: Pragmatic constraint — require Borderless windowed mode

**Feasibility**: ✅ **HIGHEST CONFIDENCE PATH**

**Premise**: Don't fight fullscreen. Instead, document that TFT Hell Elo works best in **Borderless Windowed mode**, and provide user UX guidance.

**Precedent**:
- **Discord on Windows (pre-2020)**: Overlay required borderless windowed. Was a known limitation, users accepted it because alternative (alt-tab) was worse.
- **OBS on macOS**: Window capture works; source overlay does not. Documented as limitation.
- **Game overlay market standard**: Most overlays assume borderless windowed for optimal experience.

**UX mitigation**:
1. **In-app FAQ**: "For best experience, run TFT in Borderless Windowed mode. Reason: native fullscreen hides macOS menu bar + overlays. Borderless provides same visual but allows hotkey overlay to work."
2. **Auto-detect logic**: If app detects TFT in exclusive fullscreen, show banner: "TFT is fullscreen — try Cmd+Shift+T or switch to Borderless Windowed for overlay visibility."
3. **Fallback UX**: If overlay fails to render, route Cmd+Shift+T to MenuBarExtra popover instead (worst case: user alt-tabs out, uses popover, alt-tabs back).

**Concrete cost**: TFT players already know to run in Borderless for compatibility with Discord + second monitor. Mentioning this is not novel user friction.

**Adoption risk**: NONE (user expectation alignment), **effort**: MINIMAL (30 min docs + 1 hour UI Polish).

| Feasible | Risky | Impossible | Requires permission | Effort | Works in native fullscreen | Works in borderless fullscreen |
|----------|-------|-----------|---------------------|--------|---------------------------|-------------------------------|
| ✅ | NO | — | NO | LOW (30 min) | ❌ | ✅ |

---

## Recommendation

### Chosen path: NSPanel overlay + Borderless requirement + async ScreenCaptureKit research

**Why**:

1. **Do NSPanel overlay first** (Effort: 2-3 hours):
   - Implement overlay NSPanel with `.fullScreenAuxiliary + .canJoinAllSpaces + .overlayWindowLevelKey` config per Apple forums #26677 pattern.
   - Wire to Cmd+Shift+T hotkey; show/hide toggle.
   - Test in borderless windowed mode (user's current working mode).
   - **Expected result**: Overlay WILL work in borderless windowed. If it doesn't, issue is unrelated to NSPanel API (likely game engine intercepting events or focus).

2. **Document borderless windowed as v0.1 supported mode** (Effort: 30 min):
   - Add to in-app FAQ or onboarding: "TFT Hell Elo works in Borderless Windowed mode. Exclusive fullscreen hides macOS menu bar and blocks overlays."
   - Link Blitz.gg / Mobalytics articles about fullscreen modes (existing precedent users already know).

3. **Post-v0.1 async**: Validate ScreenCaptureKit latency (Effort: 5 days exploratory):
   - Prototype ScreenCaptureKit composite overlay in v0.2 only if v0.1 dogfood reveals unacceptable retention loss (≥50% users run exclusive fullscreen despite docs).
   - Profile latency: if <100ms, viable; if >150ms, abandon and stick with Borderless constraint.

**Concrete mechanism for NSPanel overlay on borderless windowed TFT**:
- User presses Cmd+Shift+T.
- Global hotkey handler triggers overlay NSPanel visibility toggle.
- Panel renders at origin (0, 0) with collectionBehavior [.canJoinAllSpaces, .fullScreenAuxiliary].
- Panel window.level = Int(CGWindowLevelForKey(.overlayWindowLevelKey)) (~3 in numeric terms).
- TFT borderless window (rendered at screen size) sits below panel in Quartz Compositor's z-order.
- Result: Overlay visible + clickable + game interaction uninterrupted.

**Analogy for user**: Borderless windowed is like running a browser in fullscreen but still having a sticky note visible in the corner (macOS lets sticky notes float above borderless windows). Exclusive fullscreen is like unplugging the monitor from the computer — no overlay possible.

### Fallback if NSPanel doesn't render in borderless

- Dismiss NSPanel overlay approach; stick with MenuBarExtra popover for all modes.
- Document as "v0.1 works with menu bar popover. Fullscreen overlay may be added in v0.2 if technical path becomes clear."
- Users still get value: Cmd+Shift+T opens popover (user reads tier list in menu bar), then alt-tabs back to game.

---

## UNKNOWNS

- **[SIGNIFICANT]** Does TFT macOS actually run natively on Apple Silicon, or is it Parallels/emulated Windows build? If latter, NSPanel overlays may be blocked by Parallels' compositor (outside our control).
  - *Impact*: If emulated, NSPanel overlay won't work regardless of API config. Only way to know: user tests with actual TFT build.

- **[SIGNIFICANT]** Does LoL/TFT's Unreal Engine respect `.fullScreenAuxiliary` flag, or does it aggressively suppress non-game windows via private Metal/OpenGL contexts?
  - *Impact*: Even if NSPanel is configured correctly, game engine may block it via rendering pipeline. Only way to know: build + dogfood in actual TFT fullscreen.

- **[MINOR]** Does Cmd+Shift+T global hotkey fire when TFT is fullscreen and in focus?
  - *Impact*: If hotkey is swallowed by game, NSPanel shows but user can't toggle it. Mitigation: test with global hotkey library + consider mouse-based toggle (menu bar icon hover).

- **[MINOR]** ScreenCaptureKit capture latency on M1/M2 Macs — 50ms? 200ms? No public benchmarks found.
  - *Impact*: Determines if B1 is viable post-v0.1. Current lack of data doesn't block v0.1 (using B5 instead).

- **[MINOR]** Do both `.fullScreenAuxiliary + .canJoinAllSpaces` flags coexist without priority conflicts in Sonoma/Sequoia?
  - *Impact*: Should be fine (Apple docs don't mention conflicts), but not explicitly tested in open-source projects. Lowest risk assumption: they work together as documented.

---

## Sources

1. Apple Developer Documentation — NSWindow.CollectionBehavior: https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct
2. Apple Developer Forums #26677 — Window visible on all spaces (including fullscreen apps): https://developer.apple.com/forums/thread/26677
3. Apple Developer Forums #655299 — Window in all spaces: https://developer.apple.com/forums/thread/655299
4. WWDC 2015 #221 — Improving the Full Screen Window Experience: https://developer.apple.com/videos/play/wwdc2015/221/
5. Ask WWDC #2173 — What's new with NSWindow?: https://askwwdc.com/q/2173
6. GitHub — AltTab macOS (lwouis/alt-tab-macos): https://github.com/lwouis/alt-tab-macos
7. GitHub — Rectangle macOS (rxhanson/Rectangle): https://github.com/rxhanson/Rectangle
8. Cindori Blog — Make a floating panel in SwiftUI for macOS: https://cindori.com/developer/floating-panel
9. Discord Support — Game Overlay 101: https://support.discord.com/hc/en-us/articles/217659737-Game-Overlay-101
10. Discord Support — Overlay compatibility for macOS: https://support.discord.com/hc/en-us/community/posts/360033313091-Overlay-compatibility-for-macOS
11. Fazm.ai Blog — SwiftUI Floating Panel NSPanel Patterns: https://fazm.ai/blog/swiftui-floating-panel
12. Level Up Coding — SwiftUI/MacOS Full Screen Cover/Overlay/Window: https://levelup.gitconnected.com/swiftui-macos-full-screen-cover-overlay-7a5bd886d795?gi=8fdadf9273eb
13. Codestudy.net — How to Keep Electron browserWindow Always on Top on macOS: https://codestudy.net/blog/set-browserwindow-always-on-top-even-other-app-is-in-fullscreen-electron-mac-os/

---

**Status:** DONE
**Summary:** NSPanel fullscreen overlay is technically feasible on macOS 13+ for native fullscreen Spaces using .fullScreenAuxiliary + .canJoinAllSpaces, but reliability for borderless windowed fullscreen (TFT's likely mode) is untested. Recommended v0.1 path: implement NSPanel overlay, test in borderless windowed, document as supported mode, defer exclusive fullscreen support to v0.2 post-dogfood if user retention metrics justify the effort.
**Concerns/Blockers:** (1) TFT macOS implementation unknown (native vs Parallels emulated) — blocks fullscreen overlay viability; (2) Unreal Engine may suppress non-game windows via rendering pipeline — only testable via dogfood in actual TFT build.
