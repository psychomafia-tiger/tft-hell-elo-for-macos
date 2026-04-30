# Handoff — Phase 4: Positioning Hex Grid

**Date**: 2026-04-29 15:20 ICT
**Branch**: `feat/v0.1-implementation` (clean, all pushed up to `e0d1479`)
**Predecessor**: `handoff-260428-1057-phase-4-pending.md`
**Plan**: `plans/260426-1752-tftactics-feature-parity/phase-04-positioning-hex-grid.md`

---

## Resume command (next session)

```bash
cd "/Users/mac/Desktop/TFTTACTICS FOR MACS" && cat plans/reports/handoff-260429-1520-phase4-hex-grid-pending.md
```

---

## Session summary (what was done 2026-04-28 → 2026-04-29)

| Commit | Change |
|---|---|
| `e256c1e` | Phase 4 cleanup (CompCardItemsRow removed) + docs sync |
| `2312312` | TraitChip vertical pill fix (lineLimit + prefix 6) |
| `c6a1b24` | traitsRow hidden from collapsed card |
| `9b07626` | Traits in expanded card (2-row TraitBadge grid) |
| `57f015f` | Expanded card: carousel + LV.9 as portrait icons |
| `f4f6a8f` | TraitBadge — icon-only + .help() tooltip (must-have) |
| `60d94cf` | TraitBadge centering fix + inactive trait filter + sample regen |
| `91c017a` | ItemBadge size param + 8-champ cap + lv9 overflow |
| `83fa7b4` | Items on ALL champions (removed isCarry gate) + 30% threshold |
| `e0d1479` | Docs sync: changelog + bugs-log #009-#011 + system-architecture |

**App state**: collapsed card = header + max 8 portraits + anomalies. Expanded = traits (icon badges) + carousel portraits + LV.9 portraits. Items show on any champion with ≥30% consistent build.

---

## Phase 4 — Positioning Hex Grid

**Plan file**: `plans/260426-1752-tftactics-feature-parity/phase-04-positioning-hex-grid.md`

**Goal**: Render a 4×7 hex board in `ExpandedCardView` showing where each champion belongs. Right-side space currently empty — this fills it (anh noted "chỗ đó sẽ là chỗ để fill cái bản đồ sắp xếp tướng" on 2026-04-28 screenshot review).

**TFTactics reference**: `docs/reference_image/tfttactics_windows.png` + screenshots in `plans/260426-1752-tftactics-feature-parity/research/`

---

## Architecture decisions (pre-decided in plan)

### Data source
Riot Match-v5 does NOT expose `units[].position` directly. Strategy:
- **Primary**: Modal position from `participant.units[i]` ordering (Riot encodes board layout implicitly via unit array order in some match versions)
- **Fallback**: Rule-based inference — frontline traits (tank/brawler) → front two rows (rows 1-2), backline traits (mage/sniper) → back rows (rows 3-4)
- **Output**: `positioning: [{championId, hexCol, hexRow, frequency}]` per comp

### Schema bump
`1.2.0 → 1.3.0`. Swift forward-compat decoder retains 1.2.0 support.

### SwiftUI render
`Canvas`-based hex grid (not `LazyVGrid` — hexes use offset coordinate math). `HexCell` shows `ChampionPortrait(size: 28)`.

---

## Files to CREATE

### Pipeline
- `Pipeline/src/tftmac_pipeline/positioning_aggregator.py` — extracts per-comp hex positions from match data
- `Pipeline/tests/test_positioning_aggregator.py` — unit tests

### App
- `App/TFTMac/Models/Position.swift` — `struct Position: Codable { let championId: String; let hexCol: Int; let hexRow: Int; let frequency: Double }`
- `App/TFTMac/Views/HexGridView.swift` — SwiftUI Canvas, 4 rows × 7 cols, pointy-top hex offset coords
- `App/TFTMac/Views/HexCell.swift` — single hex cell with `ChampionPortrait(size:28)` inside
- `App/TFTMacTests/HexGridGeometryTests.swift` — pixel coordinate math tests

## Files to MODIFY

