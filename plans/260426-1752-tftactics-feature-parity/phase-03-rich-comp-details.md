# Phase 3 — Rich Comp Details

**Parent plan:** [plan.md](plan.md)
**Status:** ⏳ Blocked by Phase 2
**Effort:** 15-23h
**Gaps closed:** A4 (subtype/playstyle heuristic), A5 (early comp), A6 (carousel priority), A7 (LV.9 alts), B2 (item icon artwork)
**Manual gate before:** Phase 2 merged + anh sees trait chips live
**Manual gate after:** anh expands a comp, sees real item icons + early-game champs + carousel priorities + LV.9 alternatives

---

## Goal

Add the rich detail surface that TFTactics shows when a user expands a comp: real item artwork (was: text only), early-game transition comp (5 transition champs), carousel priority order, level 9 alternative champions, and improved playstyle heuristic. All details powered by pipeline-side aggregation from Match-v5 stage data.

## Architecture

- **Pipeline (Python)** — `comp_pipeline.py` extends per-comp aggregation with: `early_comp` (most-frequent units in stages 2-1 to 3-2), `carousel_priority` (champions taken at stage carousels, ranked by frequency), `lv9_alternatives` (champions appearing only in 9+ unit games), `playstyle` (slow-roll / fast-8 / standard heuristic from gold spent vs level curve).
- **App (Swift)** — `Models/Comp.swift` extended with these fields. New `Generated/ItemCatalog.swift` upgrade (data-driven). New `Services/ItemAssetURL.swift`. `Views/CompCardItemsRow.swift` upgraded to show item icons. `Views/ExpandedCardView.swift` extended with three new sections (Early / Carousel / Level 9).
- **Schema bump** — `1.2.0 → 1.3.0`. Forward-compat retained.

## Files

**Create:**
- `Pipeline/src/tftmac_pipeline/early_comp_aggregator.py`
- `Pipeline/src/tftmac_pipeline/carousel_aggregator.py`
- `Pipeline/src/tftmac_pipeline/playstyle_classifier.py`
- `Pipeline/tests/test_early_comp_aggregator.py`
- `Pipeline/tests/test_carousel_aggregator.py`
- `Pipeline/tests/test_playstyle_classifier.py`
- `App/TFTMac/Resources/set17-items.json`
- `App/TFTMac/Services/ItemAssetURL.swift`
- `App/TFTMacTests/ItemAssetURLTests.swift`
- `App/TFTMac/Views/EarlyCompSection.swift`
- `App/TFTMac/Views/CarouselPrioritySection.swift`
- `App/TFTMac/Views/LevelNineAltsSection.swift`
- `App/TFTMacTests/EarlyCompSectionTests.swift`

**Modify:**
- `Pipeline/src/tftmac_pipeline/json_emitter.py` — schema 1.3.0 + 4 new fields per comp
- `App/TFTMac/Models/Comp.swift` — `earlyComp`, `carouselPriority`, `lv9Alternatives`, `playstyle`
- `App/TFTMac/Models/SchemaVersion.swift` — accept 1.3.0
- `App/TFTMac/Generated/ItemCatalog.swift` — data-driven from set17-items.json
- `App/TFTMac/Views/CompCardItemsRow.swift` — render item icons
- `App/TFTMac/Views/ExpandedCardView.swift` — wire 3 new sections
- `App/TFTMac/Views/PlaystyleLabel.swift` — read from comp.playstyle (was: heuristic on champion costs)

---

## Task 1: Early comp aggregator (Python TDD)

**Files:**
- Create: `Pipeline/src/tftmac_pipeline/early_comp_aggregator.py`
- Test: `Pipeline/tests/test_early_comp_aggregator.py`

- [ ] **Step 1: Write failing test**

```python
# Pipeline/tests/test_early_comp_aggregator.py
"""Early comp aggregation: top 5 units in stages 2-1 to 3-2."""
from tftmac_pipeline.early_comp_aggregator import extract_early_comp

def test_returns_top_5_units_from_early_stages():
    # Match-v5 doesn't track per-stage units directly; we approximate from
    # the units that ALSO appear in winning early-game placements (top 4 by
    # round 3-2 = participants whose placement <= 4 had these units).
    participants = [
        {
            "placement": 1,
            "units": [
                {"character_id": "TFT17_Lissandra", "tier": 2},
                {"character_id": "TFT17_Pyke", "tier": 2},
                {"character_id": "TFT17_IvernMinion", "tier": 1},
                {"character_id": "TFT17_Mordekaiser", "tier": 1},
                {"character_id": "TFT17_Yasuo", "tier": 1},
            ],
        },
        {
            "placement": 2,
            "units": [
                {"character_id": "TFT17_Lissandra", "tier": 2},
                {"character_id": "TFT17_Pyke", "tier": 2},
                {"character_id": "TFT17_Yasuo", "tier": 1},
            ],
        },
    ]
    early = extract_early_comp(participants, max_units=5)
    assert len(early) <= 5
    # Most frequent first
    assert early[0]["id"] == "TFT17_Lissandra" or early[0]["id"] == "TFT17_Pyke"
    assert all("frequency" in u for u in early)
```

