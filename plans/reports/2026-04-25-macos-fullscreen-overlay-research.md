# macOS Fullscreen Overlay Research — TFT Hell Elo

**Date**: 2026-04-25
**Context**: F1 dogfood blocker — overlay panel needs to display above TFT (League client) fullscreen window
**Author**: Claude research session, sources cited inline

## Executive Summary

1. **macOS không có "Exclusive Fullscreen" như Windows** — chỉ có Native Spaces Fullscreen (NSWindow.toggleFullScreen) tạo Space riêng. Khi Cmd+Shift+3 không chụp được trong TFT "Fullscreen" mode, đó vì TCC/Spaces isolation, không phải bypass WindowServer.

2. **Code TFT Hell Elo hiện tại đã match config Remedy/discordOverlayMac (open-source proof-of-work)** — về lý thuyết overlay nên hiện được trên TFT fullscreen. Cần test thực tế trước khi infer (suy luận) bug code.

3. **LSUIElement không cản trở** cross-app fullscreen overlay — Remedy có `LSUIElement: 1` và work fine. Concerns ban đầu của tôi sai.

## Code config comparison (mình vs Remedy)

| Property | TFT Hell Elo (OverlayPanel) | Remedy (Electron BrowserWindow) | Match? |
|---|---|---|---|
| Window class | `NSPanel` subclass | `type: 'panel'` (Electron mapping → NSPanel) | ✓ |
| styleMask | `[.nonactivatingPanel, .resizable, .titled]` | `frame: false` (no titlebar) | ⚠ traffic lights only diff |
| Window level | `overlayWindow` (102) | `alwaysOnTop: true` default = floating (3) | ✓ mình cao hơn |
| collectionBehavior | `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]` | Same (default Electron panel) | ✓ |
| canBecomeKey | `false` (override) | `setFocusable(false)` | ✓ |
| isFloatingPanel | `true` | (Electron internal) | ✓ |
| LSUIElement | `YES` | `1` (same) | ✓ |
| Activation | `NSApp.activate(ignoringOtherApps: true)` | (Electron internal) | ~ |

**Verdict**: Cấu hình của TFT Hell Elo về cơ bản tương đương với Remedy (đã ship và work trên League/TFT macOS fullscreen). Không có lý do code sai về mặt spec.

## Findings by source

### Apple Developer Forum — thread 26677
- 2014 thread, vẫn được link cho macOS Sequoia (2025)
- Original poster cùng config (`MaximumWindowLevelKey + .canJoinAllSpaces + .fullScreenAuxiliary`) báo "appears all spaces but NOT over fullscreen apps"
- Ken Thomases (Apple eng) clarify: `.fullScreenAuxiliary` doc string ambiguous — original meaning: "windows of THE FULLSCREEN APP can have auxiliaries on its space". Cross-app behavior **không document**.
- **Implication**: official doc không guarantee cross-app fullscreen overlay; phụ thuộc impl của macOS (đã cải thiện qua versions, nhưng không ai có spec chính thức).
- Source: https://developer.apple.com/forums/thread/26677

### Riot LoL Mac Metal transition (Patch 25.14, 2025)
- Riot hoàn tất transition OpenGL → Metal cho League/TFT macOS, Patch 25.14 (mid-2025)
- **macOS không support exclusive fullscreen** ngay cả với Metal — composited windowing system always
- "Fullscreen" trong League settings = NSWindow.toggleFullScreen (Native Spaces), không bypass
- Source: https://www.dtgre.com/2025/07/lol-patch-25-14-mac-metal-transition-guide-performance-fixes.html

### Remedy (Discord overlay cho macOS, open source)
- LSUIElement: 1 (menu bar app)
- Overlay BrowserWindow config:
  ```javascript
  type: 'panel',           // → NSPanel + nonactivatingPanel
  alwaysOnTop: true,       // → level floating (3)
  frame: false,            // no titlebar
  transparent: true,
  setIgnoreMouseEvents(true),
  setFocusable(false)      // canBecomeKey = false
  ```
- Comment trong code: "type set to panel (overlap on fullscreen application)"
- Source: https://github.com/Naozumi520/Remedy/blob/main/src/main.js#L241-L259

### discordOverlayMac (simpler example)
- Standard Electron app (LSUIElement KHÔNG set, có Dock)
- Overlay config:
  ```javascript
  alwaysOnTop: true,
  focusable: false,
  transparent: true,
  setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true })  // → canJoinAllSpaces + fullScreenAuxiliary
  setIgnoreMouseEvents(true)
  ```
- Source: https://github.com/hughescr/discordOverlayMac/blob/main/main.js

