# Phase 04 — Tests + Phase Completion Protocol docs

## Context Links

- Existing Pipeline tests: `Pipeline/tests/{conftest.py,test_*.py}` (14 passing)
- Existing fixture: `Pipeline/tests/fixtures/fetched-matches-kr-2026-04-24.json` (98 KR matches)
- Existing Swift tests: `App/TFTMacTests/` (verify path during impl; XCUITest in `App/TFTMacUITests/`)
- Phase 01-03 deliverables (this plan)
- Documentation rule: `~/.claude/rules/documentation-management.md`

## Overview

- **Priority**: P1 (gate for "phase done"; tests verify Phase 01-03 work)
- **Status**: pending
- **Effort**: 3h
- **Description**: Comprehensive test coverage (Python + Swift) using fixtures (no live Riot API in CI), plus 4-doc Phase Completion Protocol (system-architecture, data-pipeline-architecture NEW, project-changelog APPEND, bugs-log APPEND).

## Key Insights

1. **Test layering** (concrete numbers):
   - Existing 14 pytest tests cover schema regression + comp signature + comp grouping + jaccard + tuning. Stay green.
   - New Phase 01 tests target 5 new modules + CLI smoke = ~20 new tests.
   - Phase 03 Swift tests target RemoteFetcher (URLProtocol mock), SchemaCompatibilityGate, DiskCache, Comp/Anomaly decode = ~12 new tests.
   - Total post-phase: ~46 unit tests.

2. **Why no live Riot API tests in CI**:
   - Dev key expires every 24h. CI run on stale key = false negative + flake.
   - Fixture (`fetched-matches-kr-2026-04-24.json`) already proxies real schema and is locked by 14 schema regression tests. Schema drift = those break loud.
   - Local-only `make smoke` lets anh manually verify against live API (fresh key) before deploys.

3. **Golden file pattern for aggregator output**:
   - Take fixture (98 KR matches) → run pipeline aggregator → save output as `expected-tier-list-output.json`.
   - Test asserts current pipeline produces byte-identical output to golden (via `diff -u`).
   - When pipeline logic changes intentionally, regenerate golden + commit. Reviewer sees JSON diff in PR.

4. **Phase Completion Protocol = 4 docs, APPEND semantics**:
   - `system-architecture.md` — UPDATE in place (architecture diagram now reflects pipeline layer).
   - `data-pipeline-architecture.md` — CREATE NEW (canonical deep-dive for this phase).
   - `project-changelog.md` — APPEND new entry, never replace prior entries.
   - `bugs-log.md` — APPEND any bugs found during testing (zero entries acceptable; file existence is the requirement).

## Requirements

### Functional — Python tests

- [F1] `test_riot_client.py`: mock aiohttp via `aioresponses`; test Challenger fetch, match-id fetch, match-detail fetch, retry on 503, abort on 401, header includes correct UA + X-Riot-Token.
- [F2] `test_tier_calculator.py`: parametric tests for boundary cases (S/A/B/C thresholds), sample-size floor.
- [F3] `test_champion_aggregator.py`: from fixture, assert top-N champions, is_carry detection.
- [F4] `test_item_aggregator.py`: from fixture, assert top-3 items, agreement filter, exclusion of `TFT17_EkkoOffering_*`.
- [F5] `test_anomaly_aggregator.py`: from fixture, assert anomaly detection, agreement threshold, top-3, empty array on no data.
- [F6] `test_json_emitter.py`: dataclass → JSON; sort_keys deterministic; matches schema 1.1.0; no PII (no `puuid`/`riotId*` keys present).
- [F7] `test_run_aggregator.py`: integration — feed fixture into in-memory pipeline, assert output matches `expected-tier-list-output.json` golden file byte-for-byte.

### Functional — Swift tests

- [F8] `RemoteFetcherTests.swift`: stub URLProtocol, return mock JSON, assert decode succeeds; assert timeout fires; assert retry on 503.
- [F9] `SchemaCompatibilityGateTests.swift`: pure unit tests for `.ok` and `.updateRequired` decisions across major/minor/patch combos.
- [F10] `DiskCacheTests.swift`: write to tmp dir, read back, mtime, purge.
- [F11] `AnomalyDecodeTests.swift`: decode JSON sample with anomalies array; empty array; missing field (asserts decoder error since required field).
- [F12] `DataManagerLifecycleTests.swift`: start/stop, Timer scheduled, refresh idempotent under rapid call.