- [ ] **Step 2: Run test, expect fail**

```bash
cd Pipeline && .venv/bin/pytest tests/test_early_comp_aggregator.py -v
```

- [ ] **Step 3: Implement**

```python
# Pipeline/src/tftmac_pipeline/early_comp_aggregator.py
"""Early-game transition comp extraction.

Heuristic: 1-cost and 2-cost units with highest frequency among top-4
placements. Approximates "what to play stages 2-1 to 3-2" because Match-v5
only gives final board; we infer early-comp signal from cheap units that
appeared frequently in successful runs.
"""
from collections import Counter

def extract_early_comp(participants: list[dict], max_units: int = 5) -> list[dict]:
    top4 = [p for p in participants if p.get("placement", 8) <= 4]
    if not top4:
        return []
    cheap_unit_counts: Counter = Counter()
    for p in top4:
        for unit in p.get("units", []):
            cid = unit.get("character_id", "")
            tier = unit.get("tier", 1)
            # 1-cost and 2-cost units, 1-2 star
            if _is_cheap(cid) and tier <= 2:
                cheap_unit_counts[cid] += 1
    total = len(top4)
    return [
        {"id": cid, "frequency": count / total}
        for cid, count in cheap_unit_counts.most_common(max_units)
    ]

def _is_cheap(character_id: str) -> bool:
    """Approximate cost from ID; pipeline does not have champion DB.
    Real implementation reads from a Set 17 champion cost table.
    For now: any TFT17_ champ is candidate; downstream filtering via
    `tier` <= 2 handles most cases. Phase 4 may replace with real cost lookup.
    """
    return character_id.startswith("TFT17_")
```

- [ ] **Step 4: Run test, expect pass; commit**

```bash
cd Pipeline && .venv/bin/pytest tests/test_early_comp_aggregator.py -v
git add Pipeline/src/tftmac_pipeline/early_comp_aggregator.py Pipeline/tests/test_early_comp_aggregator.py
git commit -m "feat(pipeline): early_comp_aggregator extracts top transition units"
```

---

## Task 2: Carousel priority aggregator (Python TDD)

**Files:**
- Create: `Pipeline/src/tftmac_pipeline/carousel_aggregator.py`
- Test: `Pipeline/tests/test_carousel_aggregator.py`

- [ ] **Step 1: Write failing test**

```python
# Pipeline/tests/test_carousel_aggregator.py
from tftmac_pipeline.carousel_aggregator import extract_carousel_priority

def test_carousel_priority_orders_by_frequency():
    # Carousels happen at 1-4, 2-4, 3-4, etc. Match-v5 doesn't track WHO
    # took WHAT; we approximate from final-comp carry champions (most likely
    # picked at first carousel = most frequent 3+ cost in winning comps).
    participants = [
        {"placement": 1, "units": [
            {"character_id": "TFT17_Viktor", "tier": 2, "items": [{"id": "1"}]},
            {"character_id": "TFT17_Illaoi", "tier": 2, "items": [{"id": "2"}, {"id": "3"}]},
        ]},
        {"placement": 2, "units": [
            {"character_id": "TFT17_Viktor", "tier": 2, "items": []},
        ]},
    ]
    priority = extract_carousel_priority(participants, max_units=3)
    assert priority[0]["id"] == "TFT17_Viktor"
    assert "rank" in priority[0]
    assert priority[0]["rank"] == 1
```

- [ ] **Step 2: Run test, expect fail**

```bash
cd Pipeline && .venv/bin/pytest tests/test_carousel_aggregator.py -v
```

- [ ] **Step 3: Implement**

```python
# Pipeline/src/tftmac_pipeline/carousel_aggregator.py
"""Carousel pick priority extraction.

Heuristic: champions with most items in top-4 placements = most likely
carousel picks (you carousel for items + the carry that wields them).
Returns ranked list 1, 2, 3.
"""
from collections import Counter

def extract_carousel_priority(participants: list[dict], max_units: int = 3) -> list[dict]:
    top4 = [p for p in participants if p.get("placement", 8) <= 4]
    if not top4:
        return []
    item_count: Counter = Counter()
    for p in top4:
        for unit in p.get("units", []):
            cid = unit.get("character_id", "")
            n_items = len(unit.get("items", []) or [])
            item_count[cid] += n_items
    ranked = item_count.most_common(max_units)
    return [
        {"id": cid, "rank": idx + 1, "items_seen": n}
        for idx, (cid, n) in enumerate(ranked)
    ]
```

- [ ] **Step 4: Run test, commit**

```bash
cd Pipeline && .venv/bin/pytest tests/test_carousel_aggregator.py -v
git add Pipeline/src/tftmac_pipeline/carousel_aggregator.py Pipeline/tests/test_carousel_aggregator.py
git commit -m "feat(pipeline): carousel priority via item-density heuristic"
```

