# Handoff — Pipeline LIVE, next phase = TFTactics feature parity (full)

**Date**: 2026-04-26 17:42 ICT
**Branch**: `feat/v0.1-implementation` (clean, all pushed)
**Predecessor**: `handoff-260425-2335-data-pipeline-tcc-block.md`

## Status snapshot

| Subsystem | State |
|---|---|
| **Data pipeline (Riot → GHA → repo)** | ✅ LIVE — Run 24952866102 PASS in 13m17s, last commit afd565f at 09:16 UTC |
| **App network fetch** | ✅ LIVE — RemoteFetcher pulled 110KB/63 comps from raw.githubusercontent.com (verified pid 8191 17:05:58, HTTP 200 in 412ms) |
| **Repo visibility** | PUBLIC (anh approved, flipped via API to enable raw.git CDN) |
| **Cmd+Shift+T hotkey** | ✅ PASS — 4 toggles consecutive, <1ms latency |
| **App running** | pid 8191 (rendering real VN2 data but feature-incomplete vs target) |

## Decisions locked this session

1. **Full parity với TFTactics** — không ship intermediate, đi tới feature-complete trước
2. **VN2 region only** — không multi-region, sample 527 matches/cycle đủ cho VN2 dogfood
3. **Positioning hex grid = CRITICAL** — không defer, anh chơi TFT thấy position quan trọng meta
4. **Asset source TBD** — likely CommunityDragon (free CDN, có Set 17 art) vs scrape TFTactics (gray legality). Cần research trong plan phase
5. **Trait-centric comp algorithm** — replace champion-set hash với trait-combo hash để comp có semantic name ("Psionic Conduits" thay vì "Illaoi+Nami+Rhaast+...")

## Critical bugs lộ ra trong session này (đã document docs/bugs-log.md)

- **#001b** ✅ — over-defensive `AXIsProcessTrusted()` guard (Carbon hotkey không cần AX)
- **#001c** ✅ — NSLog `<private>` redaction (đổi sang `os.Logger` `.public`)
- **#004** ⏳ NEW — Pipeline metadata thiếu: `updated_at`, `match_count`, anomalies always 0. Aggregator quên populate top-level. Defer fix tới Phase 1.

## Gap analysis (TFT Hell Elo hiện tại vs TFTactics target)

### A. Data model gaps

| # | Gap | Effort |
|---|---|---|
| A1 | Champion name resolution `TFT17_xxx` → "Aatrox" (Set 17 SDK lookup) | 1-2h |
| A2 | Comp semantic name từ trait combo ("Primordian Marauders") | 2-4h |
| A3 | Trait synergies + counts (icon + "2", "4"...) | 4-6h |
| A4 | Subtype/playstyle ("Slow Roll (6)", "Fast 8") heuristic | 3-5h |
| A5 | Early comp (5 transition champs first 2-3 stages) | 4-6h |
| A6 | Carousel priority (champion pick order) | 2-3h |
| A7 | LV.9 alt champions | 2-3h |
| A8 | Positioning hex grid (board layout) | 6-8h |

### B. UI/Asset bundle gaps

| # | Gap | Effort |
|---|---|---|
| B1 | Champion portraits real PNG (placeholder generic person icon hiện) | 4-8h |
| B2 | Item icons artwork (text only hiện: "Gargoyle Stoneplate") | 4-6h |
| B3 | Trait icons | 2-3h |
| B4 | Hex grid SwiftUI component (positioning render) | 4-6h |

### C. Algorithm gaps

| # | Gap | Effort |
|---|---|---|
| C1 | No S tier (60/63 = C tier) — threshold quá strict cho 527-match sample | 1-2h tuning |
| C2 | Trait-centric comp detection (rewrite aggregator) | 6-10h |

### D. Đã có (giữ nguyên)

✅ Header (patch number, match count, "X min ago")
✅ Tier badge A/B/C colored circle
✅ Stats row (Avg X.X · Play X% · X matches)
✅ Item recommendations text format
✅ Star tier per champion slot (1/2/3 stars)
✅ Tabs Champions/Traits/Search structure
✅ Expand chevron per comp card

**Total estimate Phase 1+2+3 = ~50-65h**

## Next session entry — superpowers workflow

### Resume command

```bash
cd "/Users/mac/Desktop/TFTTACTICS FOR MACS" && cat plans/reports/handoff-260426-1742-tftactics-feature-parity-plan.md
```