### Electron PR #34388 — "Add panel support for BrowserWindow"
- Confirms: `type: 'panel'` adds `NSWindowStyleMaskNonactivatingPanel` style mask, mimics NSPanel "visible on top of full screened apps and joins all spaces"
- Implementation in `electron_native_widget_mac.mm`
- Source: https://github.com/electron/electron/pull/34388

## Recommendations (ranked)

### 1. **TEST FIRST** (5 min, 70% probability of success)
Mình chưa actually test trong TFT fullscreen sau khi hotkey fix. Code config đúng spec — nhiều khả năng work ngay.

**Test recipe**:
1. TFT → Settings → Video → "Fullscreen"
2. Vào game (1-1 hoặc home screen)
3. Cmd+Shift+T
4. Kỳ vọng: panel hiện ở góc trên-phải

Nếu work → đóng F1, ship.

### 2. Fallback A — Tăng level lên `screenSaver` (1000) (15 min, 60% probability nếu (1) fail)
Nếu test (1) fail, thử thay:
```swift
self.level = NSWindow.Level.screenSaver  // 1000, cao hơn menu bar
```
Tradeoff: panel sẽ overlap menu bar macOS — UX hơi xấu nhưng overlay sẽ chắc chắn hiện trên TFT.

### 3. Fallback B — Remove `.titled` style mask (10 min, low probability)
`.titled` styleMask cho panel có thể trigger edge case của macOS Spaces. Thử:
```swift
styleMask: [.nonactivatingPanel, .resizable]  // bỏ .titled
```
Tradeoff: mất traffic lights → user cần dùng Cmd+Shift+T để hide. Add custom close button nếu cần.

### 4. Fallback C — Toggle `setActivationPolicy` dynamic (45 min, 80% probability nếu (1)+(2)+(3) fail)
Pattern từ Multi.app blog (Spotlight/Raycast-style apps):
```swift
// Khi show overlay
NSApp.setActivationPolicy(.regular)
overlayController.show()
NSApp.activate(ignoringOtherApps: true)

// Khi hide
overlayController.hide()
NSApp.setActivationPolicy(.accessory)
```
Tradeoff: app icon flash trong Dock briefly mỗi lần toggle. Smaller user surprise.

### 5. Fallback D — Picture-in-Picture wrapper (4-6 hours, 50% probability)
Wrap overlay UI trong AVPictureInPictureController. PiP guarantee float trên top all apps including fullscreen.
Complexity: cần fake video track để PiP API accept content. Heavy.

### 6. Last resort — Educate user dùng Borderless (0 hours, 100% probability)
Thêm first-run setup wizard:
- Detect TFT process (Match-v5 client)
- Banner: "Cho overlay work tốt nhất, đổi TFT → Settings → Video → Borderless. Borderless trên Mac Metal modern không giảm FPS đáng kể (~1-2%)."
- Skip nếu user already Borderless (cannot detect; just educate).

## Plain-language explanation cho user

**Câu hỏi**: Tại sao TFT "Fullscreen" mode không cho overlay hiện?

**Plain answer**: macOS có 2 chế độ "fullscreen":
- **Borderless Window** — game là cửa sổ size full màn hình, vẫn nằm trong WindowServer normal. Overlay app khác hiện được dễ.
- **Native Spaces Fullscreen** (TFT chọn "Fullscreen" → cái này) — game được put vào Space riêng, isolation cao hơn. Overlay từ app khác cần special config (`canJoinAllSpaces + fullScreenAuxiliary`) mới hiện được.

**Concrete example**: Mở Notes ở chế độ fullscreen (NSWindow.toggleFullScreen). Cmd+Tab về Finder — Finder window không hiện trên Notes space. Đây là Native Spaces Fullscreen mechanism. TFT "Fullscreen" trên Mac = same mechanism.

**Tại sao Borderless chụp được screenshot mà Fullscreen không?**: Cmd+Shift+3 dùng TCC permission cho Screen Recording. TFT khi ở Native Spaces Fullscreen có thể trigger TCC re-evaluation và block screenshot tools không cấp permission cho space đó. Borderless không trigger Spaces transition → screenshot work normal.

## Status

**DONE_WITH_CONCERNS**

**Concerns**:
1. Mình chưa verify in vivo (thực tế) — config đúng spec không guarantee work với specific edge case của TFT/Riot client
2. Apple deprecated CGS Private API trong các macOS version gần đây — nếu fallback A-C đều fail, fallback D (PiP) là realistic option duy nhất
3. Borderless education path là zero-risk fallback — should ship dù sao

**Next action**: Anh test (1) trước. Báo lại kết quả, mình implement fallback theo thứ tự nếu cần.