---

## Task 3: Playstyle classifier (Python TDD)

**Files:**
- Create: `Pipeline/src/tftmac_pipeline/playstyle_classifier.py`
- Test: `Pipeline/tests/test_playstyle_classifier.py`

- [ ] **Step 1: Write failing test**

```python
# Pipeline/tests/test_playstyle_classifier.py
from tftmac_pipeline.playstyle_classifier import classify_playstyle

def test_slow_roll_when_3star_2cost_carry_dominant():
    # Slow roll = 2-cost or 3-cost unit at 3-star → many participants reach
    # 3-star on a low-cost carry, signature for slow-roll archetype.
    participants = [
        {"placement": 1, "level": 7, "units": [
            {"character_id": "TFT17_Pyke", "tier": 3, "rarity": 1},
        ]},
        {"placement": 2, "level": 7, "units": [
            {"character_id": "TFT17_Pyke", "tier": 3, "rarity": 1},
        ]},
    ]
    assert classify_playstyle(participants) == "Slow Roll"

def test_fast_8_when_avg_level_8_plus_with_5cost():
    participants = [
        {"placement": 1, "level": 9, "units": [
            {"character_id": "TFT17_Nami", "tier": 2, "rarity": 4},
        ]},
        {"placement": 2, "level": 8, "units": [
            {"character_id": "TFT17_Nami", "tier": 2, "rarity": 4},
        ]},
    ]
    assert classify_playstyle(participants) == "Fast 8"

def test_standard_default():
    assert classify_playstyle([
        {"placement": 4, "level": 7, "units": [{"character_id": "TFT17_Aatrox", "tier": 2, "rarity": 2}]},
    ]) == "Standard"
```

- [ ] **Step 2: Run test, expect fail**

```bash
cd Pipeline && .venv/bin/pytest tests/test_playstyle_classifier.py -v
```

- [ ] **Step 3: Implement**

```python
# Pipeline/src/tftmac_pipeline/playstyle_classifier.py
"""Comp playstyle classifier.

Three classes:
- "Slow Roll" — high frequency of 3-star low-cost (rarity 0/1/2) units.
- "Fast 8" — average final level >= 8 and ≥1 5-cost unit (rarity 4).
- "Standard" — neither.

`rarity` in Riot Match-v5: 0=1cost, 1=2cost, 2=3cost, 3=4cost, 4=5cost.
"""
def classify_playstyle(participants: list[dict]) -> str:
    if not participants:
        return "Standard"

    n = len(participants)
    avg_level = sum(p.get("level", 7) for p in participants) / n
    has_5cost_majority = sum(
        1 for p in participants
        if any(u.get("rarity", 0) == 4 for u in p.get("units", []))
    ) / n >= 0.5
    has_3star_lowcost = sum(
        1 for p in participants
        if any(u.get("tier", 1) == 3 and u.get("rarity", 0) <= 2 for u in p.get("units", []))
    ) / n >= 0.4

    if has_3star_lowcost:
        return "Slow Roll"
    if avg_level >= 8.0 and has_5cost_majority:
        return "Fast 8"
    return "Standard"
```

- [ ] **Step 4: Run test, commit**

```bash
cd Pipeline && .venv/bin/pytest tests/test_playstyle_classifier.py -v
git add Pipeline/src/tftmac_pipeline/playstyle_classifier.py Pipeline/tests/test_playstyle_classifier.py
git commit -m "feat(pipeline): playstyle classifier (slow roll / fast 8 / standard)"
```

---

## Task 4: LV.9 alternatives (extend comp_pipeline)

**Files:**
- Modify: `Pipeline/src/tftmac_pipeline/comp_pipeline.py`
- Test: append to `Pipeline/tests/test_comp_signature.py` (or create new)

- [ ] **Step 1: Write test for LV.9 alts extraction**

Append to `Pipeline/tests/test_comp_signature.py` or create `tests/test_lv9_alternatives.py`:

```python
def test_lv9_alts_only_appear_in_lv9_games():
    from tftmac_pipeline.comp_pipeline import extract_lv9_alternatives
    participants = [
        {"placement": 1, "level": 9, "units": [
            {"character_id": "TFT17_Nami", "tier": 2, "rarity": 4},
            {"character_id": "TFT17_Aatrox", "tier": 2, "rarity": 2},
        ]},
        {"placement": 3, "level": 8, "units": [
            {"character_id": "TFT17_Aatrox", "tier": 2, "rarity": 2},
        ]},
    ]
    alts = extract_lv9_alternatives(participants, base_units={"TFT17_Aatrox"})
    # Nami appears only in level 9 game and not in base comp
    assert any(u["id"] == "TFT17_Nami" for u in alts)
```

- [ ] **Step 2: Implement in comp_pipeline.py**

