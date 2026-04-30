# Handoff — v0.1 shipped, pending .dmg release

**Date**: 2026-04-30 17:09 ICT
**Branch**: `feat/v0.1-implementation` (clean) + `main` at `397767e` (deployed)
**Predecessor**: `handoff-260429-1520-phase4-hex-grid-pending.md`

---

## Resume command (next session)

```bash
cd "/Users/mac/Desktop/TFTTACTICS FOR MACS" && cat plans/reports/handoff-260430-1709-v0_1-shipped-pending-dmg-release.md
```

---

## Session summary (2026-04-29 → 2026-04-30)

### What shipped

**Phase 4 — Positioning Hex Grid** complete + deployed to production.

| Layer | Output |
|---|---|
| Pipeline | `positioning_aggregator.py` rule-based (Riot Set 17 doesn't expose `pos` field) — archetype classification (frontline_heavy/backline_heavy/flex) + cost-driven hex slots |
| Schema | `1.2.0 → 1.4.0` (skipping 1.3.0). `comp.positioning[]` additive |
| App | `Position.swift` model, `HexGeometry`, `HexCell`, `HexagonShape`, `HexGridView`, `PositioningSection` wrapper. Wired into `ExpandedCardView` after LV.9 Options |
| Tests | +27 new (14 pipeline + 3 emitter + 4 decoding + 5 geometry + 1 fixture invariant). All green: 204 pipeline / 138 app |
| Docs | `docs/positioning-architecture.md` new, `system-architecture.md` synced, changelog + bugs-log appended (Bug #012 = hardcoded SchemaVersion in tests) |

### Deploy ops (today)

- Pushed 9 commits → `origin/feat/v0.1-implementation`
- Opened + merged **PR #1** `feat → main` (54 commits, merge commit, branch retained)
- Re-enabled `tft-data-refresh.yml` workflow (was `disabled_manually`)
- Anh rotated Riot Dev API key → updated `.env` local + GHA secret `RIOT_API_KEY`
- Manually triggered workflow (run `25155158085`) — 21m48s, 61 comps emitted, all with positioning
- Live `data/tier-list.json` on `main` confirmed schema **1.4.0**, region VN2, 61/61 comps populated
- Anh visually verified: hex grid renders in `ExpandedCardView`, looks reasonable

### Key commits

```
397767e data: refresh tier-list.json [skip ci]            ← live data, schema 1.4.0
4b3da84 Merge pull request #1                              ← feat → main
f9e34f6 docs(phase-04): positioning hex grid sync
6249e77 test(app): bump hardcoded schema 1.2.0 → 1.4.0
1ebe40e data: refresh sample-tier-list.json to 1.4.0
248ea0b feat(app): wire PositioningSection into ExpandedCardView
ece9288 feat(app): HexGridView 4x7 board + PositioningSection
98cab8a feat(app): HexGeometry + HexCell + HexagonShape
21a686b feat(app): Position model + Comp.positioning forward-compat
22d1451 feat(pipeline): emit positioning per comp (schema 1.4.0)
50c7c76 feat(pipeline): rule-based positioning_aggregator
```

---

## Current state

- **Champions tab feature-complete** vs TFTactics Windows reference
- All 4 phases of `plans/260426-1752-tftactics-feature-parity/` shipped
- Working tree clean, both branches pushed
- Workflow live + cron 12h re-enabled — anh không cần làm gì để data tự refresh
- App auto-fetches new data on launch; existing testers (nếu có) sẽ thấy positioning sau khi quit + reopen

---

## What remains — choose at next session start

### Option A — Ship `.dmg` for 9 testers (~30-45 min)

Primary KPI path: 10 người × 3+ uses/week × 4 weeks. Steps:

1. Tag release: `git tag -a v0.1.0 -m "v0.1.0 — TFTactics feature parity (Champions tab)" && git push origin v0.1.0`
2. Production build: `xcodebuild archive -project App/TFTMac.xcodeproj -scheme TFTMac -archivePath /tmp/tftmac.xcarchive`
3. Export `.app` from archive → wrap in `.dmg` (use `create-dmg` or `hdiutil`)
4. Upload `.dmg` to GitHub Releases under tag `v0.1.0`
5. Draft release notes — Phase 1-4 highlights, Gatekeeper xattr workaround instruction (`xattr -d com.apple.quarantine TFTMac.app`)
6. Send link to 9 testers (channels TBD — Discord? direct DM?)

**Risk**: unsigned `.dmg` triggers Gatekeeper. Anh memory: "Direct .dmg unsigned trên GitHub Releases (v0.1)" — đã chấp nhận tradeoff. Documented xattr workaround essential.

### Option B — Dogfood internally first (anh tự dùng vài ngày)

Risk-averse path: anh dùng app live data vài ngày → gom self-feedback → fix bugs/polish → ship .dmg sau. Recommended nếu anh chưa tự test với data thật ngoài quick visual check hôm nay.

Watch points trong dogfood:
- Hex grid placement có convincing không? Hay có comp ngu ngu (cost-5 mage Karma đứng nhầm hàng)?
- Tier distribution `0S 0A 2B 59C` — có cảm giác "thiếu S/A" không? Có thể cần tune `tier_calculator` thresholds.
- Launch time <500ms still holds?
- Asset cache hit rate (portrait load lag?)

### Option C — Start v0.2 (chọn 1 feature)

Per phase-04 plan "After Phase 4 deferred":

| Feature | Effort | Value |
|---|---|---|
| **Traits tab** — filter comps theo trait icon | ~10-15h (1-2 weekends) | high — TFTactics có, parity feature |
| **Search tab** — tìm comp theo champion name | ~6-10h (1 weekend) | medium — convenience |
| **Native fullscreen hotkey** (Bug #002) | ~10-20h hard | high — testers đa số chơi fullscreen |
| **Multi-region** (KR/NA/EUW) | ~3-5h | low — VN2 đủ cho 9 testers VN |
| **Real positioning data** | blocked on Riot | none until Riot ships `pos` |
| **Notarization + Developer ID** | ~5-10h + $99/yr cert | medium — improve install UX, fix TCC pain |

Brainstorm session start: "anh muốn user cảm thấy gì lần thứ 5 mở app mà v0.1 chưa có?"

### Option D — Stop, viết changelog rồi nghỉ

Đã cover trong handoff này. Skip.

---

## Important context for next session

### Pending cleanup (low priority)

- **PAT rotation**: `ghp_1Zu...` từ session cũ chưa rotate. Per phase-04 plan checklist nhưng không block ship. Làm nếu tiện: https://github.com/settings/tokens → revoke + re-auth `gh auth login`.
- **Bug #002 fullscreen hotkey** — Carbon API limitation, deferred. Nếu nhiều tester báo "hotkey không work khi fullscreen game" thì priority lên cao.
- **Bug #001 TCC cdhash invalidation** — anh dev workflow biết rồi (re-grant Accessibility sau xcodebuild). Tester production .dmg không gặp vì cdhash stable. Tester chỉ cần grant 1 lần.

### Watch items if hex grid looks weird

`positioning_aggregator.py` không có per-champion trait map. Cost 5 Karma (mage backline) và Cost 5 Sett (tank frontline) cùng cost → cùng row 0 corner. Visually có thể weird. Fix path: ship `set17-champion-traits.json` mapping champion→origin/class, swap aggregator to consult map. Effort ~3-5h. Defer until anh confirm visually weird.

### Documentation entry points

- Tổng quan kiến trúc: `docs/system-architecture.md`
- Phase 4 deep-dive: `docs/positioning-architecture.md` (Mermaid + worked example "Storm Quickdraw")
- Changelog: `docs/project-changelog.md` (5 phase entries, gần nhất `[phase-04-positioning-hex-grid] — 2026-04-30`)
- Bug log: `docs/bugs-log.md` (Bug #001-#012, #012 mới nhất)
- v0.1 design spec: `docs/design-v0.1-menu-bar-popover.md`

### Repo identity

- GitHub: `psychomafia-tiger/tft-hell-elo-for-macos`
- Bundle ID: `io.psychomafia.tfthellelo`
- User-facing name: "TFT Hell Elo"
- Code target: `TFTMac` (legacy retained — XCUITest + 5+ test files reference, không rename)

### KPI reminder

Primary: 10 người (founder + 9 testers) mở app ≥3 lần/tuần × 4 tuần liền. **Retention trước, revenue sau**. Mọi tracking PostHog opt-in chưa wire (defer v0.2 nếu cần).

---

## Unresolved

1. Visual quality of positioning rules trên data thật — anh xác nhận "trông khá ổn" hôm nay nhưng chưa stress-test trên 60+ comps. Dogfood vài ngày sẽ cho dữ liệu rõ hơn.
2. Channel gửi `.dmg` cho 9 testers chưa chốt (Discord group? Email list? Direct DM?).
3. PostHog analytics wire-up vẫn deferred — chưa biết có cần cho v0.1 round dogfood hay đợi v0.2.
