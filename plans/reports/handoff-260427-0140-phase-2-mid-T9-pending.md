# Handoff — Phase 2 mid-flight, T1-T8 ✅, T9-T11 + T10b pending

**Date**: 2026-04-27 01:40 ICT
**Branch**: `feat/v0.1-implementation` (clean, all pushed up to `268be11`)
**Predecessor**: `handoff-260426-2028-phase-1-done-phase-2-ready.md`

---

## Resume command (next session)

```bash
cd "/Users/mac/Desktop/TFTTACTICS FOR MACS" && cat plans/reports/handoff-260427-0140-phase-2-mid-T9-pending.md
```

---

## What's done in this session (8 commits)

| Commit | Task | Outcome |
|---|---|---|
| `e1cf46c` | T1 trait_combo_signature | sorted tuple of (name, tier_current) for active traits |
| `693060b` | T2 comp_name_resolver | curated trait_name_map.json + fallback strip |
| `55efa40` | T3 group_comps_by_trait_signature | additive; coexists with Jaccard `group_signatures` |
| `a4c1cad` | T4 wire trait grouping + schema 1.2.0 | json_emitter + run_aggregator rewired; 168 tests |
| `350d93b` | **mid-fix** TFT17_ prefix | regex strip both Set17_/TFT17_; trait_name_map keys updated |
| `7ac2954` | T5 TraitActivation Swift | model + Comp.traits forward-compat decode |
| `a7bc0d1` | T6 schema 1.2.0 acceptance | explicit test (existing forward-window already accepts) |
| `299ac6d` | T7 TraitCatalog + TraitAssetURL | 38-trait bundle from CDragon; iconToken-based URL |
| `268be11` | T8 TraitChip view | async icon load via AssetCache + Theme.Fonts.monoCaption |

**Tests**: 170 pipeline + 101 App = 271 green. Zero regressions.

---

## CRITICAL discoveries this session (read before continuing)

### Discovery 1 — Real Riot API uses `TFT17_*` prefix, NOT `Set17_*`
- Surfaced in T4 KR fixture smoke (sample comp emitted `"TFT17_APTrait TFT17_DarkStar"`)
- Patched in commit `350d93b`: regex `^(Set|TFT)\d+_` future-proofs Set 18+
- Memory: `project_riot_trait_prefix_TFT17.md`

### Discovery 2 — apiName ≠ icon token ≠ display name
- `TFT17_PsyOps` → display "Psionic", iconToken "psyops"
- `TFT17_APTrait` → display "Replicator", iconToken "replicator"
- `TFT17_VexUniqueTrait` → display "Doomer", iconToken "doomer"
- Catalog mandatory — simple prefix strip would show "PsyOps", "APTrait", "VexUniqueTrait" (all wrong)
- Source: CommunityDragon `https://raw.communitydragon.org/latest/cdragon/tft/en_us.json`, `data['sets']['17']['traits']`
- 38 entries bundled at `App/TFTMac/Resources/set17-traits.json`

### Discovery 3 — Trait icon URL pattern verified
- `https://raw.communitydragon.org/latest/game/assets/ux/traiticons/trait_icon_17_<token>.tft_set17.png`
- Note `.tft_set17.png` suffix (NOT just `.png`)
- Plan's guessed pattern was wrong; controller probed CDN

### Discovery 4 — Theme tokens
- `Theme.Fonts.captionSmall` — DOES NOT EXIST
- Real: `Theme.Fonts.monoCaption` (10pt monospaced)
- T8 plan snippet had wrong token; corrected during dispatch

### Discovery 5 — `comp_name_resolver` curated map needs alignment
- Currently keys use `TFT17_Psionic+TFT17_Conduit` etc. — but real apiName for "Psionic" is `TFT17_PsyOps`
- Curated map will MISS on real data → fallback path → display = catalog displayName via Swift
- **Action item for next session**: regenerate `Pipeline/data/trait_name_map.json` keys from CDragon apiNames after T9 ships and we see real comp groupings in UI

---

## Phase 2 — REMAINING tasks

### T9 — Wire TraitChip into CompCard (NEXT, ~15 LOC, do DIRECT)

**File**: `App/TFTMac/Views/CompCard.swift` (already inspected — line 38 `var body`, line 41 `championsRow`)