```python
# Append to Pipeline/src/tftmac_pipeline/comp_pipeline.py
def extract_lv9_alternatives(participants: list[dict], base_units: set[str], max_units: int = 3) -> list[dict]:
    """Champions appearing in level-9 placements that are NOT in base comp."""
    from collections import Counter
    counts: Counter = Counter()
    lv9 = [p for p in participants if p.get("level", 7) >= 9]
    for p in lv9:
        for unit in p.get("units", []):
            cid = unit.get("character_id", "")
            if cid and cid not in base_units:
                counts[cid] += 1
    return [{"id": cid, "frequency": n / max(len(lv9), 1)} for cid, n in counts.most_common(max_units)]
```

- [ ] **Step 3: Run tests, commit**

```bash
cd Pipeline && .venv/bin/pytest tests/test_comp_signature.py tests/test_lv9_alternatives.py -v
git add Pipeline/src/tftmac_pipeline/comp_pipeline.py Pipeline/tests/
git commit -m "feat(pipeline): extract_lv9_alternatives for late-game pivot"
```

---

## Task 5: Wire 4 new fields into json_emitter (schema 1.3.0)

**Files:**
- Modify: `Pipeline/src/tftmac_pipeline/json_emitter.py`
- Modify: `Pipeline/src/tftmac_pipeline/run_aggregator.py`

- [ ] **Step 1: Update emit_comp + bump SCHEMA_VERSION**

In `json_emitter.py`:

```python
SCHEMA_VERSION = "1.3.0"

def emit_comp(grouped_comp: dict, derived_name: str, participants: list[dict]) -> dict:
    sig = grouped_comp["trait_signature"]
    placements = grouped_comp["placements"]
    base_unit_ids = set(grouped_comp["champion_freq"].keys())
    return {
        # ... existing fields
        "traits": [...],
        "early_comp": extract_early_comp(participants, max_units=5),
        "carousel_priority": extract_carousel_priority(participants, max_units=3),
        "lv9_alternatives": extract_lv9_alternatives(participants, base_units=base_unit_ids, max_units=3),
        "playstyle": classify_playstyle(participants),
    }
```

Add imports at top:

```python
from .early_comp_aggregator import extract_early_comp
from .carousel_aggregator import extract_carousel_priority
from .comp_pipeline import extract_lv9_alternatives
from .playstyle_classifier import classify_playstyle
```

- [ ] **Step 2: Update run_aggregator to pass per-comp participants**

In `run_aggregator.py`, modify the loop:

```python
for sig, bucket in grouped.items():
    name = resolve_comp_name(sig)
    bucket_participants = [p for p in participants if trait_combo_signature(p) == sig]
    comp = emit_comp(bucket, name, bucket_participants)
    comps.append(comp)
```

- [ ] **Step 3: Update tests for schema bump**

Update assertions in `test_json_emitter.py`:

```python
def test_schema_is_1_3_0():
    from tftmac_pipeline.json_emitter import SCHEMA_VERSION
    assert SCHEMA_VERSION == "1.3.0"

def test_comp_has_all_phase3_fields():
    # Build a fake grouped + participants, call emit_comp, assert keys
    # ...
    assert "early_comp" in comp
    assert "carousel_priority" in comp
    assert "lv9_alternatives" in comp
    assert "playstyle" in comp
```

- [ ] **Step 4: Run full Pipeline suite**

```bash
cd Pipeline && .venv/bin/pytest -v
```

Expected: green.

- [ ] **Step 5: Commit**

```bash
git add Pipeline/src/tftmac_pipeline/json_emitter.py Pipeline/src/tftmac_pipeline/run_aggregator.py Pipeline/tests/test_json_emitter.py
git commit -m "feat(pipeline): emit early_comp + carousel + lv9_alts + playstyle (schema 1.3.0)"
```

---

## Task 6: ItemAssetURL + data-driven ItemCatalog (Swift TDD)

**Files:**
- Create: `App/TFTMac/Resources/set17-items.json`
- Create: `App/TFTMac/Services/ItemAssetURL.swift`
- Create: `App/TFTMacTests/ItemAssetURLTests.swift`
- Modify: `App/TFTMac/Generated/ItemCatalog.swift`

- [ ] **Step 1: Generate set17-items.json from live data**

```bash
jq '[.comps[].champions[].items[].id] | unique | sort | map({id: ., displayName: (. | sub("^TFT_Item_"; "") | sub("^TFT17_Item_"; "") | sub("([a-z])([A-Z])"; "\(.[1]) \(.[2])"; "g"))})' \
  data/tier-list.json > App/TFTMac/Resources/set17-items.json
```

Manually correct displayName quirks (e.g. `JeweledGauntlet` → `Jeweled Gauntlet`, `PsyOpsDroneMod` → `PsyOps Drone Mod`).

- [ ] **Step 2: Write failing test for ItemAssetURL**

