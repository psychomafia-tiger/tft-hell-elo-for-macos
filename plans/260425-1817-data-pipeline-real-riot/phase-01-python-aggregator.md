# Phase 01 — Python aggregator (Riot fetch → tier calc → JSON emit)

## Context Links

- Handoff: `plans/reports/handoff-260425-1753-data-pipeline-phase.md`
- Pre-spike (schema locked): `docs/pre-spike-api-verify.md`
- Existing scaffolding: `Pipeline/src/tftmac_pipeline/` (jaccard, comp_grouping, comp_signature, tuning)
- Existing fixture: `Pipeline/tests/fixtures/fetched-matches-kr-2026-04-24.json` (98 matches, KR, Set 17)
- Existing fetch script (manual prototype): `Pipeline/scripts/fetch_riot_sample.py` — patterns to reuse, code to refactor

## Overview

- **Priority**: P1 (blocks Phase 02 + 03)
- **Status**: pending
- **Effort**: 4h
- **Description**: Build production aggregator that fetches VN2 Challenger Match-v5 data, groups by comp signature (existing algorithm), calculates tier (S/A/B/C), aggregates anomalies per comp, emits `tier-list.json` matching App schema v1.1.0.

## Key Insights

1. **Existing scaffolding solves 50% of the work**. `comp_signature.extract_signature()` + `comp_grouping.group_signatures()` + `jaccard_similarity()` are battle-tested via 14 passing tests on real KR Set 17 data. We do NOT rewrite — we wire them into a fetch + emit pipeline.

2. **Set 17 reality (locked by `test_riot_schema_parse.py`)**:
   - No `augments[]` field. Anomaly mechanic = `TFT17_EkkoOffering_*` items in `units[].itemNames[]`.
   - `character_id` prefix `TFT17_*`, item prefixes mixed (`TFT_Item_*` 87.7%, `TFT17_*` ~17%).
   - Queue IDs: 1100 = Ranked TFT, 1090 = Normal TFT. Aggregator must filter to 1100 only (ranked = high-skill signal).

3. **Rate limit math (concrete number example)**:
   - Dev key budget: 100 req / 2 min = 50 req/min sustained, 0.83 req/s max.
   - Pipeline: 1 challenger list call + 100 PUUID match-id calls + ~1000 match detail calls = ~1101 requests.
   - Sequential at 1.3s/req (existing prototype) = ~24 min. Inside 30min Actions soft budget.
   - **2 parallel workers via aiolimiter** = ~12 min. Halves wall time, still within rate limit (aiolimiter centralizes the 50 req/min token bucket across all workers).
   - Plain language: imagine a token bucket with 100 tokens that refills 100 every 2 min. Each request takes 1 token. Two workers race for tokens — neither can exceed combined 100/2min.

4. **Why aiohttp + aiolimiter (not threads)**: Riot endpoints are I/O-bound. Threads add memory + GIL contention; asyncio with shared rate limiter = single-event-loop, simple to test. Already pinned in `pyproject.toml`.

## Requirements

### Functional
- [F1] Fetch VN2 Challenger PUUIDs (`/tft/league/v1/challenger`, platform=`vn2`).
- [F2] For each PUUID, fetch last 20 ranked match IDs (`/tft/match/v1/matches/by-puuid/{puuid}/ids?count=20&queue=1100`, regional=`sea`).
- [F3] Dedupe match IDs across PUUIDs.
- [F4] Fetch full match data for each unique ID (`/tft/match/v1/matches/{matchId}`).
- [F5] Filter to queue_id=1100 (ranked) post-fetch as belt-and-suspenders.
- [F6] Per participant: extract comp signature using existing `extract_signature()`.
- [F7] Group signatures using existing `group_signatures(threshold=0.70)` (threshold tuned in pre-spike F4).
- [F8] Per group, compute: play_rate, avg_placement, top_4_rate, sample_size.
- [F9] Per group, compute anomalies: filter `units[].itemNames[]` for `TFT17_EkkoOffering_*` prefix, group by item ID, emit top-3 with agreement >= 0.40.
- [F10] Per group, compute champion list: most-frequent units (filter cost >= 3 like signature does), top-8 by frequency, mark `is_carry=True` for highest-tier-current units.
- [F11] Per group, compute item builds per carry: `units[character_id=carry].itemNames[]` aggregation, top-3 with agreement >= 0.40 (matches existing `Champion.items` schema).
- [F12] Tier classification (S/A/B/C) — see Architecture below.
- [F13] Emit `data/tier-list.json` matching `TierList` Swift model schema 1.1.0 (anomalies field added).

