# Handoff — post-Wave 5d, v0.1 dogfood-ready code-side

**Date**: 2026-04-25 17:24 ICT
**Branch**: `feat/v0.1-implementation` (HEAD: `03c3346`)
**Session predecessor**: `handoff-260425-1605-wave5d-hotkey-blocked.md` → RESOLVED 16:54

## TL;DR (state of the world)

- **Wave 5d closed**: hotkey + overlay work trong borderless mode ✅
- **v0.1 dogfood blocker**: SOLVED code-side. Còn unblockers ngoài code.
- **Pending decisions** (anh chốt khi resume): chọn 1-2 trong 3 paths dưới đây.
- **Tests**: 61/61 pass, build clean.
- **Branch**: chưa push remote.

## v0.1 status snapshot

| Layer | Status | Detail |
|---|---|---|
| Hotkey (Cmd+Shift+T) | ✅ live | Carbon HotKey via Accessibility TCC |
| Popover (menu bar click) | ✅ live | CompListView 440px |
| Overlay panel (borderless) | ✅ live | NSPanel level=screenSaver, 520px |
| Overlay panel (native fullscreen) | ❌ unsupported v0.1 | Exclusive capture limit, defer Phase 2 |
| TCC stable across rebuild | ❌ dev pain | Adhoc cdhash đổi mỗi build → re-grant manual |
| Distribution (.dmg + GitHub Release) | ⏸ chưa làm | Cần cho 10 testers |
| PostHog analytics opt-in | ⏸ chưa làm | KPI tracking cần |
| Install guide / Gatekeeper override docs | ⏸ chưa làm | Adhoc-sign = users phải right-click → Open |

## 3 paths cho session mới (anh chọn)

### Path A — Ship v0.1 dogfood (recommended next major)
**Why**: Code core đã work. Để hit KPI (10 testers × 3x/week × 4 weeks), cần ship sớm để bắt đầu đếm retention. Lean: ship trước, optimize sau dựa trên feedback.

**Scope** (~4-6h):
1. Build Release .dmg với create-dmg hoặc hdiutil
2. Wire PostHog free tier + consent flow (opt-in alert lần đầu launch)
3. README install guide: download, right-click→Open (Gatekeeper unsign workaround), grant Accessibility, restart
4. Borderless-only docs: 1-line trong README "v0.1 supports TFT in Borderless. Native fullscreen limitation = Phase 2"
5. GitHub Release v0.1.0 với .dmg attached
6. Distribution: 10 testers nhận via Discord/Telegram (anh chọn channel)

**Risks**: Gatekeeper friction trên first install. Cần thử với 1 tester thật trước khi blast tất cả.

### Path B — Apple Development signing setup
**Why**: Eliminate dev TCC pain (anh phải re-grant Accessibility mỗi rebuild). Free tier OK (anh confirmed có Apple Dev account free).

**Scope** (~30-60m):
1. Xcode project → Signing & Capabilities → Team dropdown → select anh's personal Apple ID team
2. Automatic signing ON, signing certificate = Apple Development
3. Rebuild → verify cdhash persistent giữa các builds (`codesign -dvv` compare)
4. Test: AXIsProcessTrusted() vẫn true sau rebuild → no re-grant needed
5. Document trong CONTRIBUTING.md hoặc dev setup guide

**Tradeoff**: Apple Development cert KHÔNG cho ship dogfood (chỉ Developer ID + notarization mới qua Gatekeeper smooth). Nên Path B chỉ giúp dev workflow, không thay Path A.

### Path C — Phase 2 fullscreen workaround research
**Why**: Nếu muốn close fullscreen gap trước dogfood (over-engineering risk).

**Scope** (~4-8h research, uncertain):
1. CGEventTap với mask CGEventTapOptions.listenOnly + Input Monitoring TCC
2. Test: có catch được Cmd+Shift+T trong native fullscreen không?
3. Fallback: NSWorkspace fullscreen-enter notification → auto-show panel (no hotkey path)

**Recommendation**: ❌ Defer. v0.1 KPI achievable với borderless-only. Đo testers usage trước khi sink time.

## My recommendation: Path A then B

1. **Path A first** (today/weekend) — ship dogfood, bắt đầu đếm retention KPI
2. **Path B parallel hoặc sau** — setup signing để dev workflow stable
3. **Path C defer** — chỉ làm nếu testers complain về fullscreen

Reasoning: anh's "iterative lean scoping" = ship trước, optimize sau. KPI = retention, không phải feature completeness.

## Key context cho fresh session

- **anh's Apple Dev account**: FREE tier (no $99/yr) — affects Path B (Development cert work, but Gatekeeper notarize cần $99)
- **OS**: macOS Tahoe 26.3.1 — TCC stricter than Sequoia
- **Naming**: user-facing = "TFT Hell Elo", code target = "TFTMac" (legacy retained, không rename)
- **Bundle ID**: `io.psychomafia.tfthellelo`
- **Repo**: not pushed remote yet (anh quyết khi nào push)
- **Memory updates 2026-04-25**: TCC cdhash pattern, TFT fullscreen capture limit (xem MEMORY.md)

## Pointers

- Design doc: `docs/design-v0.1-menu-bar-popover.md`
- Wave 5d resolution: `plans/reports/handoff-260425-1605-wave5d-hotkey-blocked.md` (RESOLVED section ở cuối)
- README target: `README.md` (root) — chưa có install guide
- Code entry: `App/TFTMac/TFTMacApp.swift` (hotkey + overlay wiring)
- Key file just edited: `App/TFTMac/Views/OverlayPanel.swift` (fullscreen limitation note in docstring)

## Resume command

```bash
cd "/Users/mac/Desktop/TFTTACTICS FOR MACS" && cat plans/reports/handoff-260425-1724-post-wave5d-state.md
```

## Unresolved (anh chốt khi resume)

1. Path A vs B vs C ưu tiên — đề nghị Path A first
2. Push branch lên GitHub khi nào? (chưa push)
3. Distribution channel cho 10 testers: Discord, Telegram, hay form đăng ký?
4. PostHog account đã setup chưa, hay cần signup mới?
