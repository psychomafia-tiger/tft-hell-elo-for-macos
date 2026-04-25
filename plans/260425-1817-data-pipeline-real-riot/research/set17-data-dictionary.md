# Research — TFT Set 17 data dictionary (synthesis)

## Source basis

WebFetch denied this session. Synthesis derived from:
- `docs/pre-spike-api-verify.md` — verified Set 17 response analysis
- `Pipeline/tests/fixtures/fetched-matches-kr-2026-04-24.json` — 98 KR matches (~9529 equipped items, ~784 participants)
- `Pipeline/tests/test_riot_schema_parse.py` — locked-in expectations

## Set 17 key facts

- **Set name**: `TFTSet17` (`info.tft_set_core_name`)
- **Set number**: 17 (`info.tft_set_number`)
- **Game version (KR sample)**: `Linux Version 16.8.766.8562 (Apr 16 2026/22:22:30) [PUBLIC] <Releases/16.8>`
- **Patch (derived)**: `16.8`
- **Major mechanic change**: Augment system REMOVED. Replaced by Anomaly / Ekko Offering mechanic.

## Character ID prefix convention

All Set 17 units carry prefix `TFT17_`:
- `TFT17_Viktor`
- `TFT17_KaiSa`
- `TFT17_Aatrox`
- `TFT17_Nami`
- etc.

No cross-set unit IDs observed in active play (i.e. Set 16 `TFT16_*` units do not appear in Set 17 matches).

## Trait ID prefix

All Set 17 traits: `TFT17_<TraitName>`:
- `TFT17_AnimaSquad`
- `TFT17_HellEgo` (← potential origin of "TFT Hell Elo" naming, worth confirming with anh as easter egg/branding tie-in)
- (other Set 17 traits not enumerated in spike fixture analysis — Phase 01 champion_aggregator emits whatever appears, no hardcoded list)

## Item taxonomy (8 prefix categories — see riot-match-v5-specs.md for full table)

For Phase 01 anomaly_aggregator, target prefix:
- **`TFT17_EkkoOffering_*`** — Anomaly mechanic, Set 17's augment analog. ~74 instances in 9529 items (~0.8%). Note: this means anomalies are a relatively rare per-match event, NOT every unit gets one.

Concrete example (from spike): `TFT17_EkkoOffering_AnomalyItem` is the most-observed instance. Other variants likely exist but not enumerated in spike output.

For other items rendered in App UI (display name nice-formatting), v0.1 ships raw IDs. v0.2 may add Data Dragon mapping.

## Queue IDs in active use

- `1100` = Ranked TFT (Phase 01 target)
- `1090` = Normal TFT (filtered out by Phase 01)
- Other queues (Hyper Roll, Double Up) absent from Challenger play in spike data — irrelevant to tier list.

## Set 17 anomaly UI implication

Plain language: in older sets, players picked **augments** at rounds 2-1, 3-2, 4-2 — major decision points. In Set 17, players **buy/equip Anomaly items** through the Ekko Offering mechanic instead. Same strategic role: long-tail buff that shapes a comp's identity.

For App UI: Anomaly chips on a comp = "if you play this comp in Set 17, this is the anomaly to chase". Direct UX equivalent to old "augments to pick" recommendation.

## Sample size signal — Set 17 specifics

In 98 KR Challenger matches × 8 participants = 784 participant slots, only 74 carried a `TFT17_EkkoOffering_*` item (9.4%). Implication for tier list quality:
- Even top comps may have <30 anomaly observations → low statistical confidence on per-anomaly recommendation.
- Phase 01 spec uses `agreement >= 0.40` threshold (40% of comp instances must run this anomaly to recommend). Likely yields 0-2 anomalies per comp in v0.1, NOT always 3.

App UI handles empty `anomalies[]` array gracefully (renders nothing).

## Open: Anomaly metadata

Riot Data Dragon may expose Anomaly display names + descriptions per ID. Out of scope for v0.1 — App displays raw IDs (or stripped form like "AnomalyItem"). v0.2 enrichment task.

## Open: Set 18 release timing

No public schedule known. Riot Set cadence historically ~3-4 months. Set 17 launched March 2026 estimate. Set 18 likely Q3-Q4 2026.

When Set 18 ships:
- `tft_set_number` becomes 18 → `test_match_is_tft_set_17` FAILS LOUD.
- Anh updates fixtures, regression tests, character_id prefix expectations (`TFT18_*`).
- Aggregator code is set-agnostic (treats IDs as opaque strings) — no logic change needed beyond prefix updates.
- Anomaly mechanic may persist, may revert to augments, may be replaced. Anh spikes new schema and pivots Phase 01 anomaly_aggregator accordingly.

This is a deferred problem; v0.1 ships against Set 17.
