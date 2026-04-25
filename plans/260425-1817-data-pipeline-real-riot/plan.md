---
title: "Wire real Riot data into TFT Hell Elo (founder dogfood)"
description: "Replace bundled sample-tier-list.json with live Riot Match-v5 pipeline; founder uses real meta in real sessions."
status: pending
priority: P1
effort: 14h
branch: feat/v0.1-implementation
tags: [data-pipeline, riot-api, github-actions, dogfood, public-repo-security]
created: 2026-04-25
---

# Plan — Wire real Riot data (founder dogfood)

Phase scope: replace bundled `sample-tier-list.json` (baked into binary) with **live tier-list.json** generated from VN2 Challenger Match-v5 data, refreshed every 12h via GitHub Actions, fetched by app on launch + every 12h.

User: founder only (anh dogfood). NOT shipping to 9 testers yet. Shipping to testers gated on retention signal from anh's own usage.

## Phase status table

| # | Phase | Owner files | Status | Effort | Blocks |
|---|-------|-------------|--------|--------|--------|
| 01 | Python aggregator (TFT-Match-v1 fetch + tier calc + JSON emit) | `Pipeline/src/tftmac_pipeline/*` + `Pipeline/scripts/run_aggregator.py` | pending | 4h | 02, 03 |
| 02 | GitHub Actions cron (defensive workflow for PUBLIC repo) | `.github/workflows/tft-data-refresh.yml` + `data/tier-list.json` | pending | 2h | 03 |
| 03 | App network fetch + 12h background poll (DataManager rewrite — 6-file refactor) | `App/TFTMac/Services/DataManager.swift` + `App/TFTMac/Services/RemoteFetcher.swift` (NEW) | pending | 5h | 04 |
| 04 | Tests + 4-doc Phase Completion Protocol | `Pipeline/tests/test_run_aggregator.py` + `App/TFTMacTests/RemoteFetcherTests.swift` + 4 docs in `docs/` | pending | 3h | — |

## Dependency graph

```
Phase 01 (aggregator) ──┐
                        ├──> Phase 03 (app fetch) ──> Phase 04 (tests + docs)
Phase 02 (Actions cron)─┘
```

Phase 01 + 02 can run partly in parallel (different files), but 02 needs 01's CLI entrypoint name to invoke. Plan: 01 finishes scripts/run_aggregator.py CLI signature first; 02 starts in parallel after that.

## Architecture decisions chốt (do NOT re-debate)

1. Aggregator language = **Python** (extends existing `Pipeline/` package — DRY, reuse jaccard/comp_grouping/comp_signature already built)
2. Rate limit handling = **2 parallel workers via aiohttp + aiolimiter** (already pinned in pyproject.toml)
3. Anomaly schema = **Option A nested per-comp** — `comps[].anomalies[]` array of `{id, agreement}`
4. App refresh = **fetch on launch + Timer 12h background poll** (always fetch, no idle skip — rationale in phase-03)
5. Schema versioning = **`schema_version` at JSON root + "Update Required" banner on mismatch** (SchemaVersion model already implements `isCompatible`)

## Cron deployment recommendation

**Option 1: Public repo + defensive workflow + Secrets** — RECOMMENDED. Justification:
- Repo already public, toggling private adds friction for future open-source moment
- 24h Dev key auto-rotation is built-in damage cap (worst-case leak window = 24h, not forever)
- All defensive measures (no `${{ github.event.* }}` in run, repo guard, SHA-pinned actions) are mechanical to implement in phase-02
- Anh retains escape hatch: revoke key in Riot dev portal in 1 click

Phase 02 spec implements full defensive checklist.

## Anomaly UI rendering decision

**Inline chip list below comp metadata row** (3 chips max: top-3 most-agreed anomalies, agreement >= 0.40). Justification:
- Card already has `CompCardItemsRow` precedent — add `CompCardAnomaliesRow` (mirror pattern, DRY)
- Inline = visible at-a-glance during gameplay (matches "decision window" use case)
- Accordion/popover = 2nd click = friction during in-game scan
- Impact: +1 row in `CompCardV2.body`, ~30 LOC new file. Spec'd in phase-03.

## Test strategy decision

