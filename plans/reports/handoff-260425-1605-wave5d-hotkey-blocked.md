# Handoff — Wave 5d hotkey bug, F1 still blocked

**Date**: 2026-04-25 16:05 ICT
**Branch**: `feat/v0.1-implementation`
**Status**: Wave 5d code committed (WIP), F1 dogfood blocker still open
**Last commit**: see HEAD; `git log -3` for context

## TL;DR

Wave 5d hotfix landed code-side (3 files, 61/61 tests pass) but **Cmd+Shift+T global hotkey không fire khi anh test live**. Menu bar icon click vẫn work — confirms app runtime healthy. Vấn đề ở Carbon HotKey registration path, không phải overlay/level/positioning. Need fresh-eyes debug session.

## What was attempted this session

| Wave | Change | Outcome |
|---|---|---|
| 5c (prior) | CompCardV2 + CompListView shared (popover 440 / overlay 520) | ✓ committed |
| 5d.1 | Remove `NSApp.activate(ignoringOtherApps:)` from hotkey closure (steal focus issue) | ✓ edit, hotkey worked once after re-grant |
| 5d.2 | Bump panel level `.overlayWindow` (102) → `.screenSaver` (1000) | ✓ test updated |
| 5d.3 | NSScreen.main → cursor screen positioning (multi-monitor) | ✓ helper `screenContainingCursor()` added |
| TCC reset | `tccutil reset Accessibility io.psychomafia.tfthellelo` | ✓ done, anh re-add but hotkey still doesn't fire |

## Current bug state (live test)

- ✓ App launches OK (PID confirmed)
- ✓ Menu bar icon click → popover hiện CompListView width 440 đúng
- ❌ **Cmd+Shift+T không fire** — không show overlay panel ở desktop
- ❌ Không test được in-game vì hotkey chưa work

## Repro

1. `pkill -9 -x TFTMac; open -b io.psychomafia.tfthellelo`
2. Verify TFTMac trong System Settings → Privacy → Accessibility (toggle ON)
3. Bấm Cmd+Shift+T ở desktop — kỳ vọng panel hiện top-right cursor screen
4. **Actual**: nothing happens, no panel, no signpost trong unified log

## Hypotheses (priority order)

### H1: HotKey package callback never invoked despite register success (60% likely)
- `register()` returns `.success` (anh không thấy "permission denied" / "conflict" NSLog)
- But callback closure `overlayController.toggle()` doesn't fire when key pressed
- **Diagnostic**: add NSLog inside the closure on first line to confirm fire
- **Possible cause**: HotKey package (https://github.com/soffes/HotKey) Carbon EventHotKeyHandler binding may break when app activation policy = `.accessory` + no `NSApp.activate` in closure — Carbon RunLoop source might require app active state to dispatch events

### H2: TCC entry technically present but functionally invalid (25% likely)
- Adhoc signing: each `xcodebuild` rebuild = different bundle hash
- macOS Sequoia (anh's OS) tightened TCC validation — entry from prior signature may not authorize new binary even with same bundle ID
- **Diagnostic**: `codesign -dv --extract-certificates - app/path 2>&1` then check TCC.db for entry (`sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db "select * from access where service='kTCCServiceAccessibility'"`)
- **Workaround**: sign with stable Developer ID (anh có team `psychomafia-tiger`?), or use `codesign --force --sign - --identifier io.psychomafia.tfthellelo` with persistent identifier

### H3: HotKey package broken on macOS Sequoia (15% likely)
- HotKey package last released ~2022
- macOS 14+/Sequoia changed Carbon event dispatch
- **Diagnostic**: repro với standalone HotKey demo app
- **Workaround**: switch to KeyboardShortcuts package (https://github.com/sindresorhus/KeyboardShortcuts) — actively maintained, modern API

## Key files (touched this session, all committed in next)

```
App/TFTMac/TFTMacApp.swift                     # hotkey closure simplified, no NSApp.activate
App/TFTMac/Views/OverlayPanel.swift            # level=.screenSaver
App/TFTMac/Views/OverlayWindowController.swift # cursor screen positioning + helper
App/TFTMacTests/OverlayPanelConfigTests.swift  # test renamed for screenSaver level
App/TFTMac/Services/HotkeyRegistrar.swift      # UNCHANGED — diagnose first
plans/reports/2026-04-25-macos-fullscreen-overlay-research.md  # research from earlier
```

## Recommended next session approach (15-30 min plan)

### Step 1: Add diagnostic NSLog (5 min)
```swift
// TFTMacApp.swift, inside hotkey register closure FIRST line:
NSLog("TFT Hell Elo: Hotkey FIRED — toggle overlay")
```
Rebuild, relaunch, bấm Cmd+Shift+T, check Console.app filter "TFT Hell Elo".
- Log appears → H2 issue (panel show fails despite hotkey fire) — debug OverlayWindowController.show()
- Log NOT appears → H1 issue (Carbon binding broken) — investigate HotKey package

### Step 2: If H1 confirmed — switch to KeyboardShortcuts package (20 min)
```
Package.swift: replace HotKey với https://github.com/sindresorhus/KeyboardShortcuts (maintained 2025)
HotkeyRegistrar.swift: rewrite defaultRegister() to use KeyboardShortcuts.Name.tftToggle
```

### Step 3: If H2 confirmed — install Developer ID stable signing (30 min)
- Anh có Apple Developer account chưa? Bundle ID `io.psychomafia.tfthellelo` matches owner `psychomafia-tiger`
- Without ID: workaround = `codesign --force --deep --sign - --options runtime` với `--identifier` flag để pin identity hash

### Step 4: Verify in TFT (5 min)
After hotkey work in desktop, anh test 2 scenarios:
- Borderless: panel đè lên TFT, không steal focus
- Fullscreen: panel hiện trên TFT Space

## Resume command

```bash
cd "/Users/mac/Desktop/TFTTACTICS FOR MACS" && cat plans/reports/handoff-260425-1605-wave5d-hotkey-blocked.md
```

## Anh's answers (từ session 2026-04-25 16:11)

1. **Apple Dev account**: CÓ — nhưng FREE tier (không trả phí). Implication: codesign với personal team OK nhưng binary expires sau 7 days dev-side; cho 10 testers dogfood phải hoặc (a) upgrade paid $99/year để notarize + stable identity, hoặc (b) ship adhoc + instruct user override Gatekeeper qua right-click → Open.
2. **macOS**: **Tahoe 26.3.1** — bản mới hơn Sonoma 14 / Sequoia 15. TCC behavior trên Tahoe có thể stricter (Apple thường tighten privacy mỗi major). Pre-existing `tccutil reset` workflow vẫn work; nhưng adhoc-signing TCC entry có thể invalidate aggressive hơn — cần test xác minh.
3. **Hotkey conflict**: Rectangle.app duy nhất đang chạy (verified via `ps aux`). Default Rectangle KHÔNG bind Cmd+Shift+T (default shortcuts dùng Ctrl+Option) nhưng anh có thể custom. **Diagnostic**: open Rectangle → Preferences → check shortcuts list cho Cmd+Shift+T. Nếu có conflict → rebind Rectangle hoặc đổi TFT Hell Elo hotkey sang Cmd+Option+T.

## Unresolved (nguyên nhân chưa rõ)

1. HotKey package version trong Package.resolved — may need bump cho Tahoe 26.3.1 compat
2. Carbon Hot Key API behavior trên macOS Tahoe — có thể đã deprecated tighten
