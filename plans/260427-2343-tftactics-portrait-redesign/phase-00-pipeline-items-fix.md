# Phase 0 — Pipeline Items Fix (Bug #008)

**Status:** ⏳ Pending
**Estimate:** ~30 min
**Blocking:** All subsequent phases

## Context

Riot Match-v5 Set 17 API populates `unit.itemNames` (string array, e.g. `["TFT_Item_GargoyleStoneplate"]`) but leaves `unit.items` (int array, legacy format) **always empty**. Phase 2 trait-bucket path in `comp_grouping.py:73-78` reads `unit.get("items", [])` → `items_per_champion` empty → `_emit_champions_from_bucket` emits `"items": []` for every champion → portrait UI has nothing to render.

Verified 2026-04-27 by inspecting fixture `Pipeline/tests/fixtures/fetched-matches-kr-2026-04-24.json`: TFT17_Karma carry shows `items: []`, `itemNames: ['TFT_Item_JeweledGauntlet', 'TFT_Item_SpearOfShojin', 'TFT_Item_ArchangelsStaff']`. Same shape in current production VN2 cron output.

## Files

- Modify: `Pipeline/src/tftmac_pipeline/comp_grouping.py:69-78` (read `itemNames` instead of `items`)
- Test: `Pipeline/tests/test_trait_combo_grouping.py` (extend with itemNames-based test)
- Regen: `App/TFTMac/Resources/sample-tier-list.json` (after fix)
- Push: `data/tier-list.json` to `main` (one-off bypass cron, schedule still disabled per HEAD `92b0550` on main)

## Tasks

### Task 0.1: Write failing test for itemNames extraction

**Files:**
- Test: `Pipeline/tests/test_trait_combo_grouping.py` (extend)

- [ ] **Step 1: Read existing test file structure**

Run: `head -30 Pipeline/tests/test_trait_combo_grouping.py`
Expected: see existing test pattern using `group_comps_by_trait_signature`

- [ ] **Step 2: Append failing test**

Append to `Pipeline/tests/test_trait_combo_grouping.py`:

```python
def test_items_per_champion_uses_itemNames_not_items():
    """Bug #008 — Riot Set 17 emits unit.itemNames (strings); unit.items (ints) always empty.
    Producer must read itemNames so consumer (_emit_champions_from_bucket) can populate
    the JSON output's items[] array.
    """
    participants = [{
        "placement": 1,
        "traits": [{"name": "TFT17_DarkStar", "tier_current": 2, "num_units": 4}],
        "units": [{
            "character_id": "TFT17_Karma",
            "rarity": 4,
            "tier": 2,
            "items": [],  # legacy int array — Riot leaves empty
            "itemNames": ["TFT_Item_JeweledGauntlet", "TFT_Item_SpearOfShojin"],
        }],
    }]
    from tftmac_pipeline.comp_grouping import group_comps_by_trait_signature
    buckets = group_comps_by_trait_signature(participants)
    assert len(buckets) == 1
    bucket = next(iter(buckets.values()))
    items = bucket["items_per_champion"]["TFT17_Karma"]
    assert items["TFT_Item_JeweledGauntlet"] == 1
    assert items["TFT_Item_SpearOfShojin"] == 1
```

- [ ] **Step 3: Run test to verify it FAILS**

Run: `cd Pipeline && .venv/bin/pytest tests/test_trait_combo_grouping.py::test_items_per_champion_uses_itemNames_not_items -v`
Expected: FAIL — `items_per_champion["TFT17_Karma"]` is empty dict (current code reads empty `items` int array)

### Task 0.2: Fix producer to read itemNames

**Files:**
- Modify: `Pipeline/src/tftmac_pipeline/comp_grouping.py:69-78`

- [ ] **Step 1: Replace items extraction loop**

Find in `comp_grouping.py`:

```python
            for item in unit.get("items", []) or []:
                # Riot returns ints (item ids) or dicts; normalize
                item_id = item if isinstance(item, (str, int)) else item.get("id")
                if item_id is not None:
                    b["items_per_champion"][cid][item_id] += 1
```

Replace with:

```python
            # Bug #008 — Riot Set 17 leaves `items` (int IDs) empty; populates
            # `itemNames` (strings like "TFT_Item_GargoyleStoneplate") instead.
            # Prefer itemNames; fall back to items for older sets / safety.
            raw_items = unit.get("itemNames") or unit.get("items") or []
            for item in raw_items:
                item_id = item if isinstance(item, str) else (
                    item if isinstance(item, int) else item.get("id") if isinstance(item, dict) else None
                )
                if item_id is not None:
                    b["items_per_champion"][cid][item_id] += 1
```

- [ ] **Step 2: Run targeted test to verify PASS**

Run: `cd Pipeline && .venv/bin/pytest tests/test_trait_combo_grouping.py::test_items_per_champion_uses_itemNames_not_items -v`
Expected: PASS

- [ ] **Step 3: Run full pipeline suite for regression check**

Run: `cd Pipeline && .venv/bin/pytest`
Expected: 187 passed (was 186 + new test). Zero failures.

### Task 0.3: Regenerate bundled fixture + verify items emit

**Files:**
- Modify: `App/TFTMac/Resources/sample-tier-list.json` (regen)

- [ ] **Step 1: Regen via inline Python (relaxed min_sample for KR demo)**