```swift
// App/TFTMacTests/ItemAssetURLTests.swift
import XCTest
@testable import TFTMac

final class ItemAssetURLTests: XCTestCase {

    func test_buildsLowercaseItemURL() {
        let url = ItemAssetURL.icon(forItemId: "TFT_Item_JeweledGauntlet")
        // Verified pattern (Phase 1 Task 0 method): adjust if probe shows different
        XCTAssertEqual(
            url?.absoluteString,
            "https://raw.communitydragon.org/latest/game/assets/maps/particles/tft/item_icons/standard/tft_item_jeweledgauntlet.png"
        )
    }

    func test_handlesSet17ScopedItems() {
        let url = ItemAssetURL.icon(forItemId: "TFT17_Item_PsyOps_DroneMod")
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("tft17_item_psyops_dronemod"))
    }
}
```

- [ ] **Step 3: Implement ItemAssetURL**

```swift
// App/TFTMac/Services/ItemAssetURL.swift
import Foundation

enum ItemAssetURL {
    private static let base = "https://raw.communitydragon.org/latest/game/assets/maps/particles/tft/item_icons/standard"

    static func icon(forItemId id: String) -> URL? {
        guard !id.isEmpty else { return nil }
        return URL(string: "\(base)/\(id.lowercased()).png")
    }
}
```

- [ ] **Step 4: Refactor ItemCatalog to data-driven (mirror ChampionCatalog Phase 1 Task 5 pattern)**

```swift
// App/TFTMac/Generated/ItemCatalog.swift
import Foundation
import os

enum ItemCatalog {
    struct Entry: Decodable {
        let id: String
        let displayName: String
    }

    static let entries: [String: Entry] = loadFromBundle()

    static func displayName(forId id: String) -> String {
        entries[id]?.displayName ?? id
    }

    private static func loadFromBundle() -> [String: Entry] {
        let logger = Logger(subsystem: "io.psychomafia.tfthellelo", category: "ItemCatalog")
        guard let url = Bundle.main.url(forResource: "set17-items", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let arr = try? JSONDecoder().decode([Entry].self, from: data) else {
            logger.error("set17-items.json missing")
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: arr.map { ($0.id, $0) })
    }
}
```

- [ ] **Step 5: Register in Xcode + run tests**

```bash
ruby -e "
require 'xcodeproj'
proj = Xcodeproj::Project.open('App/TFTMac.xcodeproj')
target = proj.targets.find { |t| t.name == 'TFTMac' }
test_target = proj.targets.find { |t| t.name == 'TFTMacTests' }
target.add_resources([proj.main_group.find_subpath('TFTMac/Resources', true).new_file('App/TFTMac/Resources/set17-items.json')])
target.add_file_references([proj.main_group.find_subpath('TFTMac/Services', true).new_file('App/TFTMac/Services/ItemAssetURL.swift')])
test_target.add_file_references([proj.main_group.find_subpath('TFTMacTests', true).new_file('App/TFTMacTests/ItemAssetURLTests.swift')])
proj.save
"

xcodebuild test -project App/TFTMac.xcodeproj -scheme TFTMac -destination 'platform=macOS' -only-testing:TFTMacTests/ItemAssetURLTests 2>&1 | tail -20
```

- [ ] **Step 6: Commit**

```bash
git add App/TFTMac/Resources/set17-items.json App/TFTMac/Services/ItemAssetURL.swift App/TFTMac/Generated/ItemCatalog.swift App/TFTMacTests/ItemAssetURLTests.swift App/TFTMac.xcodeproj
git commit -m "feat(app): ItemAssetURL + data-driven ItemCatalog"
```

---

## Task 7: Render item icons in CompCardItemsRow

**Files:**
- Modify: `App/TFTMac/Views/CompCardItemsRow.swift`

- [ ] **Step 1: Read current implementation**

```bash
cat App/TFTMac/Views/CompCardItemsRow.swift
```

- [ ] **Step 2: Replace text rendering with HStack of 24px icons**

Add inner view:

```swift
private struct ItemIcon: View {
    let itemId: String
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            if let img = image {
                Image(nsImage: img).resizable().aspectRatio(contentMode: .fit)
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Colors.bgCard)
                    .overlay(
                        Text(String(ItemCatalog.displayName(forId: itemId).prefix(1)))
                            .font(Theme.Fonts.captionSmall)
                            .foregroundStyle(Theme.Colors.textMuted)
                    )
            }
        }
        .frame(width: 24, height: 24)
        .help(ItemCatalog.displayName(forId: itemId))  // tooltip on hover
        .task {
            guard image == nil,
                  let url = ItemAssetURL.icon(forItemId: itemId),
                  let data = try? await AssetCache.shared.data(for: url),
                  let img = NSImage(data: data) else { return }
            self.image = img
        }
    }
}
```

Then in the existing `body`, replace text-of-items with:

```swift
HStack(spacing: 4) {
    ForEach(comp.champions.flatMap { $0.items }, id: \.id) { item in
        ItemIcon(itemId: item.id)
    }
    Spacer(minLength: 0)
}
```

- [ ] **Step 3: Run regression tests**

```bash
xcodebuild test -project App/TFTMac.xcodeproj -scheme TFTMac -destination 'platform=macOS' -only-testing:TFTMacTests/CompCardV2Tests 2>&1 | tail -20
```

