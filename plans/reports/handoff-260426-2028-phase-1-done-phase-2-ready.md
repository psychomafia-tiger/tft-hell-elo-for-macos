# Handoff — Phase 1 ✅ DONE, Phase 2 ready (with Bug #005 fold-in)

**Date**: 2026-04-26 20:28 ICT
**Branch**: `feat/v0.1-implementation` (clean, all pushed up to `d82534d`)
**Predecessor**: `handoff-260426-1742-tftactics-feature-parity-plan.md`

---

## Resume command (next session)

```bash
cd "/Users/mac/Desktop/TFTTACTICS FOR MACS" && cat plans/reports/handoff-260426-2028-phase-1-done-phase-2-ready.md
```

---

## What's done in session this

### Phase 1 ✅ COMPLETE (7 tasks, 8 commits)

| Commit | Task | Outcome |
|---|---|---|
| `3768b97` | T1 Bug #004 | aggregator emits `updated_at` + `match_count` (HeaderBar timestamp will work) |
| `3089cb5` | T1 follow-up | added real-matches test (covers `len(matches)` with non-empty comps) |
| `d5874b4` | T2 tier tuning | S = ≥5% play / ≤4.3 avg → 2 S-tier emit on live VN2 (was 0) |
| `bf285a1` | T3 ChampionAssetURL | URL builder verified vs CommunityDragon Set 17 |
| `e4004d5` | T4 AssetCache | URLSession + 30d disk cache + 50MB LRU + SHA-256 keys |
| `b35a848` | T5 ChampionCatalog | data-driven 59-entry Set 17 catalog (Kai'Sa, Bel'Veth, Cho'Gath, etc.) |
| `6605802` | T6 ChampionPortrait | `.task` async load real artwork, placeholder fallback |
| `d82534d` | T7 docs | changelog +1, bugs-log +2, asset-pipeline-architecture.md |

**Tests**: 88 unit + 1 UI + 137 pipeline = all green.
**Manual gate**: anh confirmed real portraits load (Aatrox/Viktor/Illaoi visible in popover).

### Plan deltas applied this session

- Phase 1 Task 0 — research file created with verified URL patterns (`research/communitydragon-set17.md`)
- Phase 1 Task 3-5 — Ruby xcodeproj snippet fixed (group-relative paths, NOT repo-relative — was causing path-doubling)
- Phase 2 — added **Task 10b** for Bug #005 (star_level fix, see below)

---

## NEW BUG SURFACED — Bug #005 (folded into Phase 2 Task 10b)

**Symptom**: anh quan sát popover → star indicator over-renders. TFTactics convention = chỉ 3-star champions show ★★★ (gold). 1-star + 2-star render nothing. Current code (`StarLevelIndicator.derivedLevel`) uses heuristic `isCarry ? 2 : 1` → wrong star count on every champion.

**Root cause** (2 layers):
1. Pipeline doesn't emit `star_level` per champion (no Match-v5 `units[].tier` aggregation)
2. App heuristic in `App/TFTMac/Views/StarLevelIndicator.swift:32-34` hardcoded

**Fix plan** (Phase 2 Task 10b — full code skeleton in plan file):
- Pipeline: aggregate modal `tier` per champion across top-4, emit `star_level: int`
- App: `Champion.starLevel: Int` (default 1, forward-compat)
- `StarLevelIndicator` body: `if level >= 3 { 3 stars } else { EmptyView() }`
- Schema bump 1.2.0 (cùng đợt với trait emission)

**Why fold-in vs hotfix**: schema bump cần wave together với trait fields (avoid two consecutive 1.2.0 → 1.3.0 bumps). Phase 2 ships data + UI together.

Documented at `docs/bugs-log.md:89` (Bug #005 entry).

---

## Phase 2 — READY TO START

**Goal**: trait-centric comp identification — semantic names ("Psionic Conduits"), trait chips with icons + counts, schema 1.2.0.

**Effort**: 14-23h (now +2-3h with Bug #005 fold-in = ~16-26h)

**Tasks**: 12 total (was 11, added Task 10b mid-plan)
1. Trait combo signature builder (Python TDD)
2. Comp name resolver with curated map
3. Comp grouping by trait signature (additive)
4. Wire into run_aggregator + emit traits[] (schema 1.2.0)
5. TraitActivation Swift model + Comp.traits forward-compat decode
6. SchemaCompatibilityGate accepts 1.2.0
7. TraitCatalog + TraitAssetURL (Set 17 trait icons)
8. TraitChip view (TDD)
9. Wire TraitChip into CompCard
10. Refresh bundled fixture to schema 1.2.0
10b. **NEW** — Bug #005 fix: star_level data + 3-star-only render
11. Phase Completion Protocol

**Pre-Phase-2 manual gates**:
- ✅ anh sees real portraits live (DONE)
- ⏳ Pipeline cron re-run with new tier thresholds (so S-tier badge visible) — auto at 12:00 UTC, OR manual trigger:
  ```bash
  gh workflow run aggregator.yml --ref feat/v0.1-implementation
  gh run watch
  ```
  Optional — Phase 2 schema bump 1.2.0 will trigger fresh data anyway.

---

## Subagent-driven workflow (continue)

Per skill `superpowers:subagent-driven-development` chosen last session. Pattern:
- 1 implementer subagent per task
- 1 spec reviewer + 1 code-reviewer per task (skip-able for trivial 3-line tunings — exercise judgment)
- Manual gate after entire phase

**Lessons from Phase 1 dispatch**:
- Ruby xcodeproj `new_file` takes **group-relative** path (filename only), NOT repo-relative — implementer hit path-doubling bug Task 3, fixed manually. Plan now updated.
- SourceKit shows `XCTest` undefined diagnostic after every new test file added — these are stale-index false positives; `xcodebuild test` actually compiles + runs fine. Ignore SourceKit, trust xcodebuild.
- Implementers tend to over-deliver (P1.T1 added unrequested `emit_dict` helper but it was justified — production output needed it). Spec reviewer caught it as "in-scope refactor", approved.
- Skip per-task code-quality review for tasks <50 LOC + single-file scope. Run final code-reviewer at phase end on full diff.

---

## Pending TODOs (track end-of-Phase-2 or later)

| # | Task | Where | Block? |
|---|---|---|---|
| 1 | 🔐 Rotate Riot API key `RGAPI-3015...` (visible in `.env`) | https://developer.riotgames.com | Soft (auto 24h) |
| 2 | 🔐 Rotate PAT `ghp_1Zu...` from earlier session | https://github.com/settings/tokens | Soft |
| 3 | Manual trigger `gh workflow run aggregator.yml` để có S-tier badge sớm hơn 12h cron | terminal | Optional |
| 4 | (P1.T1 followup) Refactor `build_tier_list_payload` SRP — pure assembler vs invokes pipeline | `Pipeline/src/tftmac_pipeline/run_aggregator.py:43` | Defer |
| 5 | (P1.T1 followup) Unify timestamp format (`Z` vs `+00:00`) between `last_updated` and `updated_at` | `run_aggregator.py:80,90` | Defer |

---

## Repo state

- **Branch**: `feat/v0.1-implementation` synced to origin (last push d82534d 20:21 ICT)
- **Default branch**: `main` (53 commits behind feat — sync after Phase 4 ships)
- **Visibility**: PUBLIC
- **Open files / WIP**: none, working tree clean
- **App built + installed**: `~/Library/Developer/Xcode/DerivedData/TFTMac-*` (LaunchServices registered, `open -a TFTMac` works)

---

## Architecture state (post-Phase-1)

- **Schema**: pipeline still 1.1.0 (Phase 2 will bump 1.2.0); app accepts 1.0.0 + 1.1.0
- **Asset pipeline NEW**: ChampionAssetURL → AssetCache → CommunityDragon CDN → disk cache `~/Library/Caches/io.psychomafia.tfthellelo.assets/` → SwiftUI view
- **Catalog**: 59-entry Set 17 champion lookup (Resources/set17-champions.json) — replaces 15-entry hand-coded
- **Tier thresholds**: S ≥5%/4.3, A ≥3%/4.3, B ≥1.5%/4.6, C else (was 10%/4.0 strict)
- **Bugs log**: 4 fixed (#001b, #001c, #004, #C1) + 1 deferred (#005 → Phase 2 Task 10b)

---

## First action next session

1. Read this handoff
2. Verify `git log --oneline -5` shows `d82534d` HEAD
3. Verify all tests still green:
   ```bash
   cd Pipeline && .venv/bin/pytest -v 2>&1 | tail -5
   xcodebuild test -project App/TFTMac.xcodeproj -scheme TFTMac -destination 'platform=macOS' 2>&1 | tail -5
   ```
4. (Optional) trigger pipeline cron `gh workflow run aggregator.yml` to refresh data with new thresholds
5. Begin Phase 2 — invoke `superpowers:subagent-driven-development` skill, dispatch P2.T1 implementer (trait_combo_signature)

Phase 2 plan: `plans/260426-1752-tftactics-feature-parity/phase-02-trait-centric-comp.md`

## Unresolved (for next session)

1. Bug #005 visual confusion — anh's screenshot showed 3 stars on multiple champions but code derivedLevel returns max 2. Discrepancy unresolved (could be CommunityDragon asset baked-in stars, OR rendering quirk). Phase 2 Task 10b fix replaces both data + render path so root-cause investigation deferred — fix-forward.
2. Should Phase 2 also bump SchemaVersion accept set to include 1.2.0 right at Task 6, or wait until pipeline emits 1.2.0 first? Plan says Task 6 — verify ordering doesn't break in-flight remote fetches.
