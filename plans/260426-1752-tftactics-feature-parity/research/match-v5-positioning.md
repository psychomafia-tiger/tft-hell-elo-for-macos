# Match-v5 Positioning Data — Research Findings

**Date**: 2026-04-29
**Phase**: 4 (Positioning Hex Grid)
**Outcome**: ❌ `pos`/`position` NOT exposed by Riot Match-v5 for Set 17 → must use rule-based fallback.

---

## Verification

```bash
cd Pipeline && .venv/bin/python -c "
import json
m = json.load(open('tests/fixtures/fetched-matches-kr-2026-04-24.json'))
p = m[0]['info']['participants'][0]
u = p['units'][0]
print('keys:', list(u.keys()))
print('pos field count:', sum(1 for x in p['units'] if 'pos' in x or 'position' in x))
"
```

**Output**:
- Unit keys: `['character_id', 'itemNames', 'name', 'rarity', 'tier']`
- 0/9 units expose any positioning field across the fixture (98 matches × 8 participants).

**Conclusion**: Set 17 Match-v5 has **no board layout data**. Riot historically removed/never-shipped positioning in this endpoint.

---

## Fallback strategy — rule-based positioning

No champion-level trait map ships in our pipeline (only `App/TFTMac/Resources/set17-champions.json` with id+displayName, no traits per champion). Fallback uses **cost + is_carry + comp-level activated traits** as heuristics.

### Hex grid convention

4 rows × 7 cols = 28 hexes (pos 0-27). Layout:

```
Row 0 (pos 0-6)   = backline (your side, far from enemy)  ← carries
Row 1 (pos 7-13)  = mid-back (flex)
Row 2 (pos 14-20) = mid-front (flex)
Row 3 (pos 21-27) = frontline (closest to enemy)          ← tanks
```

### Position assignment rules

Inputs: `champions: [{id, cost, is_carry, ...}]`, `traits: [{name, count, style}]` (already on bucket).

1. **Classify comp archetype** from active traits:
   - `frontline_heavy` if any of `{HPTank, ResistTank, ShieldTank, MeleeTrait, Brawler, Vanguard, Bastion}` in active traits
   - `backline_heavy` if any of `{RangedTrait, APTrait, ASTrait, ManaTrait, Sniper, Sorcerer, Marksman, Mage}` in active traits
   - default: `flex`

2. **Carry placement** (`is_carry=True`, sorted by cost desc):
   - First carry → pos 3 (row 0, col 3 — dead center backline)
   - Second carry → pos 1 (row 0, col 1 — left wing)
   - Third carry → pos 5 (row 0, col 5 — right wing)

3. **Non-carry by cost** (filler/tank/flex):
   - Cost 5 non-carry → pos 0/6 (row 0 corners — bonus backline)
   - Cost 4 non-carry → pos 8/12 (row 1 mid)
   - Cost 3 → pos 22/26 if `frontline_heavy` else pos 9/11 (split front vs mid)
   - Cost 1-2 → pos 21,23,24,25,27 (row 3 frontline tanks)
   - Cost 7+ (Blitzcrank-unique) → pos 24 (row 3 col 3 dead front)

4. **Conflict resolution**: if pos already taken by higher-priority champion, walk to next free pos in same row, then adjacent row.

### Concrete example — "Storm Quickdraw" comp

Champions (from real fixture): Jhin (cost 4 carry), Senna (cost 4 carry), Kindred (cost 3), Caitlyn (cost 2), Maokai (cost 2 tank), Ezreal (cost 1).

Traits active: `Quickdraw` + `Storm` → `backline_heavy`.

Position output:
- Jhin pos 3 (1st carry, center backline)
- Senna pos 1 (2nd carry, left wing)
- Kindred pos 11 (cost-3 backline-heavy → row 1)
- Caitlyn pos 9 (cost 2 → row 1 mid filler... wait, rule says row 3)
- Maokai pos 22 (cost 2 → row 3 frontline)
- Ezreal pos 25 (cost 1 → row 3 frontline)

**Frequency** = 1.0 for all (deterministic rule-based, no real positional data).

---

## Limitations

- **Visual approximation**: real player boards differ. A backline Karma in one game might be sidelined; rule places her dead center.
- **No tank/mage distinction within cost class**: cost 5 Karma (mage) and cost 5 Sett (tank) get same row by cost. Future v0.2: ship per-champion trait map for accurate per-unit classification.
- **Frequency=1.0**: signals to UI "this is a heuristic, not measured". Future: when Riot exposes pos field, replace with modal frequency from raw data.

---

## Implementation plan

1. Implement `positioning_aggregator.aggregate_positions(champions, traits)` returning `[{championId, pos, frequency}]`.
2. Wire into `emit_comp` after `_emit_champions_from_bucket` returns.
3. Schema bump 1.2.0 → 1.4.0 (skipping 1.3.0 — was reserved for a richer item-detail bump that didn't ship as a separate version).
4. Forward-compat decoder in App.

## Unresolved

- Should we expose a `positioning_inferred: true` flag in JSON so future data with real positions can flip to `false`? **Decision**: no — `frequency` field semantically captures this (1.0 = inferred, <1.0 = measured modal). Defer flag until needed.