### Functional — Docs (Phase Completion Protocol)

- [F13] `docs/system-architecture.md` — add Section "Data pipeline layer" with diagram showing Riot API → aggregator → Actions → GitHub raw → app fetch.
- [F14] `docs/data-pipeline-architecture.md` (NEW) — canonical deep-dive: aggregator algorithm details, schema definition, runbook (manual smoke, key rotation, troubleshooting).
- [F15] `docs/project-changelog.md` — APPEND `[Unreleased] - Data pipeline real Riot wiring`; subsections Added/Changed/Deprecated.
- [F16] `docs/bugs-log.md` — APPEND or CREATE; document any bugs found in Phase 01-03 manual testing (or note "no bugs surfaced during phase").

### Non-functional
- [NF1] All tests deterministic; no time/random dependence (mock `datetime.utcnow()` in emitter test).
- [NF2] No live Riot API calls in CI tests.
- [NF3] Test runtime: pytest <30s total; Swift XCTests <60s.
- [NF4] Golden file < 200KB (1500 matches → ~50KB output JSON; well under).
- [NF5] Doc updates pass markdownlint (if configured locally; otherwise visual review).

## Architecture

### Test directory layout

```
Pipeline/tests/
├── conftest.py                              # EXISTING — fixtures dir helper
├── fixtures/
│   ├── fetched-matches-kr-2026-04-24.json   # EXISTING
│   ├── sample-participant.json              # EXISTING
│   ├── hand_labeled_groups.json             # EXISTING
│   └── expected-tier-list-output.json       # NEW — golden file
├── test_riot_schema_parse.py                # EXISTING — keep
├── test_comp_signature.py                   # EXISTING
├── test_comp_grouping.py                    # EXISTING
├── test_jaccard.py                          # EXISTING
├── test_tuning.py                           # EXISTING
├── test_riot_client.py                      # NEW
├── test_tier_calculator.py                  # NEW
├── test_champion_aggregator.py              # NEW
├── test_item_aggregator.py                  # NEW
├── test_anomaly_aggregator.py               # NEW
├── test_json_emitter.py                     # NEW
└── test_run_aggregator.py                   # NEW — golden file integration

App/TFTMacTests/
├── (existing) ...
├── RemoteFetcherTests.swift                 # NEW
├── SchemaCompatibilityGateTests.swift       # NEW
├── DiskCacheTests.swift                     # NEW
├── AnomalyDecodeTests.swift                 # NEW
└── DataManagerLifecycleTests.swift          # NEW
```

### `aioresponses` for Python async mock

```python
from aioresponses import aioresponses

@pytest.fixture
def mock_riot():
    with aioresponses() as m:
        m.get(
            "https://vn2.api.riotgames.com/tft/league/v1/challenger",
            payload={"entries": [{"puuid": "abc..."}]},
        )
        yield m
```

Add `aioresponses` to `pyproject.toml` `[project.optional-dependencies] dev`.

### URLProtocol mock for Swift

Standard pattern: `class URLProtocolStub: URLProtocol { static var responses: [URL: (Data, HTTPURLResponse)] = [:] ... }`. Inject via `URLSessionConfiguration.protocolClasses = [URLProtocolStub.self]`. Existing tests may already use this pattern — check during impl.

### Golden file generation script

Add to `Makefile`:
```
regenerate-golden:
	cd Pipeline && .venv/bin/python -m tftmac_pipeline.golden_regen \
	  --input tests/fixtures/fetched-matches-kr-2026-04-24.json \
	  --output tests/fixtures/expected-tier-list-output.json
```

`golden_regen.py` is a thin wrapper around `run_aggregator` that reads matches from disk instead of fetching. Devs run when intentionally changing pipeline logic; CI never runs it.

### Manual smoke target

Add to `Makefile`:
```
smoke:
	@if [ -z "$$RIOT_API_KEY" ]; then echo "ERROR: RIOT_API_KEY not set"; exit 1; fi
	cd Pipeline && .venv/bin/python scripts/run_aggregator.py \
	  --region vn2 --max-matches 200 --output /tmp/smoke-tier-list.json
	@echo "✓ Smoke output: /tmp/smoke-tier-list.json"
	@python -c "import json; d=json.load(open('/tmp/smoke-tier-list.json')); print(f'  schema={d[\"schema_version\"]} comps={len(d[\"comps\"])}')"
```

Anh runs `make smoke` before each phase deploy or weekly during dogfood.

