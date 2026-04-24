# TFT Mac Companion v0.1 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: `superpowers:subagent-driven-development` hoặc `superpowers:executing-plans` để implement plan này task-by-task. Steps dùng checkbox `- [ ]` syntax.

**Generated**: 2026-04-24 (Weekend 0 start)
**Input spec**: `docs/product-spec-v0.1.md` (APPROVED)
**Eng review**: `plans/reports/2026-04-24-eng-review-v0.1.md` (CLEARED)
**Target ship**: Weekend 3 (2026-05-11) — founder + 3 testers
**Primary KPI**: 10 testers × ≥3 opens/tuần × 4 tuần liên tiếp

---

## Goal

Build + ship native macOS menu bar popover (cửa sổ bật lên từ thanh menu) hiển thị TFT Challenger tier list, data pipeline (ống dẫn dữ liệu) local cron refresh 12h, unsigned .dmg distribution (phát hành) cho 10 testers retention test.

## Architecture

- **App** (`App/`): SwiftUI macOS 13+ target, `MenuBarExtra` + `HotKey` Swift package, Cmd+Shift+T toggle, fetch `tier-list.json` từ Cloudflare R2 với 7-day cache fallback.
- **Pipeline** (`Pipeline/`): Python 3.11+ async script via `launchd` cron mỗi 12h, fetch Riot Match-v5 API (Dev key fallback, Production key target), comp detection (Jaccard 0.70 threshold pre-spike-tuned), R2 upload với LKG (last-known-good) fallback.
- **Distribution** (`Distribution/`): `install.sh` one-command onboarding với `xattr -cr` + `spctl --add`, manual `xcodebuild` build, GitHub Releases private repo.

## Tech Stack

- Swift 5.9+ / SwiftUI / AppKit primitives (NSStatusItem, NSPopover)
- Python 3.11+ / aiohttp / aiolimiter / boto3 (cho R2 S3 API)
- launchd plist (macOS built-in cron)
- pytest + XCTest + XCUITest
- Cloudflare R2 public bucket + GitHub Releases private

---

## Phases

| # | Phase | Duration | Status | Gate (điều kiện hoàn tất) |
|---|---|---|---|---|
| 0 | Weekend 0 pre-spike (Assignment 48h) | 2 days | pending | Production key applied, install.sh tested, Jaccard threshold locked, wireframe locked |
| 1 | Weekend 1 — App scaffold + dogfood | 2 days | blocked by 0 | Founder uses app ≥5 TFT sessions với hardcoded JSON |
| 2 | Weekend 2 — Pipeline + R2 + distribution | 2 days | blocked by 1 | Cron runs 2x without fail, app fetches R2, .dmg builds |
| 3 | Week 2 — Tests + ship v0.1.0 | 2 days | blocked by 2 | All tests pass, .dmg ships to founder + 3 testers |

## Phase Files

- [phase-00-weekend-0-pre-spike.md](./phase-00-weekend-0-pre-spike.md) — Pre-code 48h Assignment, TDD foundation algorithms
- [phase-01-weekend-1-app-scaffold.md](./phase-01-weekend-1-app-scaffold.md) — SwiftUI menu bar + hotkey + popover + hardcoded JSON render
- [phase-02-weekend-2-pipeline-distribution.md](./phase-02-weekend-2-pipeline-distribution.md) — Python pipeline + launchd + R2 + install.sh
- [phase-03-testing-ship-v0.1.md](./phase-03-testing-ship-v0.1.md) — Full test suite + .dmg + GitHub Release + tester DM

## Key Dependencies

1. **Riot API key** (founder-action): Dev key instant, Production key 1-4 weeks review. P0 blocker for Phase 2.
2. **Wireframe locked** (founder+CC): Required before Phase 1 UI code. Via `/design-consultation` → `/design-shotgun`.
3. **Comp detection threshold locked** (pre-spike): Required before Phase 2 pipeline code. Pre-spike hand-label gate trong Phase 0.
4. **Cloudflare R2 account** (founder-action): Required before Phase 2 upload. One-time 20 min setup.

## Success Criteria (từ spec launch gate)

- [ ] App .dmg ship đến founder + 3 initial testers
- [ ] 0 crash trong tuần đầu tiên
- [ ] Pipeline cron chạy mỗi 12h không fail 2 lần liên tiếp (no 24h gap)
- [ ] Founder dogfood ≥5 TFT sessions liên tiếp thay thế alt-tab Chrome

## Risk Register (top 3)

| Risk | Mitigation |
|---|---|
| Production key rejected | Dev key + regen script fallback (Phase 2 contingency) |
| Jaccard threshold miss-tunes | Pre-spike hand-label 10 groups + LKG validation gate (Phase 0 + Phase 2) |
| Mac sleep miss cron window | `pmset schedule wake` + lock file prevents concurrent runs (Phase 2) |

---

**Next action**: Start Phase 0 — execute Weekend 0 Assignment 6 action items. See `phase-00-weekend-0-pre-spike.md`.