**Both** — split by environment:
- **Local dev / CI**: recorded fixtures (existing `Pipeline/tests/fixtures/fetched-matches-kr-2026-04-24.json` + new `tier-list-output.json` golden file). No live API calls in CI = no flake from 24h key expiry.
- **Manual smoke (founder runs before deploy)**: `make smoke` invokes aggregator with real key against VN2, asserts non-empty output + schema valid. Zero CI dependency.

Spec'd in phase-04.

## Background poll session detection

**Always fetch, no idle skip.** Justification (concrete numbers):
- 12h Timer fires → 1 HTTPS GET to GitHub raw URL (~50KB JSON gzipped) → ~200ms + ~50KB egress
- Per day = 2 fetches × 50KB = 100KB/day = 36MB/year
- Battery impact: URLSession on background thread, no CPU spike; equivalent to checking email twice/day
- Skipping when idle = adds state machine + edge case bugs for negligible savings

Spec'd in phase-03.

## Phase Completion Protocol (post-merge)

After Phase 04 completes, MUST update 4 docs (APPEND, not replace, where noted):
1. `docs/system-architecture.md` — add data pipeline layer to architecture diagram
2. `docs/data-pipeline-architecture.md` — NEW deep-dive doc (this phase's canonical reference)
3. `docs/project-changelog.md` — APPEND entry: "wire real Riot data, founder dogfood phase"
4. `docs/bugs-log.md` — APPEND any bugs found during testing (zero entries OK; file existence is the requirement)

## Files anticipated (full inventory)

**Create**:
- `Pipeline/src/tftmac_pipeline/riot_client.py` — async TFT-League-v1 + TFT-Match-v1 client with aiolimiter
- `Pipeline/src/tftmac_pipeline/tier_calculator.py` — play_rate/avg_placement → S/A/B/C tier
- `Pipeline/src/tftmac_pipeline/anomaly_aggregator.py` — `TFT17_EkkoOffering_*` per-comp aggregation
- `Pipeline/src/tftmac_pipeline/json_emitter.py` — `TierListOutput` dataclass → JSON matching App schema
- `Pipeline/scripts/run_aggregator.py` — CLI entrypoint (`python -m tftmac_pipeline` style)
- `Pipeline/tests/test_riot_client.py`, `test_tier_calculator.py`, `test_anomaly_aggregator.py`, `test_json_emitter.py`, `test_run_aggregator.py`
- `Pipeline/tests/fixtures/expected-tier-list-output.json` — golden file
- `.github/workflows/tft-data-refresh.yml`
- `data/tier-list.json` — initial committed empty stub (workflow overwrites)
- `App/TFTMac/Services/RemoteFetcher.swift` — URLSession + cache + fallback chain
- `App/TFTMac/Services/SchemaCompatibilityGate.swift` — small wrapper around `SchemaVersion.isCompatible`
- `App/TFTMac/Views/CompCardAnomaliesRow.swift` — chip list view
- `App/TFTMacTests/RemoteFetcherTests.swift`, `SchemaCompatibilityGateTests.swift`
- `docs/data-pipeline-architecture.md`
- `docs/bugs-log.md` (if not present)
- `Makefile` (or extend existing) — `make smoke`, `make pipeline-test`

**Modify**:
- `App/TFTMac/Services/DataManager.swift` — orchestrate RemoteFetcher → bundled fallback chain
- `App/TFTMac/Models/Comp.swift` — add `anomalies: [AnomalyRecommendation]` field
- `App/TFTMac/Models/Anomaly.swift` (NEW model file alongside existing models)
- `App/TFTMac/Views/CompCard.swift` — insert `CompCardAnomaliesRow` between items row and expand divider
- `App/TFTMac/Resources/sample-tier-list.json` — bump schema_version to 1.1.0 + add anomalies (backward-compat sample)
- `Pipeline/pyproject.toml` — bump version to 0.2.0
- `docs/system-architecture.md` — add pipeline layer
- `docs/project-changelog.md` — APPEND
- `.env.example` — already current, no change

**Delete**: none.

## Key links

- Handoff: `plans/reports/handoff-260425-1753-data-pipeline-phase.md`
- Pre-spike findings: `docs/pre-spike-api-verify.md` (Riot schema locked, Set 17 reality)
- Design doc: `docs/design-v0.1-menu-bar-popover.md`
- Existing scaffolding: `Pipeline/src/tftmac_pipeline/` (jaccard, comp_grouping, comp_signature, tuning)
- Existing fixture: `Pipeline/tests/fixtures/fetched-matches-kr-2026-04-24.json` (98 KR matches, Set 17)

## Risks summary (full per-phase in phase files)

| Risk | Likelihood | Impact | Mitigation phase |
|------|------------|--------|------------------|
| Riot API schema drift mid-Set-17 | Low | High | 01 — schema regression tests already exist; CI breaks loud |
| Dev key leaked from public repo | Med | Med (24h cap) | 02 — defensive workflow + 24h auto-rotation |
| GitHub Actions timeout (>6h job) | Low | Med | 01 — 2 parallel workers keep job <30min |
| App fetch crashes on malformed JSON | Low | High (founder UX) | 03 — schema gate + bundled fallback chain |
| Anomaly UI breaks card layout | Low | Low | 03 — chip row constrained width, fixture preview before merge |

## Rollback plan per phase

- Phase 01: revert Python files; existing `sample-tier-list.json` still ships as fallback. App unaffected.
- Phase 02: disable workflow in GitHub UI (1 click). `data/tier-list.json` becomes stale, app falls back to bundled.
- Phase 03: revert `DataManager.swift` to current bundled-only stub. App reverts to v0.1 baseline.
- Phase 04: tests/docs only — revert without code impact.

No phase has cascading rollback risk. Each phase shipped independently is functional; partial deploy = graceful degrade to bundled fallback.

## Success criteria (whole plan)

- [ ] `python -m tftmac_pipeline` produces `data/tier-list.json` matching schema 1.1.0 from real VN2 Challenger data
- [ ] GitHub Actions workflow runs every 12h, commits updated JSON to `data/` branch
- [ ] App on launch fetches `https://raw.githubusercontent.com/.../data/tier-list.json`, decodes successfully, renders comps with anomaly chips
- [ ] App schema gate rejects mismatched data and shows "Update Required" banner without crashing
- [ ] All Pipeline pytest tests pass (existing 14 + new ~20)
- [ ] All Swift XCTests pass (existing + new RemoteFetcher + SchemaCompatibility)
- [ ] 4 docs updated per Phase Completion Protocol
- [ ] Founder uses app for ≥3 TFT sessions with live data, reports zero crash + meta data feels current

## Resolved decisions (anh chốt 2026-04-25)

1. **CDN vs raw GitHub URL**: ✅ **raw.githubusercontent.com** — KISS, no third-party dep. Latency 300-500ms acceptable for founder dogfood.
2. **Sample size threshold**: ✅ **UI fade (pipeline emits all)** — preserves "almost-meta" trending comps signal for power user.
3. **Region pool**: ✅ **VN2 only for v0.1** — meta-region match. Expand to multi-region (KR mix) when shipping 9 testers if VN2 sample size proves insufficient.

## Deferred to v0.2 (anh chốt 2026-04-25 post code-reviewer audit)

- **Data-drift alerting** (PR distribution shift detection): defer until shipping 9 testers. v0.1 anh là QA in-session.
- **Git history bloat mitigation** (730 commits/year from cron): defer + tracked as Bug #003 in `docs/bugs-log.md`. Re-evaluate at 6-month mark or repo size > 500MB. Options: orphan branch / Git LFS / separate data repo.
- **Action SHA auto-bump tooling** (Renovate/Dependabot): defer for v0.1 KISS. Manual monthly bump via `gh api`. Re-evaluate when shipping testers.

## Post-audit patches applied (2026-04-25)

Code-reviewer audit found 4 critical findings — all fixed:
- **C1**: Phase 03 effort bumped 3h → 5h (DataManager refactor scope clarified, MenuBarExtra lifecycle hook corrected)
- **C2**: Anomaly decoding switched to `decodeIfPresent ?? []` forward-compat strategy (bundled JSON stays at schema 1.0.0, no lockstep bump)
- **C3**: Workflow PII grep guard added before commit step
- **C4**: SHA-pin policy documented (manual monthly bump, no Renovate for v0.1)

Total effort: 12h → 14h. Audit report: `plans/reports/code-reviewer-260425-1831-data-pipeline-arch-security.md`.
