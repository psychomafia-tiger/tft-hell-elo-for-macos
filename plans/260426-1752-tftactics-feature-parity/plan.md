# TFTactics Feature Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring TFT Hell Elo to feature parity with TFTactics Windows reference — real champion portraits, trait-centric comp identification with semantic names, rich playstyle/early-comp/carousel details, and positioning hex grid. Ship Champions tab complete; defer Traits/Search tabs to v0.2.

**Architecture:** Two-tier change. (1) **Pipeline** (Python, `Pipeline/src/tftmac_pipeline/`) — rewrite comp signature from champion-set hash to trait-combo hash, extract per-champion positions and items more aggressively, populate `updated_at`/`match_count` metadata. (2) **App** (Swift, `App/TFTMac/`) — add `ChampionDB`/`TraitDB`/`ItemDB` lookup modules backed by CommunityDragon CDN with on-disk cache, swap placeholder UI to real artwork, add `TraitChip` + `HexGrid` SwiftUI components. Schema bumps `1.1.0 → 1.2.0` (forward-compat decoder retained).

**Tech Stack:** SwiftUI native (Canvas for hex grid), URLSession + FileManager (asset cache), Python 3.11 (Riot Match-v5 aggregator), CommunityDragon CDN (free, Set 17 assets), `os.Logger` (`io.psychomafia.tfthellelo`).

---

## Phase Summary

| # | Phase | Files | Effort | Status |
|---|---|---|---|---|
| 1 | [Champion resolution + portraits + tier tuning](phase-01-champion-resolution-and-portraits.md) | A1, B1, C1 | 7-12h | ⏳ Ready |
| 2 | [Trait-centric comp identification](phase-02-trait-centric-comp.md) | A2, A3, B3, C2 | 14-23h | ⏳ Blocked by Phase 1 |
| 3 | [Rich comp details](phase-03-rich-comp-details.md) | A4-A7, B2 | 15-23h | ⏳ Blocked by Phase 2 |
| 4 | [Positioning hex grid](phase-04-positioning-hex-grid.md) | A8, B4 | 10-14h | ⏳ Blocked by Phase 3 |

Total estimate: **46-72h** (~6-9 working days). Manual gate (anh review) required between every phase.

## Locked Decisions (no re-debate)

1. **Asset CDN** = CommunityDragon (`raw.communitydragon.org/latest/...`). Free, Set 17 art available, no scrape gray zone.
2. **Comp algorithm** = trait-combo signature hash. KISS over ML clustering for 527-match sample.
3. **Hex grid render** = SwiftUI `Canvas`. Native, no extra dep.
4. **v0.1 tab scope** = Champions only. Traits + Search defer v0.2.
5. **Region** = VN2 only (per anh's dogfood scope).

## Cross-Phase Constraints

- **Schema versioning** — pipeline bumps `1.2.0` when Phase 2 lands (trait combo + name fields). App `SchemaCompatibilityGate` updated to accept both `1.1.0` (forward-compat) and `1.2.0`.
- **Bundled fixture** (`Resources/sample-tier-list.json`) refreshed once per phase to match new schema; existing TDD tests must continue green.
- **Disk cache** — single `URLCache`-backed shared `AssetCache` service in `Services/`, used by all asset views. TTL 30 days, max 50MB.
- **No Augment work** — Set 17 has Anomaly mechanic, not Augments. `Anomaly` model already exists (Phase 03 of prior plan); reuse, do not re-spec.

## Success Criteria (full plan)

- All 60+ comps in `tier-list.json` show real champion portraits (not placeholder circles).
- Comp names are semantic ("Psionic Conduits", "Dominator Marksmen") not concat ("Illaoi + Nami + ...").
- Trait chips with icons + active counts visible per comp.
- ≥1 comp tier-S after Phase 1 threshold tuning.
- Positioning hex grid renders for top-3 S/A tier comps with correct hex coordinates.
- App launch <500ms p95 retained (no regression).
- Bundle size <8MB retained (assets lazy-fetch, not bundled).

## Pending Cleanup (track in last phase)

- 🔐 Rotate Riot API key `RGAPI-3015...` (current key visible in `.env`, Riot dev keys auto-rotate 24h but explicit rotation cleaner).
- 🔐 Rotate PAT `ghp_1Zu...` from prior session.
- Bug #004 fix folded into Phase 1 Task 0 (aggregator metadata `updated_at` + `match_count` populate).

## Resume / Status Tracking

Each phase file ends with a "Phase Completion Checklist" — agent updates `docs/project-changelog.md`, `docs/bugs-log.md`, and the phase-specific architecture doc per project's `Phase Completion Protocol` rule (CLAUDE.md). Verification: `grep -c "^## " docs/project-changelog.md` must increment ≥1 per phase.