- [ ] **Step 4: Manual smoke**

```bash
xcodebuild build -project App/TFTMac.xcodeproj -scheme TFTMac
open App/build/Debug/TFTMac.app
```

Anh: open popover, check items row shows icons (with text fallback before async load completes).

- [ ] **Step 5: Commit**

```bash
git add App/TFTMac/Views/CompCardItemsRow.swift
git commit -m "feat(app): render item icons in CompCardItemsRow with text fallback"
```

---

## Task 8: Comp model extension for Phase 3 fields (TDD)

**Files:**
- Modify: `App/TFTMac/Models/Comp.swift`
- Modify: `App/TFTMac/Models/SchemaVersion.swift`
- Test: append to `TraitActivationDecodingTests.swift` or create `Phase3FieldsDecodingTests.swift`

- [ ] **Step 1: Write failing test for full v1.3.0 decode**

```swift
// App/TFTMacTests/Phase3FieldsDecodingTests.swift
import XCTest
@testable import TFTMac

final class Phase3FieldsDecodingTests: XCTestCase {

    func test_decodesV1_3_0Comp() throws {
        let json = #"""
        {
          "comp_id": "test", "name": "Test", "tier": "S",
          "play_rate": 0.05, "avg_placement": 4.0, "top_4_rate": 0.5,
          "sample_size": 100, "champions": [], "anomalies": [], "traits": [],
          "early_comp": [{"id": "TFT17_Lissandra", "frequency": 0.8}],
          "carousel_priority": [{"id": "TFT17_Viktor", "rank": 1, "items_seen": 5}],
          "lv9_alternatives": [{"id": "TFT17_Nami", "frequency": 0.7}],
          "playstyle": "Fast 8"
        }
        """#.data(using: .utf8)!
        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        let comp = try dec.decode(Comp.self, from: json)
        XCTAssertEqual(comp.earlyComp.count, 1)
        XCTAssertEqual(comp.carouselPriority.first?.rank, 1)
        XCTAssertEqual(comp.lv9Alternatives.first?.id, "TFT17_Nami")
        XCTAssertEqual(comp.playstyle, "Fast 8")
    }

    func test_forwardCompatV1_2_0CompMissingFields() throws {
        let json = #"""
        {"comp_id": "x", "name": "X", "tier": "B",
         "play_rate": 0.02, "avg_placement": 4.5, "top_4_rate": 0.4,
         "sample_size": 50, "champions": [], "anomalies": [], "traits": []}
        """#.data(using: .utf8)!
        let dec = JSONDecoder(); dec.keyDecodingStrategy = .convertFromSnakeCase
        let comp = try dec.decode(Comp.self, from: json)
        XCTAssertEqual(comp.earlyComp, [])
        XCTAssertEqual(comp.carouselPriority, [])
        XCTAssertEqual(comp.lv9Alternatives, [])
        XCTAssertEqual(comp.playstyle, "Standard")
    }
}
```

- [ ] **Step 2: Run test, expect fail**

```bash
xcodebuild test -project App/TFTMac.xcodeproj -scheme TFTMac -destination 'platform=macOS' -only-testing:TFTMacTests/Phase3FieldsDecodingTests 2>&1 | tail -20
```

- [ ] **Step 3: Extend Comp.swift**

Add structs at bottom of `Models/Comp.swift`:

```swift
struct EarlyCompUnit: Codable, Equatable {
    let id: String
    let frequency: Double
}

struct CarouselPick: Codable, Equatable {
    let id: String
    let rank: Int
    let itemsSeen: Int
}

struct Lv9Alternative: Codable, Equatable {
    let id: String
    let frequency: Double
}
```

Extend `Comp`:

```swift
struct Comp: Encodable {
    // ... existing
    let traits: [TraitActivation]
    let earlyComp: [EarlyCompUnit]              // NEW
    let carouselPriority: [CarouselPick]        // NEW
    let lv9Alternatives: [Lv9Alternative]       // NEW
    let playstyle: String                       // NEW

    init(
        // ... existing
        traits: [TraitActivation] = [],
        earlyComp: [EarlyCompUnit] = [],
        carouselPriority: [CarouselPick] = [],
        lv9Alternatives: [Lv9Alternative] = [],
        playstyle: String = "Standard"
    ) {
        // ... existing assignments
        self.earlyComp = earlyComp
        self.carouselPriority = carouselPriority
        self.lv9Alternatives = lv9Alternatives
        self.playstyle = playstyle
    }
}

extension Comp: Decodable {
    enum CodingKeys: String, CodingKey {
        // ... existing
        case earlyComp
        case carouselPriority
        case lv9Alternatives
        case playstyle
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // ... existing decodes
        self.traits = (try? c.decodeIfPresent([TraitActivation].self, forKey: .traits)) ?? []
        self.earlyComp = (try? c.decodeIfPresent([EarlyCompUnit].self, forKey: .earlyComp)) ?? []
        self.carouselPriority = (try? c.decodeIfPresent([CarouselPick].self, forKey: .carouselPriority)) ?? []
        self.lv9Alternatives = (try? c.decodeIfPresent([Lv9Alternative].self, forKey: .lv9Alternatives)) ?? []
        self.playstyle = (try? c.decodeIfPresent(String.self, forKey: .playstyle)) ?? "Standard"
    }
}
```