### Recommended workflow (per superpowers)

1. **`superpowers:brainstorming`** — debate tradeoffs cho 5 critical decisions:
   - Asset source: CommunityDragon vs DDragon vs scrape — pick winner
   - Comp algorithm: trait-combo hash vs ML clustering — KISS vs accuracy
   - Hex grid: SwiftUI Canvas vs custom NSView vs Lottie animation
   - Single big plan vs 3 phased plans (per anh's "full parity" decision: prefer 1 plan with phases)
   - Multi-tab navigation (Champions/Traits/Search) currently stub — wire all 3 hay defer 2-3?

2. **`superpowers:writing-plans`** — create plan tại `plans/260426-NNNN-tftactics-feature-parity/` với:
   - `plan.md` overview <80 lines
   - Phase files: `phase-01-champion-resolution-and-portraits.md` (A1+B1+C1), `phase-02-trait-centric-comp.md` (A2+A3+B3+C2), `phase-03-rich-comp-details.md` (A4-A7+B2), `phase-04-positioning-hex-grid.md` (A8+B4)
   - Mỗi phase: research/, todo list, success criteria, related files
   - Manual gates trước mỗi phase (anh review trước khi proceed)

3. **`superpowers:executing-plans`** — execute từng phase, anh approve checkpoint

### Pre-plan research questions for `researcher` agent

- Set 17 (TFT 16.x patch) champion ID list + canonical names — Riot Data Dragon URL?
- CommunityDragon Set 17 asset paths (champion portraits, item icons, trait icons)
- TFTactics URL patterns + anti-scrape posture
- Best practices SwiftUI hex grid render (đã có open-source components?)

## Pending TODOs (defer hoặc parallel)

| # | Task | Where | Block? |
|---|---|---|---|
| 1 | **🔐 ROTATE PAT** (token starting `ghp_1Zu...` from session 26-04 16:00 ICT — anh paste vào chat) | https://github.com/settings/tokens | Soft (PAT chỉ active cho `gh auth`) |
| 2 | **🔐 ROTATE Riot API key** (key starting `RGAPI-3015...` — anh select trong .env, mình thấy) | https://developer.riotgames.com → regenerate dev key | Soft (Riot dev key tự rotate 24h) |
| 3 | Test 4 Schema mismatch overlay | manual | Defer — sau Phase 2 plan execute |
| 4 | Test 5 Stale cache banner | manual | Optional — non-blocking |
| 5 | Bug #004 fix: aggregator populate `updated_at` + `match_count` + anomalies | Pipeline | Defer Phase 1 plan |
| 6 | Workflow file: 12h cron sẽ tự fire 12:00/00:00 UTC, không cần manual trigger nữa | N/A | Auto |

## Repo state context

- **Default branch**: `main` (restored after dogfood detour to `feat/v0.1-implementation`)
- **Commits pushed**: 53 commits feat = main (fast-forward sync)
- **Latest commits**: 0b413a8 (workflow fix) → afd565f (data refresh by GHA)
- **Visibility**: PUBLIC
- **Secrets in repo**: `RIOT_API_KEY` (working, ngày mai rotate)

## Architecture state (unchanged from yesterday)

- 4-layer pipeline complete: Riot Match-v5 API → Python aggregator (VN2 Challenger 527 matches) → GHA cron 12h → App fetch chain
- Schema: 1.1.0 (cron output), bundled stays 1.0.0 (forward-compat decoder works)
- App: SwiftUI MenuBarExtra + DataManager `@MainActor ObservableObject` + dual-route hotkey (popover + overlay)
- Carbon hotkey via HotKey package (no AX needed — Bug #001b lesson)
- Logging: `os.Logger` subsystem `io.psychomafia.tfthellelo` category `diagnostics` với explicit `.public`

## Unresolved (for next session)

1. Set 17 champion name table — official Riot source vs CommunityDragon SDK? Need researcher
2. Asset CDN strategy — bundle in .app (offline-first) vs lazy-fetch with cache?
3. Comp tier threshold tuning — Phase 1 quick win, vẫn dùng 527 matches hay request larger sample?
4. Aggregator metadata bug #004 — fix in Phase 1 vs separate hotfix commit now
5. Rotate timing — anh muốn rotate ngay session này trước khi đóng, hay defer next session?