## Related Code Files

### Create
- `Pipeline/tests/test_riot_client.py`
- `Pipeline/tests/test_tier_calculator.py`
- `Pipeline/tests/test_champion_aggregator.py`
- `Pipeline/tests/test_item_aggregator.py`
- `Pipeline/tests/test_anomaly_aggregator.py`
- `Pipeline/tests/test_json_emitter.py`
- `Pipeline/tests/test_run_aggregator.py`
- `Pipeline/tests/fixtures/expected-tier-list-output.json`
- `Pipeline/src/tftmac_pipeline/golden_regen.py` (helper for dev only)
- `App/TFTMacTests/RemoteFetcherTests.swift`
- `App/TFTMacTests/SchemaCompatibilityGateTests.swift`
- `App/TFTMacTests/DiskCacheTests.swift`
- `App/TFTMacTests/AnomalyDecodeTests.swift`
- `App/TFTMacTests/DataManagerLifecycleTests.swift`
- `Makefile` (or extend existing if present)
- `docs/data-pipeline-architecture.md` (canonical deep-dive)
- `docs/bugs-log.md` (if not present)

### Modify
- `Pipeline/pyproject.toml` — add `aioresponses` to dev deps
- `docs/system-architecture.md` — add data pipeline section + diagram
- `docs/project-changelog.md` — APPEND entry

### Delete
- None.

## Implementation Steps

1. **Add `aioresponses` to dev deps**: edit `Pipeline/pyproject.toml`, run `cd Pipeline && pip install -e '.[dev]'` to refresh venv.

2. **Write Pipeline tests in order** (per dependency):
   - `test_tier_calculator.py` (pure fn, no fixtures needed)
   - `test_anomaly_aggregator.py` (fixture-driven; uses existing 98-match fixture)
   - `test_champion_aggregator.py`
   - `test_item_aggregator.py`
   - `test_json_emitter.py` (dataclass-driven)
   - `test_riot_client.py` (aioresponses mock)
   - `test_run_aggregator.py` (golden file integration)

3. **Generate golden file**:
   - Run `make regenerate-golden` against existing 98-match KR fixture.
   - Inspect output JSON manually; sanity-check it has comps, anomalies, tiers.
   - Commit `expected-tier-list-output.json`.

4. **Write Swift tests**:
   - `SchemaCompatibilityGateTests` first (pure unit).
   - `AnomalyDecodeTests` (string-input JSON via `JSONDecoder`).
   - `DiskCacheTests` (use `FileManager.default.temporaryDirectory`).
   - `RemoteFetcherTests` (URLProtocol stub).
   - `DataManagerLifecycleTests` (lighter — verify Timer scheduled, refresh idempotent).

5. **Run full test suites**:
   - `cd Pipeline && pytest -v` — all green (existing 14 + new ~20).
   - Xcode → ⌘U — all green.

6. **Update docs**:
   - `docs/system-architecture.md`: add ASCII or Mermaid diagram showing data flow Riot → aggregator → Actions → GitHub raw → app. Reference `docs/data-pipeline-architecture.md` for detail.
   - `docs/data-pipeline-architecture.md` (NEW): full content per template (Overview / Components / Data flow / Schema / Runbook / Troubleshooting). Aim ~150-300 lines, structured for grep-ability.
   - `docs/project-changelog.md`: APPEND under `## [Unreleased]` (or current header):
     ```
     ### Added
     - Data pipeline: Python aggregator (`Pipeline/scripts/run_aggregator.py`) fetching VN2 Challenger Match-v5 data, emitting `data/tier-list.json` schema 1.1.0
     - GitHub Actions cron `tft-data-refresh.yml` running every 12h with defensive public-repo workflow
     - App fetch chain in `DataManager.swift`: remote → cache (fresh) → cache (stale + banner) → bundled fallback
     - Anomaly chip row in CompCard for Set 17 EkkoOffering recommendations
     - SchemaCompatibilityGate with "Update Required" overlay for forward-incompat schemas
     - 4 manual test paths documented (offline, stale, schema-mismatch, anomaly-render)
     ### Changed
     - Schema bumped 1.0.0 → 1.1.0: additive `anomalies[]` per comp + root `region` field
     - Bundled `sample-tier-list.json` updated to schema 1.1.0
     ```
   - `docs/bugs-log.md`: APPEND or CREATE; if no bugs found, write the section header with "No bugs surfaced during phase 01-04 (2026-04-25 to <merge date>)".