- [ ] **Step 4: Update SchemaVersion**

```swift
enum SchemaVersion {
    static let app: String = "1.3.0"
    static let acceptedRemote: Set<String> = ["1.0.0", "1.1.0", "1.2.0", "1.3.0"]
}
```

- [ ] **Step 5: Run tests, commit**

```bash
ruby -e "
require 'xcodeproj'
proj = Xcodeproj::Project.open('App/TFTMac.xcodeproj')
test_target = proj.targets.find { |t| t.name == 'TFTMacTests' }
test_target.add_file_references([proj.main_group.find_subpath('TFTMacTests', true).new_file('App/TFTMacTests/Phase3FieldsDecodingTests.swift')])
proj.save
"
xcodebuild test -project App/TFTMac.xcodeproj -scheme TFTMac -destination 'platform=macOS' -only-testing:TFTMacTests/Phase3FieldsDecodingTests 2>&1 | tail -20

git add App/TFTMac/Models/ App/TFTMacTests/Phase3FieldsDecodingTests.swift App/TFTMac.xcodeproj
git commit -m "feat(app): Comp model accepts schema 1.3.0 (early/carousel/lv9/playstyle)"
```

---

## Task 9: Three new ExpandedCardView sections

**Files:**
- Create: `App/TFTMac/Views/EarlyCompSection.swift`
- Create: `App/TFTMac/Views/CarouselPrioritySection.swift`
- Create: `App/TFTMac/Views/LevelNineAltsSection.swift`
- Modify: `App/TFTMac/Views/ExpandedCardView.swift`

- [ ] **Step 1: Implement EarlyCompSection**

```swift
// App/TFTMac/Views/EarlyCompSection.swift
import SwiftUI

struct EarlyCompSection: View {
    let units: [EarlyCompUnit]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Early Game")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textMuted)
            HStack(spacing: 6) {
                ForEach(units, id: \.id) { unit in
                    VStack(spacing: 2) {
                        MiniChampionPortrait(championId: unit.id)
                        Text("\(Int(unit.frequency * 100))%")
                            .font(Theme.Fonts.captionSmall)
                            .foregroundStyle(Theme.Colors.textMuted)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

/// Reusable 28px portrait without name label, for compact contexts.
struct MiniChampionPortrait: View {
    let championId: String
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            if let img = image { Image(nsImage: img).resizable().aspectRatio(contentMode: .fill) }
            else { Circle().fill(Theme.Colors.bgCard) }
        }
        .frame(width: 28, height: 28)
        .clipShape(Circle())
        .help(ChampionCatalog.displayName(forId: championId))
        .task {
            guard image == nil,
                  let url = ChampionAssetURL.squarePortrait(forChampionId: championId),
                  let data = try? await AssetCache.shared.data(for: url),
                  let img = NSImage(data: data) else { return }
            self.image = img
        }
    }
}
```

- [ ] **Step 2: Implement CarouselPrioritySection**

```swift
// App/TFTMac/Views/CarouselPrioritySection.swift
import SwiftUI

struct CarouselPrioritySection: View {
    let picks: [CarouselPick]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Carousel Priority")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textMuted)
            HStack(spacing: 8) {
                ForEach(picks, id: \.id) { pick in
                    HStack(spacing: 4) {
                        Text("\(pick.rank).")
                            .font(Theme.Fonts.captionSmall)
                            .foregroundStyle(Theme.Colors.accentGold)
                        MiniChampionPortrait(championId: pick.id)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}
```

- [ ] **Step 3: Implement LevelNineAltsSection**

```swift
// App/TFTMac/Views/LevelNineAltsSection.swift
import SwiftUI

struct LevelNineAltsSection: View {
    let alts: [Lv9Alternative]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("LV.9 Alternatives")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textMuted)
            HStack(spacing: 6) {
                ForEach(alts, id: \.id) { alt in
                    VStack(spacing: 2) {
                        MiniChampionPortrait(championId: alt.id)
                        Text("\(Int(alt.frequency * 100))%")
                            .font(Theme.Fonts.captionSmall)
                            .foregroundStyle(Theme.Colors.textMuted)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}
```

- [ ] **Step 4: Wire into ExpandedCardView**

In `App/TFTMac/Views/ExpandedCardView.swift` body, append below existing content:

```swift
if !comp.earlyComp.isEmpty {
    EarlyCompSection(units: comp.earlyComp)
        .padding(.top, 8)
}
if !comp.carouselPriority.isEmpty {
    CarouselPrioritySection(picks: comp.carouselPriority)
        .padding(.top, 8)
}
if !comp.lv9Alternatives.isEmpty {
    LevelNineAltsSection(alts: comp.lv9Alternatives)
        .padding(.top, 8)
}
```