**Insertion**:
```swift
// In body VStack, between topRow and championsRow:
if !comp.traits.isEmpty {
    traitsRow
}

// Add private computed near line 92:
private var traitsRow: some View {
    HStack(spacing: 4) {
        ForEach(comp.traits.sorted(by: { $0.count > $1.count }), id: \.name) { trait in
            TraitChip(activation: trait)
        }
        Spacer(minLength: 0)
    }
}
```

**Verify**: `xcodebuild test -only-testing:TFTMacTests/CompCardV2Tests` (NOT full suite — UI test pops app)

**Commit msg**: `feat(app): render trait chips row in CompCard`

### T10 — Refresh bundled fixture to schema 1.2.0 (~5 min, DIRECT)

**File**: `App/TFTMac/Resources/sample-tier-list.json` (current = v1.0.0 or v1.1.0)

**Steps**:
1. `cd Pipeline && .venv/bin/python scripts/run_aggregator.py --output ../App/TFTMac/Resources/sample-tier-list.json` (verify CLI flags)
   - OR if cron has run: copy from `Pipeline/data/tier-list.json`
   - Manual trigger: `gh workflow run aggregator.yml --ref feat/v0.1-implementation && gh run watch`
2. Update `App/TFTMacTests/regression/SampleTierListFixtureTests.swift`:
   ```swift
   func test_fixtureSchemaIs1_2_0() {
       XCTAssertEqual(loadedTierList.schemaVersion, SchemaVersion(major: 1, minor: 2, patch: 0))
   }
   func test_fixtureCompsHaveTraits() {
       let withTraits = loadedTierList.comps.filter { !$0.traits.isEmpty }
       XCTAssertGreaterThan(withTraits.count, 0)
   }
   ```
3. Verify: `xcodebuild test -only-testing:TFTMacTests/SampleTierListFixtureTests`

**Commit msg**: `data: refresh bundled fixture to schema 1.2.0 (trait-aware)`

### T10b — Bug #005 fix: star_level data + 3-star-only render (~30-45 min, DISPATCH cross-lang)

**Cross-lang Python+Swift, 5+ files, justified subagent dispatch.**

Plan at `plans/260426-1752-tftactics-feature-parity/phase-02-trait-centric-comp.md` lines 1052-1188.

Pipeline: aggregate modal `tier` per champion in `champion_aggregator.py`, emit `star_level: int`.
App: `Champion.starLevel` (default 1, forward-compat). `StarLevelIndicator` body: `if level >= 3 { 3 stars } else { EmptyView() }`.

**Note**: T4 `_emit_champions_from_bucket` currently sets `cost: 0` because trait bucket doesn't carry champion rarity. T10b needs same enrichment path — consider emitting both `cost` AND `star_level` in same change.

**Commit msg**: `fix(app+pipeline): star_level data-driven, 3-star-only render (bug #005)`

### T11 — Phase Completion Protocol (~15 min, DIRECT)

Per CLAUDE.md mandate, append to:
1. `docs/system-architecture.md` — note schema 1.2.0, trait pipeline
2. CREATE `docs/trait-aggregation-architecture.md` — Mermaid: Match → trait_combo_signature → group_comps → resolve_name → emit → app TraitChip
3. APPEND `docs/project-changelog.md`:
   ```markdown
   ## [phase-02-trait-centric-comp] — 2026-04-27

   ### Added
   - Trait combo signature replaces champion-set hash for comp grouping (Pipeline)
   - `comp_name_resolver` with curated trait-combo → semantic name map (~6 entries, will grow)
   - `TraitActivation` Swift model + `traits[]` field on Comp
   - `TraitCatalog` (38 Set 17 traits from CDragon), `TraitAssetURL`, `TraitChip` view
   - Bug #005 fix: data-driven star_level + 3-star-only render

   ### Changed
   - Schema bumped 1.1.0 → 1.2.0; forward-compat decoder retains 1.0.0/1.1.0 support
   - CompCard renders trait chips row above champion row
   - `_strip_prefix` regex handles both Set17_ and TFT17_ (real Riot API uses TFT)

   ### Architecture impact
   - Pipeline grouping reshaped — comp count may collapse (trait similarity). Tier thresholds may need re-tuning post-cron-run.
   - Champion `cost` currently emits 0 from new trait-bucket path (trait_bucket doesn't carry rarity). Defer to Phase 3 enrichment.

   ### Bug fixes
   - Bug #005 (star_level over-render) — see Phase 2 Task 10b
   ```