7. **Final integration smoke**: anh runs `make smoke` against live Riot API + opens app → verifies live data renders end-to-end.

## Todo List

- [ ] Add `aioresponses` to Pipeline dev deps
- [ ] Write `test_tier_calculator.py`
- [ ] Write `test_anomaly_aggregator.py`
- [ ] Write `test_champion_aggregator.py`
- [ ] Write `test_item_aggregator.py`
- [ ] Write `test_json_emitter.py`
- [ ] Write `test_riot_client.py` with aioresponses
- [ ] Generate `expected-tier-list-output.json` golden file
- [ ] Write `test_run_aggregator.py` (golden file integration)
- [ ] Write `RemoteFetcherTests.swift`
- [ ] Write `SchemaCompatibilityGateTests.swift`
- [ ] Write `DiskCacheTests.swift`
- [ ] Write `AnomalyDecodeTests.swift`
- [ ] Write `DataManagerLifecycleTests.swift`
- [ ] Run `pytest -v` all green
- [ ] Run Xcode ⌘U all green
- [ ] Update `docs/system-architecture.md` with data pipeline section + diagram
- [ ] Create `docs/data-pipeline-architecture.md` (canonical deep-dive)
- [ ] APPEND to `docs/project-changelog.md`
- [ ] APPEND/CREATE `docs/bugs-log.md`
- [ ] Final `make smoke` against live Riot + manual app launch verification

## Success Criteria

- [ ] Existing 14 Pipeline tests still pass
- [ ] ~20 new Pipeline tests pass
- [ ] ~12 new Swift tests pass
- [ ] Golden file `expected-tier-list-output.json` exists, byte-equal to current pipeline output on 98-match fixture
- [ ] `make smoke` succeeds against live VN2 with anh's current dev key
- [ ] All 4 docs updated/created per Phase Completion Protocol
- [ ] `docs/data-pipeline-architecture.md` includes runbook section (manual smoke, key rotation, troubleshooting)
- [ ] `docs/project-changelog.md` has APPEND entry for this phase, prior entries intact (no replace)

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Golden file flake on minor sort instability | Med | Low | json_emitter uses `sort_keys=True`; group iteration order is deterministic in Python 3.7+. Test asserts diff after `json.loads + json.dumps(sort_keys=True)` to absorb whitespace. |
| `aioresponses` doesn't match aiohttp 3.9 spec | Low | Med | Pin to compatible version; if breaks, fall back to manual `unittest.mock.patch` of session methods. |
| URLProtocol mock infrastructure absent | Med | Low | Standard 30-line pattern; copy-paste from public docs if no existing pattern. Phase 03 may already establish. |
| Doc rewrite vs append on changelog | Low | Med | Explicit APPEND instruction in F15; reviewer checks via `git diff` that prior entries unchanged. |
| Phase Completion Protocol forgotten | Med | Med | Plan.md has dedicated section + checklist row in this phase. |
| Test coverage gaps on RemoteFetcher edge cases | Med | Low | Document known coverage gaps in test file comments; track for v0.2 |
| `make smoke` succeeds locally but Actions fails | Low | High | Run actual workflow `workflow_dispatch` in Phase 02 before declaring phase done; smoke is necessary but not sufficient. |

## Security Considerations

- **Test fixtures**: existing fixtures contain real PUUIDs from KR Challenger players. PII concern? Riot PUUIDs are public per Riot ToS (returned by public endpoints). Acceptable. No real-name correlation possible without separate Riot lookup.
- **Test data**: Pipeline tests do NOT require live API key (uses fixtures). `make smoke` requires key from env; never commit smoke output.
- **No new auth surfaces**: tests don't introduce new credentials.

## Next Steps

After Phase 04:
- Phase complete. Plan.md status table all rows → completed.
- Anh runs ≥3 TFT sessions with live data, captures any UX feedback in `docs/dogfood-feedback-260425.md` (out of scope for this plan; future iteration input).
- If retention signal positive after 1-2 weeks → green-light tester ship phase.

## Backwards Compatibility

- Tests are additive; no existing test deleted.
- Doc updates are additive (new sections, new files) or APPEND (changelog).
- `Makefile` is new file (or extends existing) — no behavior change to existing build.

## Rollback

- Remove new test files: tests stop running but production code unaffected.
- Revert doc updates: docs become stale but functional code unchanged.
- Phase 04 has the lowest rollback risk of all phases — purely additive.