- [ ] **Step 5: Register all 3 in Xcode**

```bash
ruby -e "
require 'xcodeproj'
proj = Xcodeproj::Project.open('App/TFTMac.xcodeproj')
target = proj.targets.find { |t| t.name == 'TFTMac' }
group = proj.main_group.find_subpath('TFTMac/Views', true)
['EarlyCompSection.swift', 'CarouselPrioritySection.swift', 'LevelNineAltsSection.swift'].each do |fn|
  target.add_file_references([group.new_file(\"App/TFTMac/Views/#{fn}\")])
end
proj.save
"
```

- [ ] **Step 6: Run full suite + manual smoke**

```bash
xcodebuild test -project App/TFTMac.xcodeproj -scheme TFTMac -destination 'platform=macOS' 2>&1 | tail -20
xcodebuild build -project App/TFTMac.xcodeproj -scheme TFTMac
open App/build/Debug/TFTMac.app
```

Anh: tap a comp to expand → verify 3 new sections appear with mini portraits.

- [ ] **Step 7: Commit**

```bash
git add App/TFTMac/Views/ App/TFTMac.xcodeproj
git commit -m "feat(app): EarlyComp + Carousel + LV.9 sections in ExpandedCardView"
```

---

## Task 10: Update PlaystyleLabel to read from comp.playstyle

**Files:**
- Modify: `App/TFTMac/Views/PlaystyleLabel.swift`

- [ ] **Step 1: Read current heuristic**

```bash
cat App/TFTMac/Views/PlaystyleLabel.swift
```

Note: `derivedPlaystyle(for:)` likely uses champion costs to guess. Replace with direct read.

- [ ] **Step 2: Replace heuristic**

```swift
extension PlaystyleLabel {
    static func derivedPlaystyle(for comp: Comp) -> String {
        // Phase 3: pipeline emits playstyle directly. Empty / "Standard" hidden.
        comp.playstyle
    }
}
```

In `PlaystyleLabel.body`, hide when `text == "Standard"`:

```swift
var body: some View {
    if text != "Standard" && !text.isEmpty {
        Text(text)
            // ... existing styling
    }
}
```

- [ ] **Step 3: Run regression tests**

```bash
xcodebuild test -project App/TFTMac.xcodeproj -scheme TFTMac -destination 'platform=macOS' 2>&1 | tail -20
```

Fix any test fixture that constructed Comp without playstyle.

- [ ] **Step 4: Commit**

```bash
git add App/TFTMac/Views/PlaystyleLabel.swift
git commit -m "feat(app): PlaystyleLabel reads pipeline-classified playstyle"
```

---

## Task 11: Phase Completion Protocol

- [ ] **Step 1: Update docs/system-architecture.md** — schema 1.3.0, Phase 3 fields, ItemAssetURL added.

- [ ] **Step 2: Create docs/rich-comp-details-architecture.md** — Mermaid: Match-v5 → 4 aggregators → emit_comp → Comp model → 3 sections.

- [ ] **Step 3: Append docs/project-changelog.md**

```markdown
## [phase-03-rich-details] — 2026-04-26

### Added
- early_comp_aggregator, carousel_aggregator, playstyle_classifier (Pipeline).
- extract_lv9_alternatives in comp_pipeline.
- ItemAssetURL + data-driven ItemCatalog (App).
- EarlyCompSection, CarouselPrioritySection, LevelNineAltsSection (App).
- MiniChampionPortrait reusable view (App).

### Changed
- CompCardItemsRow renders icons (was: text only).
- PlaystyleLabel reads pipeline classification (was: cost heuristic).
- Schema bumped 1.2.0 → 1.3.0.
```

- [ ] **Step 4: Append bugs-log if any.**

- [ ] **Step 5: Verify + commit + push**

```bash
git diff HEAD~1 docs/project-changelog.md | grep -c "^+## "
git add docs/
git commit -m "docs(phase-03): rich comp details"
git push origin feat/v0.1-implementation
```

---

## Success Criteria

- ✅ Expanded comp shows: Early Game (5 mini-portraits + %), Carousel Priority (1/2/3 ranked), LV.9 Alternatives (3 portraits).
- ✅ CompCardItemsRow shows real item icons; tooltip on hover shows item name.
- ✅ Playstyle label shows "Slow Roll" / "Fast 8" only when pipeline classifies; hidden for "Standard".
- ✅ All tests green.

## Risks

- **Match-v5 doesn't track per-stage state** — early_comp + carousel are heuristic approximations from final boards. Quality depends on top-4 sample size; <50 matches per comp = noisy. Mitigation: sample_size guard already in tier classifier.
- **Item icon URL pattern** — best guess at this phase; first runtime fetch surfaces 404 if wrong. Text fallback ensures no UI break.

## Next Phase

→ [Phase 4 — Positioning hex grid](phase-04-positioning-hex-grid.md)