- `App/TFTMac/Models/Comp.swift` — add `let positioning: [Position]` with `decodeIfPresent ?? []`
- `App/TFTMac/Views/ExpandedCardView.swift` — add `positioningSection` in body + 2-column layout (traits/carousel left | hex grid right)
- `Pipeline/src/tftmac_pipeline/run_aggregator.py` — call `positioning_aggregator` in `build_tier_list_payload`
- `Pipeline/src/tftmac_pipeline/json_emitter.py` — emit `positioning[]` field in `emit_comp`
- `App/TFTMac/Resources/sample-tier-list.json` — regenerate after pipeline adds positioning

---

## Hex coordinate math (implement this exactly)

TFT board = 4 rows × 7 cols (rows 0-3, cols 0-6). Pointy-top hexes with offset:
- Odd rows shift right by 0.5 × hex_width
- `x = col * hex_width + (row % 2 == 1 ? hex_width/2 : 0)`
- `y = row * hex_height * 0.75`

For `HexGridView`, use `Canvas { ctx, size in ... }`. Draw each occupied hex as a hexagonal path (6 vertices), then overlay `ChampionPortrait(size:28)`.

**Example** (concrete numbers): hex_width=44pt, hex_height=38pt. Cell (col=3, row=1) → x = 3×44 + 22 = 154pt, y = 1×28.5 = 28.5pt.

---

## Known risk

Riot Match-v5 may not expose position data at all for Set 17 — this is unverified. Before building HexGridView, first verify fixture has position data:

```bash
cd Pipeline && python3 -c "
import json
with open('tests/fixtures/fetched-matches-kr-2026-04-24.json') as f:
    m = json.load(f)
u = m[0]['info']['participants'][0]['units'][0]
print('Unit keys:', list(u.keys()))
"
```

Expected: `character_id, itemNames, name, rarity, tier` — NO position field. If confirmed, fall back to rule-based inference from trait data.

**Rule-based fallback** (implement if no position field):
- Champions with traits containing "Tank", "Shield", "Brawler", "Frontline" → rows 0-1
- Champions with traits containing "Sniper", "Assassin" → rows 2-3 (assassins prefer back)
- Default → distribute evenly row 1-2
- Col assignment: sort by cost DESC, place high-cost in center cols (3,4), cheaper to edges

---

## Implementation order

1. **Verify fixture data** (5 min) — check if position field exists
2. **`positioning_aggregator.py`** + tests (30 min) — rule-based inference if no position field
3. **`Position.swift` model** (5 min)
4. **`HexCell.swift`** (15 min) — single hex with portrait
5. **`HexGridView.swift`** (30 min) — Canvas render + coordinate math
6. **`ExpandedCardView` integration** (20 min) — 2-col layout with hex on right
7. **Pipeline integration + sample regen** (15 min)
8. **Tests** (15 min)
9. **Docs sync** per Phase Completion Protocol

Total estimate: ~2.5h.

---

## Current state of ExpandedCardView for context

```swift
var body: some View {
    VStack(alignment: .leading, spacing: 10) {
        traitsSection       // TraitBadge row
        Divider()
        carouselSection     // ChampionPortrait × 3 + chevrons
        Divider()
        lv9Section          // LV.9 > ChampionPortrait × 3
    }
}
```

Phase 4 adds a 2-column `HStack` wrapping `[traitsSection + carouselSection + lv9Section | positioningSection]` when positioning data is available. Degrades gracefully to current single-column layout if `comp.positioning.isEmpty`.

---

## Repo state

- **Branch**: `feat/v0.1-implementation` at `e0d1479` (2026-04-29 15:20 ICT)
- **Main**: `bfa5043` (schema 1.1.0, no traits — 38 commits behind feat)
- **Workflow schedule**: DISABLED (re-enable after feat merges to main)
- **Working tree**: clean

---

## After Phase 4

1. Merge `feat/v0.1-implementation` → `main`
2. `gh workflow enable tft-data-refresh.yml`
3. Refresh Riot Dev API key (24h expiry) via `gh secret set RIOT_API_KEY`
4. Run smoke test on production build
5. Package `.dmg` and send to anh (first tester)

---

## Unresolved

1. Riot Match-v5 Set 17 position field existence — must verify at session start before building.
2. If rule-based fallback, accuracy of frontline/backline inference vs actual player positioning — low priority for v0.1, can refine with real data after ship.