### Non-functional
- [NF1] Total runtime <20 min on GitHub Actions runner (free tier 7GB RAM, 2 vCPU).
- [NF2] Memory <500MB (1000 matches × ~50KB JSON in mem = 50MB; well within budget).
- [NF3] Idempotent: re-running with same data produces byte-identical JSON output (sorted keys, deterministic comp grouping).
- [NF4] Resilient to single-request failures (skip + log, don't abort if 1 of 1000 matches fails).
- [NF5] Logging via stdlib `logging` at INFO level — workflow log readable.

## Architecture

### Module layout

```
Pipeline/src/tftmac_pipeline/
├── __init__.py                # bump __version__ = "0.2.0"
├── jaccard.py                 # EXISTING — unchanged
├── comp_signature.py          # EXISTING — unchanged
├── comp_grouping.py           # EXISTING — unchanged
├── tuning.py                  # EXISTING — unchanged (test helper only)
├── riot_client.py             # NEW — async fetch w/ aiolimiter
├── tier_calculator.py         # NEW — S/A/B/C classification
├── anomaly_aggregator.py      # NEW — TFT17_EkkoOffering_* per-comp
├── champion_aggregator.py     # NEW — units → top-N champions per comp
├── item_aggregator.py         # NEW — itemNames → top-3 items per carry
└── json_emitter.py            # NEW — dataclasses → JSON
Pipeline/scripts/
├── fetch_riot_sample.py       # EXISTING — keep for ad-hoc fetches
└── run_aggregator.py          # NEW — production CLI entrypoint
```

### Data flow

```
[VN2 Challenger PUUIDs (TFT-League-v1)]
       │ aiolimiter 50 req/min
       ▼
[Match IDs by PUUID, queue=1100 (TFT-Match-v1)]
       │ dedupe set
       ▼
[Match details, parallel x2 (TFT-Match-v1)]
       │ filter queue_id == 1100
       ▼
[Per participant: extract_signature(units cost>=3)]
       │
       ▼
[group_signatures(threshold=0.70)] ──→ canonical groups
       │
       ▼
[For each group: aggregate {play_rate, avg_placement,
                            top_4_rate, sample_size,
                            champions, anomalies}]
       │
       ▼
[tier_calculator.classify() → S/A/B/C]
       │
       ▼
[json_emitter.emit() → data/tier-list.json]
```

### Tier calculation rules (concrete numbers)

Inputs per comp: `play_rate` (0-1), `avg_placement` (1-8), `sample_size`.

| Tier | play_rate | avg_placement | sample_size |
|------|-----------|---------------|-------------|
| **S** | >= 0.08 | <= 4.0 | >= 30 |
| **A** | >= 0.05 | <= 4.3 | >= 20 |
| **B** | >= 0.03 | <= 4.5 | >= 15 |
| **C** | else | else | >= 10 |

Comp with sample_size < 10 = filtered out (insufficient data).

Plain-language example: 1000 ranked matches × 8 participants = 8000 participant slots. Comp "Storm Quickdraw" appears 800 times → play_rate = 800/8000 = 0.10. If avg_placement = 3.7 and sample = 800 → tier S (passes all 3 thresholds).

### Anomaly aggregation (Option A — nested per comp)

Per group:
1. Collect all `TFT17_EkkoOffering_*` items across group members' units.
2. Count occurrences per anomaly_id.
3. agreement = count / group.sample_size.
4. Filter agreement >= 0.40, keep top-3 by agreement desc.
5. Emit as `comps[].anomalies = [{id, agreement}, ...]`.

If a comp has zero anomalies (small sample or no Ekko offerings), emit empty array `[]` (NOT null — Swift `[Anomaly]` non-optional decode).

### Output JSON schema (v1.1.0)

```json
{
  "schema_version": "1.1.0",
  "patch_version": "16.8",
  "last_updated": "2026-04-25T18:00:00Z",
  "data_window_hours": 12,
  "elo_bracket": "CHALLENGER",
  "region": "VN2",
  "total_matches_sampled": 1247,
  "comps": [
    {
      "comp_id": "storm-quickdraw",
      "name": "Storm Quickdraw",
      "tier": "S",
      "play_rate": 0.105,
      "avg_placement": 3.78,
      "top_4_rate": 0.61,
      "sample_size": 131,
      "champions": [
        {"id": "TFT17_Viktor", "cost": 5, "is_carry": true,
         "items": [{"id": "TFT_Item_JeweledGauntlet", "agreement": 0.82}]}
      ],
      "anomalies": [
        {"id": "TFT17_EkkoOffering_AnomalyItem", "agreement": 0.71}
      ]
    }
  ]
}
```

Schema bump 1.0.0 → 1.1.0 (additive `anomalies` field; Codable ignores unknown so old App still decodes — but App-side will bump too in Phase 03).

Add `region: "VN2"` field (additive). Useful for future multi-region pool.

### Configuration

Read from env (already in `.env.example` template):
- `RIOT_API_KEY` — required
- `RIOT_REGION` — default `vn2` (platform routing for league + match-id endpoints)
- `RIOT_ROUTING` — default `sea` (regional routing for match detail endpoint)

CLI args (override env):
- `--region vn2`
- `--routing sea`
- `--output data/tier-list.json`
- `--max-matches 1500` (cap, default 1500)
- `--workers 2` (parallel async workers)

### Error handling

| Scenario | Handling |
|----------|----------|
| 401/403 (bad key) | Abort with exit code 2, log "RIOT_API_KEY invalid or expired" |
| 429 (rate limit) | aiolimiter prevents this; if hit anyway, exponential backoff 5s/10s/20s, max 3 retries |
| 500/503 (server) | Retry once after 3s; skip if still fails, log warning |
| Connection timeout | Retry once; skip on second fail |
| Single match parse error | Log + skip; do NOT abort whole pipeline |
| 0 valid matches at end | Abort with exit code 3, "Insufficient data — refusing to overwrite tier-list.json with empty output" |

Critical: NEVER overwrite `data/tier-list.json` with empty/error output. Workflow stops on exit !=0 → previous good JSON preserved.

## Related Code Files

### Create
- `Pipeline/src/tftmac_pipeline/riot_client.py` (~150 LOC)
- `Pipeline/src/tftmac_pipeline/tier_calculator.py` (~60 LOC)
- `Pipeline/src/tftmac_pipeline/anomaly_aggregator.py` (~80 LOC)
- `Pipeline/src/tftmac_pipeline/champion_aggregator.py` (~80 LOC)
- `Pipeline/src/tftmac_pipeline/item_aggregator.py` (~70 LOC)
- `Pipeline/src/tftmac_pipeline/json_emitter.py` (~120 LOC, includes dataclasses)
- `Pipeline/scripts/run_aggregator.py` (~80 LOC, CLI wiring only)

### Modify
- `Pipeline/src/tftmac_pipeline/__init__.py` — bump `__version__ = "0.2.0"`
- `Pipeline/pyproject.toml` — version bump

### Delete
- None.

## Implementation Steps

1. **Create `riot_client.py`**:
   - Class `RiotClient(api_key, region, routing)` with `aiohttp.ClientSession` + `aiolimiter.AsyncLimiter(50, 60)` (50 req per 60s — 20% safety margin under 100/120s).
   - Methods: `fetch_challenger_puuids() -> list[str]`, `fetch_match_ids(puuid: str, count: int = 20) -> list[str]`, `fetch_match(match_id: str) -> dict`.
   - Headers same as `fetch_riot_sample.py` (User-Agent string critical to avoid Cloudflare 1010).
   - Async context manager protocol (`__aenter__` / `__aexit__`).

2. **Create `champion_aggregator.py`**:
   - `aggregate_champions(group: GroupedComp) -> list[ChampionEntry]`.
   - Across group's participants, count unit appearances. Take top-8 by frequency (TFT comps usually 8 board slots).
   - Mark `is_carry = True` for units where avg `tier_current` >= 2 (2-star+ on board = carry signal).
   - Cost from `unit.rarity + 1` (per existing `extract_signature` convention).

3. **Create `item_aggregator.py`**:
   - For each carry unit in a group, aggregate `itemNames` across appearances.
   - Filter to non-Anomaly items (exclude `TFT17_EkkoOffering_*` — those go to anomaly_aggregator).
   - Compute `agreement = count / carry.appearances`.
   - Top-3 by agreement, agreement >= 0.40.

4. **Create `anomaly_aggregator.py`**:
   - For each group, scan all participants' `units[].itemNames[]` for `TFT17_EkkoOffering_*` prefix.
   - Count per anomaly_id, agreement = count / group.sample_size.
   - Top-3 by agreement, agreement >= 0.40, emit empty array if none qualify.

5. **Create `tier_calculator.py`**:
   - `classify(play_rate, avg_placement, sample_size) -> Optional[Tier]` — None if sample < 10.
   - Pure function, easily unit-testable.

6. **Create `json_emitter.py`**:
   - Dataclasses: `TierListOutput`, `CompEntry`, `ChampionEntry`, `ItemBuild`, `AnomalyEntry`.
   - `to_dict()` methods producing snake_case keys (matches App `convertFromSnakeCase`).
   - `emit(output: TierListOutput, path: Path)` writes with `sort_keys=True, indent=2` for deterministic diffs in git.

7. **Create `run_aggregator.py` CLI**:
   - argparse for region/routing/output/max-matches/workers.
   - Load env via `os.environ.get("RIOT_API_KEY")`.
   - Async main: open `RiotClient`, fetch challenger → match IDs → match details (parallel), group, aggregate, classify, emit.
   - Exit codes: 0 success, 2 auth fail, 3 insufficient data, 1 unhandled exception.

8. **Wire into `Pipeline/pyproject.toml`**:
   - Add console_scripts entry: `tft-aggregate = tftmac_pipeline.run_aggregator:main_sync` (alternative to `python -m`; either works for Actions).

9. **Local smoke test** (anh runs manually):
   - `cd Pipeline && .venv/bin/python scripts/run_aggregator.py --region vn2 --max-matches 100 --output /tmp/test-output.json`
   - Inspect `/tmp/test-output.json` — confirm schema, comps populated, anomalies present.

## Todo List

- [ ] Create `riot_client.py` with aiohttp + aiolimiter
- [ ] Create `tier_calculator.py` with classify() pure fn
- [ ] Create `champion_aggregator.py`
- [ ] Create `item_aggregator.py`
- [ ] Create `anomaly_aggregator.py`
- [ ] Create `json_emitter.py` dataclasses + emit()
- [ ] Create `scripts/run_aggregator.py` CLI
- [ ] Bump pyproject.toml version 0.2.0
- [ ] Bump `__init__.py` __version__
- [ ] Run `cd Pipeline && .venv/bin/pytest -q` — all existing tests still pass
- [ ] Local smoke: invoke run_aggregator with --max-matches 100, verify output JSON

## Success Criteria

- [ ] `python scripts/run_aggregator.py --region vn2 --max-matches 1500` produces `data/tier-list.json` with ≥10 comps, schema_version "1.1.0"
- [ ] All existing 14 schema regression tests pass
- [ ] New unit tests (Phase 04) pass against fixtures
- [ ] Pipeline runs <20 min on local machine for max-matches=1500 (proxy for Actions)
- [ ] Output JSON deterministic: running twice with same fixture input → byte-identical files (`diff` returns empty)
- [ ] Zero `print()` statements in production modules — all output via `logging`

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| VN2 Challenger has <50 active players → tiny sample | Med | Med | Document floor; if sample <300 matches, log WARNING but emit anyway. Plan unresolved Q: VN2-only vs hybrid pool. Default VN2-only for v0.1. |
| Riot Cloudflare blocks Python User-Agent | High (already seen in pre-spike) | High | Reuse exact UA string from `fetch_riot_sample.py`; add to test that asserts UA header set |
| aiolimiter ≠ Riot's actual budget tracking → 429 storm | Low | Med | Conservative 50/60s (vs Riot's 100/120s = 20% safety margin); 429 retry handler |
| Set 17 → 18 mid-Phase-01 → schema break | Low | High | Existing `test_match_is_tft_set_17` lock — fails loud. Anh decides whether to update fixtures or pause. |
| Output JSON nondeterministic (dict ordering) | Med | Low | `sort_keys=True` in json.dumps; tested via byte-equality test |
| Memory blowup on large match list | Low | Low | Stream match details one-at-a-time, don't accumulate full list. Compute aggregates online. |
| TFT17_EkkoOffering items disappear (hotfix removed) | Low | Low | Anomaly array becomes empty `[]`, App renders empty chip row gracefully (Phase 03 spec) |

## Security Considerations

- `RIOT_API_KEY` ONLY read from env. Never log full key (log first 8 chars + `***...` if needed for debugging).
- No `eval()`, no shell out, no untrusted deserialization.
- aiohttp default TLS verification ON — confirm not disabled anywhere.
- Output JSON contains zero PII: `puuid`/`riotIdGameName` from match data is NOT propagated to output (only aggregated comp stats).
  - Concrete check: `grep -c "puuid\|riotId" data/tier-list.json` should equal 0 after emit. Add as test.

## Next Steps

After Phase 01 done:
- Phase 02 (Actions cron) can begin; needs `run_aggregator.py` CLI signature finalized.
- Phase 03 starts in parallel; needs `json_emitter.py` schema (especially anomalies field shape) finalized.

## Backwards Compatibility

- Schema 1.1.0 is additive over 1.0.0 (`anomalies` + `region` fields added). Existing App schema 1.0.0 still decodes 1.1.0 because Codable ignores unknown fields. App schema bump in Phase 03 makes anomalies a required render path.
- Existing `Pipeline/scripts/fetch_riot_sample.py` left in place (different purpose: ad-hoc inspection vs production). Not deleted.
- No DB migration; no user data touched.