4. APPEND `docs/bugs-log.md` — new bugs surfaced this phase (Bug #005 status update from ⏳ Deferred → ✅ Fixed)

**Verification**: `git diff HEAD~1 docs/project-changelog.md | grep -c "^+## "` ≥ 1

**Commit msg**: `docs(phase-02): trait-centric comp identification + bug #005 fix`

---

## Workflow lessons learned this session

### NEW memories saved (read before next session)
- `feedback_dispatch_threshold_loc.md` — sub-50-LOC single-file: do DIRECT, not subagent. Dispatch overhead burns 30-40% tokens.
- `feedback_xcodebuild_test_pops_app.md` — full `xcodebuild test` triggers XCUITest → app window opens. Use `-only-testing:TFTMacTests/SomeSuite` per-task.
- `project_riot_trait_prefix_TFT17.md` — real API uses TFT17_*; resolver regex strips both.
- `feedback_default_sonnet_for_implementers.md` — never Haiku; rework cost > savings.

### Loop pattern anh flagged
- 8 sequential subagent dispatches felt loop-like to anh
- Mỗi task em đều: dispatch → verify-bash → mark-done → next dispatch (same rhythm)
- T6 (5-LOC test) and T9 (15-LOC wire) should have been DIRECT, not subagent
- App popped up 3+ times because em ran full `xcodebuild test` instead of `-only-testing:`

### Recommended flow for T9-T11
- T9: DIRECT Edit (em đã read CompCard structure, know exact lines)
- T10: DIRECT (regenerate JSON + 2 test methods)
- T10b: DISPATCH (cross-lang justified)
- T11: DIRECT (markdown appends)

---

## Pending TODOs (track end-of-Phase-2 or later)

| # | Task | Where | Block? |
|---|---|---|---|
| 1 | 🔐 Rotate Riot API key (still in `.env`) | https://developer.riotgames.com | Soft |
| 2 | 🔐 Rotate PAT `ghp_1Zu...` (earlier session) | github.com/settings/tokens | Soft |
| 3 | Regenerate `trait_name_map.json` keys from real apiNames after T10 ships | Pipeline/data | Defer to Phase 3 |
| 4 | Champion `cost` enrichment in trait-bucket emission path (currently 0) | json_emitter.py `_emit_champions_from_bucket` | Defer to Phase 3 |
| 5 | `tft17_rhaast` portrait 404 (asset gap) | CommunityDragon CDN | Soft, log noise only |
| 6 | `generate_golden_fixture.py` still hardcodes `1.1.0` | Pipeline/scripts | Defer (dev utility) |
| 7 | Manual trigger `gh workflow run aggregator.yml` for fresh v1.2.0 data | terminal | Optional (T10 may use dry-run output) |

---

## Repo state

- **Branch**: `feat/v0.1-implementation` synced to origin (last push `268be11` 01:34 ICT — needs `git push` after T11)
- **Default branch**: `main` (61 commits behind feat — sync after Phase 4 ships)
- **Visibility**: PUBLIC
- **Working tree**: clean
- **Last commit**: `268be11 feat(app): TraitChip view with async icon load via TraitCatalog`

---

## First action next session

1. Read this handoff
2. Verify `git log --oneline -5` shows `268be11` HEAD
3. Skip per-task verification bash — trust subagent reports unless commit fails
4. **Execute T9 DIRECTLY** (read CompCard:38-92 already-known structure → 2 Edits → 1 targeted xcodebuild → commit)
5. Then T10, T10b, T11 in order per plan above

Phase 2 plan: `plans/260426-1752-tftactics-feature-parity/phase-02-trait-centric-comp.md`

---

## Unresolved (for next session)

1. After T10 ships, eyeball UI: do trait names render correctly via TraitCatalog? If many fall through to fallback, the curated `trait_name_map.json` keys are misaligned (TODO #3 above) — patch in same session.
2. Bug #005 root cause still mysterious (anh's screenshot showed 3-star ghost render, not investigated). Fix-forward in T10b replaces both data + render path.
3. `comp_pipeline.run_pipeline` (old Jaccard path) intact but unused by `build_tier_list_payload` — defer cleanup until Phase 3 confirms no regression.