Run:
```bash
cd Pipeline && .venv/bin/python -c "
import json, sys; from pathlib import Path
sys.path.insert(0, 'src')
import tftmac_pipeline.run_aggregator as ra
ra._MIN_SAMPLE_TO_EMIT = 3
matches = json.loads(Path('tests/fixtures/fetched-matches-kr-2026-04-24.json').read_text())
ranked = [m for m in matches if m.get('info', {}).get('queue_id') == 1100] or matches
payload = ra.build_tier_list_payload(ranked, region='KR', patch='')
Path('../App/TFTMac/Resources/sample-tier-list.json').write_text(json.dumps(payload, sort_keys=True, indent=2, ensure_ascii=False), encoding='utf-8')
items_count = sum(len(c.get('items', [])) for comp in payload['comps'] for c in comp['champions'])
print(f'items emitted across all champions: {items_count}')
"
```
Expected: `items emitted across all champions: 50+` (was 0 before fix).

- [ ] **Step 2: Verify Swift tests still pass with refreshed fixture**

Run:
```bash
xcodebuild -project App/TFTMac.xcodeproj -scheme TFTMac \
  -only-testing:TFTMacTests/SampleTierListFixtureTests \
  -only-testing:TFTMacTests/DataManagerTests \
  -only-testing:TFTMacTests/TierListDecodingTests \
  test 2>&1 | tail -8
```
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 3: Commit Phase 0 fix**

```bash
git add Pipeline/src/tftmac_pipeline/comp_grouping.py \
        Pipeline/tests/test_trait_combo_grouping.py \
        App/TFTMac/Resources/sample-tier-list.json
git commit -m "fix(pipeline): read unit.itemNames (Set 17 Riot API) in trait-bucket producer (bug #008)

Riot Match-v5 for Set 17 leaves unit.items (legacy int IDs) always
empty and populates unit.itemNames (string array) instead. Producer
in comp_grouping.py was reading the empty field, causing items[] to
emit empty for every champion in v1.2.0 tier-list.json — UI items
overlay had no data to render.

Fix: prefer unit.itemNames, fall back to unit.items for older sets.
Bundled KR fixture regenerated — items_per_champion now populates
50+ items across 32 comps.

Tests: new test_items_per_champion_uses_itemNames_not_items asserts
producer reads itemNames; full suite 187 green."
```

### Task 0.4: Run live aggregator + push to main

**Files:**
- Push: `data/tier-list.json` to remote `main` branch

- [ ] **Step 1: Run aggregator locally with current `.env` key**

Run:
```bash
cd Pipeline && set -a && source ../.env && set +a && \
  .venv/bin/python -m tftmac_pipeline.run_aggregator --region vn2 --output ../data/tier-list.json
```
Expected: exit 0, `Done → ../data/tier-list.json (NN comps)`. Run time ~10-15 min (rate-limited).

- [ ] **Step 2: Verify items[] now populated in output**

Run:
```bash
python3 -c "
import json
d = json.load(open('data/tier-list.json'))
items = sum(len(c.get('items', [])) for comp in d['comps'] for c in comp['champions'])
print(f'schema={d[\"schema_version\"]} comps={len(d[\"comps\"])} items_total={items}')
"
```
Expected: `items_total` > 0 (likely 30-100 across all champions).

- [ ] **Step 3: Push tier-list.json to main via worktree**

Run:
```bash
git worktree add /tmp/tft-main main && cd /tmp/tft-main && \
  git fetch origin main && git reset --hard origin/main && \
  cp "/Users/mac/Desktop/TFTTACTICS FOR MACS/data/tier-list.json" data/tier-list.json && \
  git add data/tier-list.json && \
  git commit -m "data: refresh tier-list.json with items[] populated (bug #008 fix)" && \
  git push origin main
cd "/Users/mac/Desktop/TFTTACTICS FOR MACS" && git worktree remove /tmp/tft-main
```
Expected: push succeeds. Disk worktree cleaned.

- [ ] **Step 4: Verify remote serves data with items**

Run:
```bash
curl -s "https://raw.githubusercontent.com/psychomafia-tiger/tft-hell-elo-for-macos/main/data/tier-list.json" | python3 -c "
import json, sys
d = json.load(sys.stdin)
items = sum(len(c.get('items', [])) for comp in d['comps'] for c in comp['champions'])
print(f'remote items_total: {items}')
"
```
Expected: `remote items_total > 0`.

## Success criteria

- ✅ Test `test_items_per_champion_uses_itemNames_not_items` passes
- ✅ Full pipeline pytest suite 187 green
- ✅ Bundled `sample-tier-list.json` has 50+ items across champions
- ✅ Swift tests still pass (3 affected suites)
- ✅ Live aggregator emits items[] populated
- ✅ Remote main `data/tier-list.json` returns items_total > 0

## Risk assessment

- Aggregator run failure (RIOT_API_KEY expired again): re-rotate via `https://developer.riotgames.com/`, paste in `.env`, retry. Doc'd in earlier session.
- 429 rate limit during aggregator: existing exponential backoff handles. Run time may stretch to 20+ min.
- Push to main rejected (workflow scope missing): fallback — push only `data/tier-list.json`, NOT touching `.github/workflows/` (that path was the issue earlier).

## Next phase

→ [Phase 1 — Asset metadata + URL builder](phase-01-asset-metadata.md)
