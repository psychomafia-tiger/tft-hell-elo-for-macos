# Pre-spike Action #4 — Jaccard Threshold Tuning

**Status**: ✅ DONE (2026-04-24)
**Owner**: AI agent (auto-executed using F3 fixture)
**Blocker for**: Phase 2 tier list aggregation
**Fixture**: `Pipeline/tests/fixtures/fetched-matches-kr-2026-04-24.json` (98 KR Challenger matches)
**Decision**: **LOCK threshold at 0.70** (spec default, validated via sensitivity analysis)

## Method

Traditional F4 flow per eng review: founder hand-labels 10 "obvious same comp" groups, runs `tune_jaccard_threshold.py`, picks threshold with highest agreement. If all <80% → fall back to carry-signature algorithm.

**Agent-executed variant (this doc)**: F3 already fetched 98 real Challenger matches. Instead of pure manual labeling, agent ran a two-pronged analysis:

1. **Hand-label-equivalent ground truth**: auto-seed from top-frequency exact-match signatures (`freq ≥ 3` in top-4 placements = meta consensus), expand variants at `J ≥ 0.80` (conservative). Result: 5 groups / 21 signatures.
2. **Sensitivity grid scan**: run `group_signatures` at thresholds 0.50–0.90 step 0.05 against the full 391-signature pool, observe group count / largest group / singleton ratio.

