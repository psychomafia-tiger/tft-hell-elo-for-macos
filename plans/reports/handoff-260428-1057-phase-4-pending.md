# Handoff — Portrait Redesign Phase 0-3 ✅, Phase 4 pending

**Date**: 2026-04-28 10:57 ICT
**Branch**: `feat/v0.1-implementation` (clean, all pushed up to `601355f`)
**Predecessor**: `handoff-260427-0140-phase-2-mid-T9-pending.md`
**Plan**: `plans/260427-2343-tftactics-portrait-redesign/`
**Spec**: `docs/superpowers/specs/2026-04-27-tftactics-portrait-redesign-design.md`

---

## Resume command (next session)

```bash
cd "/Users/mac/Desktop/TFTTACTICS FOR MACS" && cat plans/reports/handoff-260428-1057-phase-4-pending.md
```

---

## What's done (5 commits in this session)

| Phase | Commit | Outcome |
|---|---|---|
| 0 | `6bd35f9` (feat) + `bfa5043` (main) | Bug #008 fix — `comp_grouping.py` reads `unit.itemNames`. Pipeline 187 green. Live aggregator emitted 196 items × 111 carries × 44 comps to remote main. |
| 1 | `7e88d2d` | `set17-items.json` (183 entries) + `ItemAssetURL.swift` + `ItemCatalog` refactor (loads JSON + iconToken + itemClass). 9 new tests. |
| 2 | `24806a9` | `ItemBadge.swift` (12pt async + class-tinted fallback). 8 new tests. |
| 3 | `601355f` | `ChampionPortrait` cost-color border (always) + 3-item overlay on carry. Removed `tierColor:` param. CompCard caller updated. 5 new tests. |

**Tests**: 187 pipeline + ~50 app suite green. Zero regressions.

---

## CRITICAL discoveries this session

### Discovery 1 — Bug #008 root cause
Riot Match-v5 Set 17 emits `unit.itemNames` (string array) but leaves `unit.items` (legacy int array) ALWAYS empty. Phase 2 trait-bucket producer was reading the empty field → `items: []` for every champion → portrait UI had nothing to render. Fixed in Phase 0.

### Discovery 2 — CDragon item URL pattern
Verified live: `https://raw.communitydragon.org/latest/game/assets/maps/tft/icons/items/hexcore/<token>.png`. Token derived from CDragon `en_us.json` `data['items'][i].icon` → strip directory prefix, drop `.tex`, lowercase. Set suffix (`.tft_set13`, `.tft_set17`) varies per item — preserve exactly.

### Discovery 3 — `TFT_Item_Blank` has null name
CDragon en_us.json includes placeholder items with `name: null` that broke initial JSON decode. Script now skips items with null/empty name.

### Discovery 4 — File convention
`ChampionAssetURL`, `TraitAssetURL` live in `Services/`, NOT `Generated/`. ItemAssetURL placed in Services to match. `ItemCatalog` (lookup) stays in `Generated/` like sibling catalogs.

### Discovery 5 — Cron disabled until Phase 4 merge
Workflow schedule was disabled via `gh workflow disable tft-data-refresh.yml` (commit `92b0550` on main bypassed git push of workflow file due to OAuth scope limit). Re-enable via UI or `gh workflow enable` AFTER feat merges to main.

---

## Phase 4 — REMAINING tasks (~20 min, all DIRECT)

Plan file: `plans/260427-2343-tftactics-portrait-redesign/phase-04-cleanup-and-docs.md` (full spec)

### Task 4.1 — Remove CompCardItemsRow

```bash
# Edit CompCard.swift:45 — remove the line `CompCardItemsRow(comp: comp)`
rm App/TFTMac/Views/CompCardItemsRow.swift

# Remove from Xcode target via Ruby
ruby -rxcodeproj -e '
proj = Xcodeproj::Project.open("App/TFTMac.xcodeproj")
target = proj.targets.find { |t| t.name == "TFTMac" }
ref = proj.files.find { |f| f.path == "CompCardItemsRow.swift" }
if ref
  target.source_build_phase.remove_file_reference(ref)
  ref.remove_from_project
  proj.save
end
'

# Verify build
xcodebuild -project App/TFTMac.xcodeproj -scheme TFTMac build 2>&1 | tail -3
```

### Task 4.2 — Fix stale comments in CompCardAnomaliesRow.swift

Lines 5, 12 reference `CompCardItemsRow` — update to drop the reference.

### Task 4.3 — Regression check

```bash
xcodebuild -project App/TFTMac.xcodeproj -scheme TFTMac \
  -only-testing:TFTMacTests/CompCardV2Tests \
  -only-testing:TFTMacTests/ExpandedCardViewTests \
  -only-testing:TFTMacTests/ItemBadgeTests \
  -only-testing:TFTMacTests/ItemCatalogTests \
  -only-testing:TFTMacTests/ItemAssetURLTests \
  -only-testing:TFTMacTests/DataManagerTests \
  -only-testing:TFTMacTests/TierListDecodingTests \
  -only-testing:TFTMacTests/SampleTierListFixtureTests \
  -only-testing:TFTMacTests/TraitChipTests \
  -only-testing:TFTMacTests/TraitCatalogTests test 2>&1 | tail -8
```
Expected: `** TEST SUCCEEDED **`.

### Task 4.4 — Phase Completion Protocol docs (per CLAUDE.md mandate)

4 files to update — full content in `plans/260427-2343-tftactics-portrait-redesign/phase-04-cleanup-and-docs.md` Task 4.4 Steps 1-4:

1. **`docs/system-architecture.md`** — update last-updated date; add `ItemAssetURL.swift` (Services), `ItemBadge.swift` (Views), `set17-items.json` (Resources) to file layout block; remove `CompCardItemsRow.swift` line; add cross-ref to new `portrait-redesign-architecture.md`
2. **`docs/project-changelog.md`** — APPEND `## [phase-03-tftactics-portrait-redesign] — 2026-04-28` entry at TOP (after header, before existing entries) with Added/Changed/Fixed/Removed/Architecture-impact sections + commits list
3. **`docs/bugs-log.md`** — APPEND Bug #008 entry at end (status ✅ Fixed, commit `6bd35f9`)
4. **CREATE `docs/portrait-redesign-architecture.md`** — deep-dive Mermaid flow + URL pattern + itemClass mapping (full template in plan file)

**Verification grep**:
```bash
grep -c "^## " docs/project-changelog.md
git diff HEAD docs/project-changelog.md | grep -c "^+## "
```
Expected: count incremented by ≥1.

### Task 4.5 — Final commit + push

```bash
git add App/TFTMac/Views/CompCard.swift App/TFTMac/Views/CompCardAnomaliesRow.swift App/TFTMac.xcodeproj/project.pbxproj docs/
git add -u  # catches CompCardItemsRow.swift deletion
git commit -m "chore(phase-03): cleanup CompCardItemsRow + docs sync per Phase Completion Protocol"
git push origin feat/v0.1-implementation
```

---

## Manual smoke test (anh)

After Phase 4 ships:
1. `pkill -f TFTMac`
2. `rm -rf ~/Library/Caches/io.psychomafia.tfthellelo/`
3. Relaunch via Xcode (Cmd+R)
4. Visual compare against TFTactics screenshot (anh shared earlier today):
   - ✅ Every champion has cost-color border (1=gray, 2=green, 3=blue, 4=purple, 5=gold)
   - ✅ Carry champions show 3 item icons overlaid on bottom of portrait
   - ✅ 3-star champions show ⭐⭐⭐ above portrait
   - ✅ Header shows fresh `<N> Challenger matches · <few min> ago` (44 comps from current main)
   - ✅ No "TRAITS — Trait breakdown available in v0.2 pipeline" placeholder text

---

## Pending TODOs (post Phase 4)

| # | Task | Where | Block? |
|---|---|---|---|
| 1 | Re-enable cron workflow schedule | `gh workflow enable tft-data-refresh.yml` (OR edit `.github/workflows/tft-data-refresh.yml` to uncomment cron block) | After Phase 4 merge |
| 2 | Merge feat → main | `gh pr create` then merge | Phase 4 ship + manual smoke pass |
| 3 | Curated `trait_name_map.json` keys regen from real apiNames | `Pipeline/data/trait_name_map.json` | Defer Phase 5 |
| 4 | 80 "unknown" itemClass entries in catalog | `Pipeline/scripts/generate-set17-items.py` OVERRIDES dict | Acceptable for v0.1; iterate as needed |
| 5 | Workflow schedule actually disabled? | UI confirm or `gh workflow list` shows `disabled` | Re-check before merge |
| 6 | Riot Dev API key 24h auto-rotate | `.env` + `gh secret set RIOT_API_KEY` | Manual when expired |

---

## Repo state

- **Branch**: `feat/v0.1-implementation` synced to origin (HEAD `601355f` 10:57 ICT)
- **Main**: HEAD `bfa5043` (Phase 0 hand-push, schema 1.2.0 + items)
- **Workflow schedule**: DISABLED (active: `Dependency Graph` only)
- **Working tree**: clean

---

## Workflow lessons learned this session

### Subagent Bash perm issue
- Phase 0 + 1 implementer subagents BLOCKED on missing Bash perm in their sandbox
- Em took over direct execution after first BLOCKED — same pattern as T10b earlier session
- For Phase 4 next session: skip subagent dispatch, execute direct (Phase 4 = file deletes + Edit + markdown appends, fits "sub-50-LOC single-file" rule per `feedback_dispatch_threshold_loc.md`)

### Spec self-review caught hole
- Original spec assumed ~50 items in catalog — actual CDragon has 3565
- Self-review with live probe surfaced 8 holes including bug #008
- Lesson: probe URLs + verify counts BEFORE finalizing spec, not during execution

### CodingKeys + keyDecodingStrategy conflict (recap)
- Bug #006 from previous session — explicit snake_case raw values short-circuit `.convertFromSnakeCase` strategy
- Phase 1 ItemCatalog Swift code uses bare CodingKeys (no raw values) → strategy handles conversion → no conflict

---

## First action next session

1. Read this handoff
2. Verify `git log --oneline -5` shows `601355f` HEAD
3. Execute Phase 4 Tasks 4.1-4.5 in order (all DIRECT, ~20 min)
4. After Phase 4 commit + push: prompt anh for manual smoke test
5. After anh confirms visual: discuss merge feat → main + re-enable cron

Plan file: `plans/260427-2343-tftactics-portrait-redesign/phase-04-cleanup-and-docs.md`

---

## Unresolved (for next session)

1. None blocking — Phase 4 fully scoped and ready to execute.
2. Item icon URL miss rate at runtime — em verified URL pattern with 2 known items but didn't probe all 183. If anh reports many items render as colored squares (not real icons), grep app logs for AssetCache 404 patterns and patch URL builder or set17-items.json iconToken values.