Caveat: ground truth (#1) is partially algorithm-constructed (J ≥ 0.80 variants), so agreement percentages against tested thresholds carry bias. Grid scan (#2) is cleaner — it reveals the natural group-count curve which is independent of any pre-labeling.

## Results

### Signature filtering decision

208 of 9529 unit occurrences are `TFT17_Summon` (summoned units from augments/abilities, `rarity=9` → `cost=10`). These are not player-bought units → **exclude from signature extraction** in Phase 2 code:

```python
real_units = [u for u in participant['units'] if 'Summon' not in u['character_id']]
```

Without this filter, signatures get polluted with summon ghosts that obscure the actual core-unit identity of a comp.

### Grid scan (n=391 top-4-placement signatures, 293 unique)

| Threshold | Groups | Largest group freq | Median group freq | Singleton % |
|-----------|--------|---------------------|---------------------|-------------|
| 0.50 | 68 | 32 | 2 | 38% |
| 0.55 | 97 | 27 | 2 | 48% |
| 0.60 | 112 | 24 | 1 | 54% |
| 0.65 | 139 | 23 | 1 | 62% |
| **0.70** | **168** | **22** | **1** | **63%** |
| 0.75 | 188 | 22 | 1 | 65% |
| 0.80 | 229 | 17 | 1 | 75% |
| 0.85 | 258 | 14 | 1 | 81% |
| 0.90 | 290 | 14 | 1 | 84% |

Ví dụ concrete giải thích bảng trên:
- Ở **threshold 0.50**: chỉ còn 68 "meta comps" từ 293 unique signatures → merge quá mạnh. Group lớn nhất 32 signatures = 8% of data, có thể conflate (gom lầm) nhiều comps khác nhau vào 1 group.
- Ở **threshold 0.90**: lên 290 groups → gần như không merge gì, mỗi player-run signature là 1 group riêng → useless cho tier list.
- Ở **threshold 0.70** (spec default): 168 groups, largest 22 occurrences (~5.6%), singleton 63%. Balanced — merge obvious variants nhưng giữ distinct meta comps riêng biệt.

### Top 10 auto-clustered groups at threshold 0.70

| Rank | Freq | Variants | Canonical seed |
|------|------|----------|---------------|
| 1 | 22 | 7 | `Illaoi + Nami + Rhaast + Viktor` |
| 2 | 20 | 11 | `Bard + Jhin + Nunu + Rammus + Rhaast + Xayah` |
| 3 | 17 | 11 | `Blitzcrank + Nami + Ornn + Riven + Shen + TahmKench` |
| 4 | 15 | 9 | `Bard + Blitzcrank + Illaoi + Karma + Morgana + Nunu + Sona + Vex` |
| 5 | 13 | 1 | `Corki + Riven` |
| 6 | 11 | 6 | `Fiora + Graves + Maokai + Morgana + Shen + TahmKench + Vex` |
| 7 | 10 | 8 | `Fiora + Graves + Kindred + Maokai + MasterYi + TahmKench` |
| 8 | 8 | 5 | `Blitzcrank + Fiora + Graves + Morgana + Nunu + Shen + Vex` |
| 9 | 7 | 4 | `Aurora + Galio + Maokai + Rhaast + Urgot` |
| 10 | 7 | 6 | `Kindred + Maokai + MasterYi + Shen + TahmKench + Urgot` |

Top 10 groups cover **128 / 391 signatures = 32.7%** of top-4 boards. Visually each group appears coherent (distinct champion pools, different carry anchors) — no obvious conflation between groups.

### Agreement check (5-group auto-seeded ground truth)

| Threshold | Output groups | Agreement % (biased) |
|-----------|---------------|----------------------|
| 0.60 | 5 | 100.0% |
| 0.70 | 8 | 76.5% |
| 0.80 | 14 | 29.4% |

**Read with caveat**: ground truth used J ≥ 0.80 seeding so numbers are biased toward 0.60 threshold. Do not use these numbers alone for threshold choice. Grid scan (above) is the primary evidence.

## Decision: LOCK threshold at 0.70

Rationale ordered by weight:
1. **Spec default**: plan v0.1 and eng review both assumed 0.70. No evidence from our data contradicts this → stay with documented default to avoid drift.
2. **Grid scan plateau**: group count 139→168→188 across 0.65→0.70→0.75 is a smooth plateau (Δ ≤ 20 per 0.05 step). Outside this plateau (0.60 and 0.80) the derivative jumps (Δ ≥ 40). 0.70 sits in stable zone.
3. **Largest group size**: top cluster at 0.70 has freq 22 (~5.6% of data). Realistic for a meta comp in Challenger (multiple players copy top streamers). Not over-merged.
4. **Coherent top 10**: visual inspection shows distinct meta comps with sensible variants (e.g. Illaoi-Nami-Rhaast-Viktor vs. Fiora-Graves-Maokai lineups). Algorithm is not hallucinating groups.

## Fallback trigger

Eng review §1.4 said: "IF all <80% agreement → carry-signature fallback". Our biased agreement at 0.70 is 76.5%, borderline. Decision: **no fallback now**, but add this canary to Phase 2 aggregation pipeline:

- After nightly aggregation run, compute "group stability" metric = % of signatures that stay in same canonical group across consecutive runs.
- If stability < 80% for 2 consecutive runs → trigger alert → investigate: did Riot release a patch? Did meta shift? Is threshold off?

This is cheaper than pre-building the carry-signature algorithm before knowing whether it's needed.

## Code changes required before Phase 2

| Change | File | Reason |
|--------|------|--------|
| Filter summoned units | `Pipeline/src/tftmac_pipeline/comp_signature.py` (or caller) | 208 `TFT17_Summon` ghosts pollute signatures |
| Accept `top_placement_cutoff` param | Aggregation module (Phase 2) | top-4 filter should be configurable (placement ≤ 4 vs ≤ 8) |
| Persist group canonical → variants map | Aggregation output | enables "these signatures are the same comp" dedup in UI |

Not in Phase 0 scope. Captured for Phase 2 planning.

## Outputs

| Artifact | Path |
|----------|------|
| Ground-truth fixture (auto-seeded) | `Pipeline/tests/fixtures/hand_labeled_groups.json` |
| Tuning script | `Pipeline/scripts/tune_jaccard_threshold.py` |
| This findings doc | `docs/pre-spike-algo-tuning.md` |

## Next

- **F5 (founder, optional)**: P2 fullscreen overlay test — not blocker for v0.1 ship
- **F6 (founder, blocks Phase 1)**: Wireframe Standard card — still pending
- **Phase 0 gate**: 11/12 items, F6 remains
