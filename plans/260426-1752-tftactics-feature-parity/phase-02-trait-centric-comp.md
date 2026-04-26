# Phase 2 — Trait-Centric Comp Identification

**Parent plan:** [plan.md](plan.md)
**Status:** ⏳ Blocked by Phase 1
**Effort:** 14-23h
**Gaps closed:** A2 (semantic comp names), A3 (trait synergies + counts), B3 (trait icons), C2 (trait-combo aggregator rewrite)
**Manual gate before:** Phase 1 merged + anh sees real portraits live
**Manual gate after:** anh inspects 3 different comps, all show meaningful trait names ("Psionic Conduits") and trait chips with active counts

---

## Goal

Replace concat-style comp names (`"Illaoi + Nami + Rhaast + ..."`) with semantic names derived from active trait combinations (`"Psionic Conduits"`, `"Dominator Marksmen"`). Render trait chips with icons + active counts (e.g., `🔱 Storm 4`) per comp. Aggregator rewrites comp signature from champion-set hash to trait-combo hash so similar trait combos collapse into one canonical comp.

## Architecture

- **Pipeline (Python)** — `comp_signature.py` adds `trait_combo_signature(participant)` returning a sorted tuple of (trait_name, active_count) at each tier breakpoint. `comp_grouping.py` groups by trait signature instead of champion set. `json_emitter.py` adds new fields per comp: `traits: [{name, count, style}]` and replaces concat name with `derived_name` from a name-resolution table.
- **App (Swift)** — `Models/Comp.swift` extended with `traits: [TraitActivation]`. New `Models/TraitActivation.swift`. New `Generated/TraitCatalog.swift` (Set 17 traits). New `Services/TraitAssetURL.swift`. New `Views/TraitChip.swift` rendered in CompCard above champion row. New `Services/CompNameResolver.swift` for fallback when pipeline `derived_name` empty.
- **Schema bump** — `1.1.0 → 1.2.0`. Forward-compat: missing `traits` field → empty array, falls back to legacy concat name display.

## Files

**Create:**
- `Pipeline/src/tftmac_pipeline/trait_signature.py`
- `Pipeline/src/tftmac_pipeline/comp_name_resolver.py`
- `Pipeline/data/trait_name_map.json`
- `Pipeline/tests/test_trait_signature.py`
- `Pipeline/tests/test_comp_name_resolver.py`
- `Pipeline/tests/test_trait_combo_grouping.py`
- `App/TFTMac/Models/TraitActivation.swift`
- `App/TFTMac/Generated/TraitCatalog.swift`
- `App/TFTMac/Resources/set17-traits.json`
- `App/TFTMac/Services/TraitAssetURL.swift`
- `App/TFTMac/Views/TraitChip.swift`
- `App/TFTMacTests/TraitActivationDecodingTests.swift`
- `App/TFTMacTests/TraitChipTests.swift`
- `App/TFTMacTests/TraitAssetURLTests.swift`

**Modify:**
- `Pipeline/src/tftmac_pipeline/comp_grouping.py` — group by trait signature
- `Pipeline/src/tftmac_pipeline/json_emitter.py` — emit `traits[]` + `derived_name`, schema 1.2.0
- `Pipeline/src/tftmac_pipeline/run_aggregator.py` — wire name resolver, bump schema_version
- `App/TFTMac/Models/Comp.swift` — add `traits: [TraitActivation]` with forward-compat decode
- `App/TFTMac/Models/SchemaVersion.swift` — accept 1.2.0
- `App/TFTMac/Services/SchemaCompatibilityGate.swift` — accept 1.1.0 + 1.2.0
- `App/TFTMac/Views/CompCard.swift` — render TraitChip row above champion row
- `App/TFTMacTests/regression/SampleTierListFixtureTests.swift` — refresh fixture to schema 1.2.0

---

## Task 1: Trait signature builder (Python TDD)

**Files:**
- Create: `Pipeline/src/tftmac_pipeline/trait_signature.py`
- Test: `Pipeline/tests/test_trait_signature.py`

- [ ] **Step 1: Write failing test**

```python
# Pipeline/tests/test_trait_signature.py
"""Trait combo signature: stable hash from active traits + tier breakpoints."""
from tftmac_pipeline.trait_signature import trait_combo_signature

def test_returns_sorted_active_traits_only():
    participant = {
        "traits": [
            {"name": "Set17_Psionic", "num_units": 4, "tier_current": 2, "style": 3},
            {"name": "Set17_Dominator", "num_units": 2, "tier_current": 1, "style": 1},
            {"name": "Set17_Storm", "num_units": 1, "tier_current": 0, "style": 0},  # inactive — filtered
        ]
    }
    sig = trait_combo_signature(participant)
    # Sorted alphabetically by name, only active (tier_current > 0)
    assert sig == (("Set17_Dominator", 1), ("Set17_Psionic", 2))

def test_empty_when_no_active_traits():
    assert trait_combo_signature({"traits": []}) == ()

def test_handles_missing_traits_key():
    assert trait_combo_signature({}) == ()
```

- [ ] **Step 2: Run test to verify fail**

```bash
cd Pipeline && .venv/bin/pytest tests/test_trait_signature.py -v
```

Expected: FAIL — module missing.

- [ ] **Step 3: Implement**

```python
# Pipeline/src/tftmac_pipeline/trait_signature.py
"""Trait combo signature for comp grouping.

Signature = sorted tuple of (trait_name, tier_current) for all active traits
(tier_current > 0). Used as dict key in comp_grouping to collapse same trait
combos into one canonical comp regardless of which specific carry-equivalents
were played.
"""
from typing import Tuple

def trait_combo_signature(participant: dict) -> Tuple[Tuple[str, int], ...]:
    traits = participant.get("traits", [])
    active = [
        (t["name"], t.get("tier_current", 0))
        for t in traits
        if t.get("tier_current", 0) > 0
    ]
    return tuple(sorted(active))
```

- [ ] **Step 4: Run test to verify pass**

```bash
cd Pipeline && .venv/bin/pytest tests/test_trait_signature.py -v
```

Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Pipeline/src/tftmac_pipeline/trait_signature.py Pipeline/tests/test_trait_signature.py
git commit -m "feat(pipeline): trait_combo_signature for comp grouping"
```

---

## Task 2: Comp name resolver (Python TDD)

**Files:**
- Create: `Pipeline/data/trait_name_map.json`
- Create: `Pipeline/src/tftmac_pipeline/comp_name_resolver.py`
- Test: `Pipeline/tests/test_comp_name_resolver.py`

- [ ] **Step 1: Seed trait_name_map.json with hand-curated comp names**

```json
{
  "_comment": "Maps trait combo signatures to semantic comp names. Key = sorted trait names joined by '+'. Value = display name. Fallback: top 2 trait names joined.",
  "Set17_Dominator+Set17_Marksman": "Dominator Marksmen",
  "Set17_Psionic+Set17_Conduit": "Psionic Conduits",
  "Set17_Storm+Set17_Quickdraw": "Storm Quickdraw",
  "Set17_Marauder+Set17_Primordian": "Primordian Marauders",
  "Set17_Bastion+Set17_Vanguard": "Bastion Wall",
  "Set17_Sorcerer+Set17_Scholar": "Sorcerer Scholars"
}
```

(Curate ~10-20 entries; rest fall through to auto-name.)

- [ ] **Step 2: Write failing test**

```python
# Pipeline/tests/test_comp_name_resolver.py
from tftmac_pipeline.comp_name_resolver import resolve_comp_name

def test_returns_curated_name_when_mapped():
    sig = (("Set17_Dominator", 2), ("Set17_Marksman", 3))
    assert resolve_comp_name(sig) == "Dominator Marksmen"

def test_fallback_top_2_traits_when_unmapped():
    sig = (("Set17_Bruiser", 4), ("Set17_FakeTrait", 1))
    # Top 2 by tier (Bruiser 4 > FakeTrait 1) → "Bruiser FakeTrait"
    name = resolve_comp_name(sig)
    assert "Bruiser" in name
    assert name == "Bruiser FakeTrait"  # strips "Set17_" prefix

def test_empty_signature_returns_unknown():
    assert resolve_comp_name(()) == "Unknown Comp"
```

- [ ] **Step 3: Run test, expect fail**

```bash
cd Pipeline && .venv/bin/pytest tests/test_comp_name_resolver.py -v
```

- [ ] **Step 4: Implement**

```python
# Pipeline/src/tftmac_pipeline/comp_name_resolver.py
"""Resolve trait combo signatures to human-readable comp names."""
import json
from pathlib import Path
from typing import Tuple

_MAP_PATH = Path(__file__).parent.parent.parent / "data" / "trait_name_map.json"
_CURATED: dict[str, str] | None = None

def _load_map() -> dict[str, str]:
    global _CURATED
    if _CURATED is None:
        with open(_MAP_PATH) as f:
            raw = json.load(f)
        _CURATED = {k: v for k, v in raw.items() if not k.startswith("_")}
    return _CURATED

def resolve_comp_name(signature: Tuple[Tuple[str, int], ...]) -> str:
    if not signature:
        return "Unknown Comp"
    # Try curated map first — key = sorted trait names joined by '+'
    names_only = sorted(name for name, _ in signature)
    key = "+".join(names_only)
    curated = _load_map()
    if key in curated:
        return curated[key]
    # Fallback: top 2 traits by activation tier
    top2 = sorted(signature, key=lambda x: -x[1])[:2]
    return " ".join(_strip_prefix(name) for name, _ in top2)

def _strip_prefix(trait_name: str) -> str:
    return trait_name.replace("Set17_", "")
```

- [ ] **Step 5: Run test, expect pass**

```bash
cd Pipeline && .venv/bin/pytest tests/test_comp_name_resolver.py -v
```

- [ ] **Step 6: Commit**

```bash
git add Pipeline/data/trait_name_map.json Pipeline/src/tftmac_pipeline/comp_name_resolver.py Pipeline/tests/test_comp_name_resolver.py
git commit -m "feat(pipeline): comp_name_resolver with curated trait-combo names"
```

---

## Task 3: Comp grouping by trait signature (Python TDD)

**Files:**
- Test: `Pipeline/tests/test_trait_combo_grouping.py`
- Modify: `Pipeline/src/tftmac_pipeline/comp_grouping.py`

- [ ] **Step 1: Read current comp_grouping.py to understand interface**

```bash
cat Pipeline/src/tftmac_pipeline/comp_grouping.py
```

Note the function signature that consumes `participants` and returns grouped `comps`. Adapt below to actual names.

- [ ] **Step 2: Write failing test**

```python
# Pipeline/tests/test_trait_combo_grouping.py
"""Comp grouping by trait signature (replaces champion-set hash)."""
from tftmac_pipeline.comp_grouping import group_comps_by_trait_signature

def test_same_trait_combo_groups_together():
    participants = [
        {
            "placement": 1,
            "traits": [{"name": "Set17_Psionic", "tier_current": 2, "num_units": 4}],
            "units": [{"character_id": "TFT17_Viktor", "tier": 2, "items": []}],
        },
        {
            "placement": 3,
            "traits": [{"name": "Set17_Psionic", "tier_current": 2, "num_units": 4}],
            "units": [{"character_id": "TFT17_Syndra", "tier": 2, "items": []}],
        },
    ]
    grouped = group_comps_by_trait_signature(participants)
    assert len(grouped) == 1
    comp = list(grouped.values())[0]
    assert comp["sample_size"] == 2

def test_different_trait_combos_separate():
    participants = [
        {"placement": 1, "traits": [{"name": "Set17_Psionic", "tier_current": 2, "num_units": 4}], "units": []},
        {"placement": 2, "traits": [{"name": "Set17_Dominator", "tier_current": 1, "num_units": 2}], "units": []},
    ]
    grouped = group_comps_by_trait_signature(participants)
    assert len(grouped) == 2
```

- [ ] **Step 3: Run test, expect fail (function missing)**

```bash
cd Pipeline && .venv/bin/pytest tests/test_trait_combo_grouping.py -v
```

- [ ] **Step 4: Implement (additive — keep existing fn for backwards-compat)**

Add to `Pipeline/src/tftmac_pipeline/comp_grouping.py`:

```python
from collections import defaultdict
from .trait_signature import trait_combo_signature

def group_comps_by_trait_signature(participants: list[dict]) -> dict:
    """Group participants by trait combo signature.

    Returns dict[signature_tuple → aggregated comp dict] where each comp dict
    has: sample_size, placements (for avg + top4), trait_signature, champions
    (union with frequency).
    """
    buckets = defaultdict(lambda: {
        "sample_size": 0,
        "placements": [],
        "trait_signature": None,
        "champion_freq": defaultdict(int),
        "items_per_champion": defaultdict(lambda: defaultdict(int)),
    })
    for p in participants:
        sig = trait_combo_signature(p)
        if not sig:
            continue
        b = buckets[sig]
        b["trait_signature"] = sig
        b["sample_size"] += 1
        b["placements"].append(p.get("placement", 8))
        for unit in p.get("units", []):
            cid = unit.get("character_id")
            if not cid:
                continue
            b["champion_freq"][cid] += 1
            for item in unit.get("items", []) or []:
                # Riot returns ints (item ids) or dicts; normalize
                item_id = item if isinstance(item, (str, int)) else item.get("id")
                if item_id is not None:
                    b["items_per_champion"][cid][item_id] += 1
    return dict(buckets)
```

- [ ] **Step 5: Run test, expect pass**

```bash
cd Pipeline && .venv/bin/pytest tests/test_trait_combo_grouping.py -v
```

- [ ] **Step 6: Run full Pipeline suite (regression)**

```bash
cd Pipeline && .venv/bin/pytest -v
```

Expected: green. Existing `comp_grouping` callers continue using the old fn until Task 4 wires the new path.

- [ ] **Step 7: Commit**

```bash
git add Pipeline/src/tftmac_pipeline/comp_grouping.py Pipeline/tests/test_trait_combo_grouping.py
git commit -m "feat(pipeline): trait-signature comp grouping (additive)"
```

---

## Task 4: Wire trait grouping into run_aggregator + emit traits[] + bump schema (Python)

**Files:**
- Modify: `Pipeline/src/tftmac_pipeline/run_aggregator.py`
- Modify: `Pipeline/src/tftmac_pipeline/json_emitter.py`
- Test: existing `Pipeline/tests/test_run_aggregator.py` + `test_json_emitter.py`

- [ ] **Step 1: Read both files to understand current flow**

```bash
cat Pipeline/src/tftmac_pipeline/json_emitter.py
cat Pipeline/src/tftmac_pipeline/run_aggregator.py | head -80
```

- [ ] **Step 2: Update json_emitter to schema 1.2.0 with traits[]**

In `Pipeline/src/tftmac_pipeline/json_emitter.py`, locate the comp dict builder. Add:

```python
def emit_comp(grouped_comp: dict, derived_name: str) -> dict:
    sig = grouped_comp["trait_signature"]
    placements = grouped_comp["placements"]
    return {
        "comp_id": _slugify(derived_name),
        "name": derived_name,
        "tier": "C",  # filled by tier_calculator downstream
        "play_rate": 0.0,  # filled downstream
        "avg_placement": sum(placements) / len(placements) if placements else 8.0,
        "top_4_rate": sum(1 for p in placements if p <= 4) / max(len(placements), 1),
        "sample_size": grouped_comp["sample_size"],
        "champions": _emit_champions(grouped_comp),
        "anomalies": [],  # populated by anomaly_aggregator
        "traits": [
            {"name": name, "count": count, "style": _style_for(count)}
            for name, count in sig
        ],
    }

def _style_for(count: int) -> str:
    """Bronze/silver/gold/chromatic style tier per Riot trait UX."""
    if count >= 6: return "chromatic"
    if count >= 4: return "gold"
    if count >= 2: return "silver"
    return "bronze"

def _slugify(name: str) -> str:
    return name.lower().replace(" ", "-").replace("'", "")
```

Update top of file to bump schema:

```python
SCHEMA_VERSION = "1.2.0"
```

- [ ] **Step 3: Update run_aggregator.py to use trait grouping**

Replace the existing comp grouping call with:

```python
from .comp_grouping import group_comps_by_trait_signature
from .comp_name_resolver import resolve_comp_name
from .json_emitter import emit_comp, SCHEMA_VERSION

def build_tier_list_payload(matches, region, patch):
    participants = _flatten_participants(matches)
    grouped = group_comps_by_trait_signature(participants)
    comps = []
    for sig, bucket in grouped.items():
        name = resolve_comp_name(sig)
        comp = emit_comp(bucket, name)
        comps.append(comp)
    # ... existing tier classification + sort
    payload["schema_version"] = SCHEMA_VERSION
    payload["comps"] = comps
    return payload
```

- [ ] **Step 4: Update existing tests (refresh fixtures)**

```bash
cd Pipeline && .venv/bin/pytest -v 2>&1 | tail -30
```

Tests will likely fail on schema_version assertion (expects 1.1.0). Fix by:
- `tests/test_json_emitter.py`: assert `1.2.0`.
- `tests/test_run_aggregator.py`: assert each comp has `traits` key with list value.

- [ ] **Step 5: Verify pipeline run produces real trait data**

```bash
cd Pipeline && .venv/bin/python scripts/run_aggregator.py --dry-run --sample 50 2>&1 | tail -20
```

Eyeball output: comp names should be semantic, traits[] populated.

- [ ] **Step 6: Commit**

```bash
git add Pipeline/src/tftmac_pipeline/json_emitter.py Pipeline/src/tftmac_pipeline/run_aggregator.py Pipeline/tests/
git commit -m "feat(pipeline): emit trait-grouped comps + traits[] (schema 1.2.0)"
```

---

## Task 5: TraitActivation Swift model + forward-compat decode (TDD)

**Files:**
- Create: `App/TFTMac/Models/TraitActivation.swift`
- Create: `App/TFTMacTests/TraitActivationDecodingTests.swift`
- Modify: `App/TFTMac/Models/Comp.swift`

- [ ] **Step 1: Write failing test**

```swift
// App/TFTMacTests/TraitActivationDecodingTests.swift
import XCTest
@testable import TFTMac

final class TraitActivationDecodingTests: XCTestCase {

    func test_decodesV1_2_0CompWithTraits() throws {
        let json = #"""
        {
          "comp_id": "psionic-conduits",
          "name": "Psionic Conduits",
          "tier": "S",
          "play_rate": 0.082,
          "avg_placement": 3.95,
          "top_4_rate": 0.61,
          "sample_size": 142,
          "champions": [],
          "anomalies": [],
          "traits": [
            {"name": "Set17_Psionic", "count": 4, "style": "gold"},
            {"name": "Set17_Conduit", "count": 2, "style": "silver"}
          ]
        }
        """#.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let comp = try decoder.decode(Comp.self, from: json)
        XCTAssertEqual(comp.traits.count, 2)
        XCTAssertEqual(comp.traits.first?.name, "Set17_Psionic")
        XCTAssertEqual(comp.traits.first?.count, 4)
        XCTAssertEqual(comp.traits.first?.style, .gold)
    }

    func test_decodesV1_1_0CompWithoutTraits() throws {
        let json = #"""
        {
          "comp_id": "old-comp",
          "name": "Old Comp",
          "tier": "B",
          "play_rate": 0.05,
          "avg_placement": 4.5,
          "top_4_rate": 0.50,
          "sample_size": 100,
          "champions": [],
          "anomalies": []
        }
        """#.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let comp = try decoder.decode(Comp.self, from: json)
        XCTAssertEqual(comp.traits, [])
    }
}
```

- [ ] **Step 2: Run test, expect fail**

```bash
xcodebuild test -project App/TFTMac.xcodeproj -scheme TFTMac -destination 'platform=macOS' -only-testing:TFTMacTests/TraitActivationDecodingTests 2>&1 | tail -20
```

Expected: FAIL — `TraitActivation` undefined; `Comp.traits` undefined.

- [ ] **Step 3: Implement TraitActivation.swift**

```swift
// App/TFTMac/Models/TraitActivation.swift
import Foundation

/// A single active trait on a comp (from pipeline schema 1.2.0).
///
/// `style` reflects Riot's UX tier (bronze/silver/gold/chromatic) rendered
/// as the trait chip background color.
struct TraitActivation: Codable, Equatable {
    let name: String     // e.g. "Set17_Psionic"
    let count: Int       // active unit count, e.g. 4
    let style: Style

    enum Style: String, Codable {
        case bronze, silver, gold, chromatic
    }
}
```

- [ ] **Step 4: Modify Comp.swift to add traits with forward-compat decode**

In `App/TFTMac/Models/Comp.swift`, add property + update both inits:

```swift
struct Comp: Encodable {
    // ... existing properties
    let anomalies: [Anomaly]
    let traits: [TraitActivation]   // NEW — empty for v1.1.0 schema

    init(
        // ... existing params
        anomalies: [Anomaly] = [],
        traits: [TraitActivation] = []
    ) {
        // ... existing assignments
        self.traits = traits
    }
}

extension Comp: Decodable {
    enum CodingKeys: String, CodingKey {
        // ... existing cases
        case traits
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // ... existing decodes
        self.anomalies = (try? c.decodeIfPresent([Anomaly].self, forKey: .anomalies)) ?? []
        self.traits = (try? c.decodeIfPresent([TraitActivation].self, forKey: .traits)) ?? []
    }
}
```

- [ ] **Step 5: Register new file in Xcode**

```bash
ruby -e "
require 'xcodeproj'
proj = Xcodeproj::Project.open('App/TFTMac.xcodeproj')
target = proj.targets.find { |t| t.name == 'TFTMac' }
group = proj.main_group.find_subpath('TFTMac/Models', true)
file = group.new_file('App/TFTMac/Models/TraitActivation.swift')
target.add_file_references([file])
test_target = proj.targets.find { |t| t.name == 'TFTMacTests' }
test_group = proj.main_group.find_subpath('TFTMacTests', true)
test_file = test_group.new_file('App/TFTMacTests/TraitActivationDecodingTests.swift')
test_target.add_file_references([test_file])
proj.save
"
```

- [ ] **Step 6: Run tests**

```bash
xcodebuild test -project App/TFTMac.xcodeproj -scheme TFTMac -destination 'platform=macOS' -only-testing:TFTMacTests/TraitActivationDecodingTests 2>&1 | tail -20
```

Expected: 2 PASS.

- [ ] **Step 7: Commit**

```bash
git add App/TFTMac/Models/TraitActivation.swift App/TFTMac/Models/Comp.swift App/TFTMacTests/TraitActivationDecodingTests.swift App/TFTMac.xcodeproj
git commit -m "feat(app): TraitActivation model + Comp.traits with forward-compat decode"
```

---

## Task 6: SchemaCompatibilityGate accepts 1.2.0 (TDD)

**Files:**
- Modify: `App/TFTMac/Models/SchemaVersion.swift`
- Modify: `App/TFTMac/Services/SchemaCompatibilityGate.swift`
- Test: existing `App/TFTMacTests/SchemaCompatibilityGateTests.swift` — add new case

- [ ] **Step 1: Add failing test case**

Append to `App/TFTMacTests/SchemaCompatibilityGateTests.swift`:

```swift
func test_accepts_v1_2_0() {
    let gate = SchemaCompatibilityGate()
    XCTAssertTrue(gate.isAcceptable(remoteVersion: "1.2.0"))
}
```

- [ ] **Step 2: Run test, expect fail**

```bash
xcodebuild test -project App/TFTMac.xcodeproj -scheme TFTMac -destination 'platform=macOS' -only-testing:TFTMacTests/SchemaCompatibilityGateTests/test_accepts_v1_2_0 2>&1 | tail -10
```

- [ ] **Step 3: Update SchemaVersion + Gate**

In `App/TFTMac/Models/SchemaVersion.swift`:

```swift
enum SchemaVersion {
    static let app: String = "1.2.0"
    static let acceptedRemote: Set<String> = ["1.0.0", "1.1.0", "1.2.0"]
}
```

In `App/TFTMac/Services/SchemaCompatibilityGate.swift`, ensure `isAcceptable` reads from `SchemaVersion.acceptedRemote`.

- [ ] **Step 4: Run all schema tests**

```bash
xcodebuild test -project App/TFTMac.xcodeproj -scheme TFTMac -destination 'platform=macOS' -only-testing:TFTMacTests/SchemaCompatibilityGateTests -only-testing:TFTMacTests/SchemaVersionTests 2>&1 | tail -20
```

Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add App/TFTMac/Models/SchemaVersion.swift App/TFTMac/Services/SchemaCompatibilityGate.swift App/TFTMacTests/SchemaCompatibilityGateTests.swift
git commit -m "feat(app): accept schema 1.2.0 (trait-aware comps)"
```

---

## Task 7: TraitCatalog + TraitAssetURL (Swift TDD)

**Files:**
- Create: `App/TFTMac/Resources/set17-traits.json`
- Create: `App/TFTMac/Generated/TraitCatalog.swift`
- Create: `App/TFTMac/Services/TraitAssetURL.swift`
- Test: `App/TFTMacTests/TraitAssetURLTests.swift`

- [ ] **Step 1: Generate set17-traits.json from live data**

```bash
# Once Phase 2 Task 4 is live, regenerate from data/tier-list.json
jq '[.comps[].traits[]?.name] | unique | sort | map({id: ., displayName: (. | sub("^Set17_"; ""))})' \
  data/tier-list.json > App/TFTMac/Resources/set17-traits.json
```

If pipeline hasn't refreshed live data yet (Task 4 commits but cron hasn't run), seed manually with ~20 known traits from Set 17 (Psionic, Conduit, Dominator, Marksman, Storm, Quickdraw, Marauder, Primordian, Bastion, Vanguard, Sorcerer, Scholar, Bruiser, Striker, Frost, Blaze, Empyrean, Edgelord, Visionary, Soulbound).

- [ ] **Step 2: Write failing test for TraitAssetURL**

```swift
// App/TFTMacTests/TraitAssetURLTests.swift
import XCTest
@testable import TFTMac

final class TraitAssetURLTests: XCTestCase {

    func test_buildsLowercaseTraitURL() {
        let url = TraitAssetURL.icon(forTraitName: "Set17_Psionic")
        XCTAssertEqual(
            url?.absoluteString,
            "https://raw.communitydragon.org/latest/game/assets/ux/traiticons/trait_icon_17_psionic.png"
        )
    }

    func test_returnsNilForBlank() {
        XCTAssertNil(TraitAssetURL.icon(forTraitName: ""))
    }
}
```

(Note: actual URL pattern verified during execution — Phase 1 Task 0 method. If `.tex.png` or different path, adjust both implementation and test in this step.)

- [ ] **Step 3: Run test, expect fail**

```bash
xcodebuild test -project App/TFTMac.xcodeproj -scheme TFTMac -destination 'platform=macOS' -only-testing:TFTMacTests/TraitAssetURLTests 2>&1 | tail -10
```

- [ ] **Step 4: Implement TraitAssetURL + TraitCatalog**

```swift
// App/TFTMac/Services/TraitAssetURL.swift
import Foundation

enum TraitAssetURL {
    private static let base = "https://raw.communitydragon.org/latest/game/assets/ux/traiticons"

    static func icon(forTraitName name: String) -> URL? {
        guard !name.isEmpty else { return nil }
        // "Set17_Psionic" → "trait_icon_17_psionic"
        let lower = name.lowercased().replacingOccurrences(of: "set", with: "")
        let parts = lower.split(separator: "_", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        return URL(string: "\(base)/trait_icon_\(parts[0])_\(parts[1]).png")
    }
}
```

```swift
// App/TFTMac/Generated/TraitCatalog.swift
import Foundation
import os

enum TraitCatalog {
    struct Entry: Decodable {
        let id: String
        let displayName: String
    }

    static let entries: [String: Entry] = loadFromBundle()

    static func displayName(forId id: String) -> String {
        entries[id]?.displayName ?? id.replacingOccurrences(of: "Set17_", with: "")
    }

    private static func loadFromBundle() -> [String: Entry] {
        let logger = Logger(subsystem: "io.psychomafia.tfthellelo", category: "TraitCatalog")
        guard let url = Bundle.main.url(forResource: "set17-traits", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let arr = try? JSONDecoder().decode([Entry].self, from: data) else {
            logger.error("set17-traits.json missing — empty catalog")
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: arr.map { ($0.id, $0) })
    }
}
```

- [ ] **Step 5: Register all 3 files in Xcode**

```bash
ruby -e "
require 'xcodeproj'
proj = Xcodeproj::Project.open('App/TFTMac.xcodeproj')
target = proj.targets.find { |t| t.name == 'TFTMac' }
test_target = proj.targets.find { |t| t.name == 'TFTMacTests' }

group_svc = proj.main_group.find_subpath('TFTMac/Services', true)
target.add_file_references([group_svc.new_file('App/TFTMac/Services/TraitAssetURL.swift')])

group_gen = proj.main_group.find_subpath('TFTMac/Generated', true)
target.add_file_references([group_gen.new_file('App/TFTMac/Generated/TraitCatalog.swift')])

group_res = proj.main_group.find_subpath('TFTMac/Resources', true)
target.add_resources([group_res.new_file('App/TFTMac/Resources/set17-traits.json')])

group_test = proj.main_group.find_subpath('TFTMacTests', true)
test_target.add_file_references([group_test.new_file('App/TFTMacTests/TraitAssetURLTests.swift')])

proj.save
"
```

- [ ] **Step 6: Run tests**

```bash
xcodebuild test -project App/TFTMac.xcodeproj -scheme TFTMac -destination 'platform=macOS' -only-testing:TFTMacTests/TraitAssetURLTests 2>&1 | tail -20
```

Expected: 2 PASS.

- [ ] **Step 7: Commit**

```bash
git add App/TFTMac/Resources/set17-traits.json App/TFTMac/Generated/TraitCatalog.swift App/TFTMac/Services/TraitAssetURL.swift App/TFTMacTests/TraitAssetURLTests.swift App/TFTMac.xcodeproj
git commit -m "feat(app): TraitCatalog + TraitAssetURL for Set 17 trait icons"
```

---

## Task 8: TraitChip view (TDD)

**Files:**
- Create: `App/TFTMac/Views/TraitChip.swift`
- Create: `App/TFTMacTests/TraitChipTests.swift`

- [ ] **Step 1: Write failing test (snapshot-style assertion on view existence + props)**

```swift
// App/TFTMacTests/TraitChipTests.swift
import XCTest
import SwiftUI
@testable import TFTMac

final class TraitChipTests: XCTestCase {

    func test_initWithGoldStyle() {
        let activation = TraitActivation(name: "Set17_Psionic", count: 4, style: .gold)
        let chip = TraitChip(activation: activation)
        XCTAssertEqual(chip.activation.name, "Set17_Psionic")
        XCTAssertEqual(chip.activation.style, .gold)
    }

    func test_displayLabelStripsSetPrefix() {
        let activation = TraitActivation(name: "Set17_Psionic", count: 4, style: .gold)
        let chip = TraitChip(activation: activation)
        XCTAssertEqual(chip.displayLabel, "Psionic 4")
    }
}
```

- [ ] **Step 2: Run test, expect fail**

```bash
xcodebuild test -project App/TFTMac.xcodeproj -scheme TFTMac -destination 'platform=macOS' -only-testing:TFTMacTests/TraitChipTests 2>&1 | tail -10
```

- [ ] **Step 3: Implement**

```swift
// App/TFTMac/Views/TraitChip.swift
import SwiftUI

struct TraitChip: View {
    let activation: TraitActivation
    @State private var iconImage: NSImage?

    var displayLabel: String {
        "\(TraitCatalog.displayName(forId: activation.name)) \(activation.count)"
    }

    var body: some View {
        HStack(spacing: 4) {
            ZStack {
                Circle().fill(backgroundColor)
                if let img = iconImage {
                    Image(nsImage: img).resizable().aspectRatio(contentMode: .fit)
                        .frame(width: 12, height: 12)
                } else {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 18, height: 18)
            Text(displayLabel)
                .font(Theme.Fonts.captionSmall)
                .foregroundStyle(Theme.Colors.textPrimary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(backgroundColor.opacity(0.25))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(backgroundColor, lineWidth: 1))
        .task {
            guard iconImage == nil,
                  let url = TraitAssetURL.icon(forTraitName: activation.name),
                  let data = try? await AssetCache.shared.data(for: url),
                  let img = NSImage(data: data) else { return }
            self.iconImage = img
        }
    }

    private var backgroundColor: Color {
        switch activation.style {
        case .bronze: return Theme.Colors.accentBronze
        case .silver: return Theme.Colors.accentSilver
        case .gold: return Theme.Colors.accentGold
        case .chromatic: return Color.purple
        }
    }
}
```

- [ ] **Step 4: Register + run tests**

```bash
ruby -e "
require 'xcodeproj'
proj = Xcodeproj::Project.open('App/TFTMac.xcodeproj')
target = proj.targets.find { |t| t.name == 'TFTMac' }
group = proj.main_group.find_subpath('TFTMac/Views', true)
target.add_file_references([group.new_file('App/TFTMac/Views/TraitChip.swift')])
test_target = proj.targets.find { |t| t.name == 'TFTMacTests' }
test_group = proj.main_group.find_subpath('TFTMacTests', true)
test_target.add_file_references([test_group.new_file('App/TFTMacTests/TraitChipTests.swift')])
proj.save
"

xcodebuild test -project App/TFTMac.xcodeproj -scheme TFTMac -destination 'platform=macOS' -only-testing:TFTMacTests/TraitChipTests 2>&1 | tail -20
```

Expected: 2 PASS.

- [ ] **Step 5: Commit**

```bash
git add App/TFTMac/Views/TraitChip.swift App/TFTMacTests/TraitChipTests.swift App/TFTMac.xcodeproj
git commit -m "feat(app): TraitChip view with async icon load"
```

---

## Task 9: Wire TraitChip into CompCard

**Files:**
- Modify: `App/TFTMac/Views/CompCard.swift`

- [ ] **Step 1: Add traitsRow above championsRow**

In `body`:

```swift
var body: some View {
    VStack(alignment: .leading, spacing: 8) {
        topRow
        if !comp.traits.isEmpty {
            traitsRow
        }
        championsRow
        CompCardItemsRow(comp: comp)
        // ... rest unchanged
    }
    // ... unchanged
}

private var traitsRow: some View {
    HStack(spacing: 4) {
        ForEach(comp.traits.sorted(by: { $0.count > $1.count }), id: \.name) { trait in
            TraitChip(activation: trait)
        }
        Spacer(minLength: 0)
    }
}
```

- [ ] **Step 2: Update CompCardV2Tests fixtures (if any depend on traits being absent)**

Run tests:

```bash
xcodebuild test -project App/TFTMac.xcodeproj -scheme TFTMac -destination 'platform=macOS' -only-testing:TFTMacTests/CompCardV2Tests 2>&1 | tail -20
```

Fix any failures by updating test fixtures to include `traits: []` when constructing `Comp` literals.

- [ ] **Step 3: Run full suite**

```bash
xcodebuild test -project App/TFTMac.xcodeproj -scheme TFTMac -destination 'platform=macOS' 2>&1 | tail -30
```

Expected: green.

- [ ] **Step 4: Manual smoke test**

```bash
xcodebuild build -project App/TFTMac.xcodeproj -scheme TFTMac -destination 'platform=macOS'
open App/build/Debug/TFTMac.app
```

Anh: open popover, verify each comp shows trait chips above champions row. (Note: requires pipeline cron to have run at least once to publish v1.2.0 data; if still v1.1.0, traits empty and row hidden — verify forward-compat works.)

- [ ] **Step 5: Commit**

```bash
git add App/TFTMac/Views/CompCard.swift App/TFTMacTests/CompCardV2Tests.swift
git commit -m "feat(app): render trait chips row in CompCard"
```

---

## Task 10: Refresh bundled fixture to schema 1.2.0

**Files:**
- Modify: `App/TFTMac/Resources/sample-tier-list.json`
- Test: `App/TFTMacTests/regression/SampleTierListFixtureTests.swift`

- [ ] **Step 1: Manually trigger pipeline + copy live output as new fixture**

```bash
cd Pipeline && .venv/bin/python scripts/run_aggregator.py --output ../App/TFTMac/Resources/sample-tier-list.json
```

(Or if cron has already run, copy from `data/tier-list.json`.)

- [ ] **Step 2: Update SampleTierListFixtureTests to assert v1.2.0**

```swift
func test_fixtureSchemaIs1_2_0() {
    XCTAssertEqual(loadedTierList.schemaVersion, "1.2.0")
}

func test_fixtureCompsHaveTraits() {
    let withTraits = loadedTierList.comps.filter { !$0.traits.isEmpty }
    XCTAssertGreaterThan(withTraits.count, 0, "post-1.2.0 fixture must have ≥1 comp with traits")
}
```

- [ ] **Step 3: Run regression suite**

```bash
xcodebuild test -project App/TFTMac.xcodeproj -scheme TFTMac -destination 'platform=macOS' -only-testing:TFTMacTests/SampleTierListFixtureTests 2>&1 | tail -20
```

- [ ] **Step 4: Commit**

```bash
git add App/TFTMac/Resources/sample-tier-list.json App/TFTMacTests/regression/SampleTierListFixtureTests.swift
git commit -m "data: refresh bundled fixture to schema 1.2.0 (trait-aware)"
```

---

## Task 11: Phase Completion Protocol

- [ ] **Step 1: Update docs/system-architecture.md** — note schema 1.2.0, trait pipeline.

- [ ] **Step 2: Create docs/trait-aggregation-architecture.md** — Mermaid: Match → trait_combo_signature → group_comps → resolve_name → emit → app TraitChip.

- [ ] **Step 3: Append docs/project-changelog.md**

```markdown
## [phase-02-trait-centric-comp] — 2026-04-26

### Added
- Trait combo signature replaces champion-set hash for comp grouping (Pipeline).
- `comp_name_resolver` with curated trait-combo → semantic name map (~20 entries).
- `TraitActivation` Swift model + `traits[]` field on Comp.
- `TraitCatalog`, `TraitAssetURL`, `TraitChip` view in App.

### Changed
- Schema bumped 1.1.0 → 1.2.0. Forward-compat decoder retains 1.0.0/1.1.0 support.
- CompCard renders trait chips row above champion row.

### Architecture impact
- Pipeline grouping algorithm reshaped — comp count may drop (collapsed by trait similarity). Tier thresholds may need re-tuning post-cron-run.
```

- [ ] **Step 4: Append docs/bugs-log.md** — log any bugs surfaced.

- [ ] **Step 5: Verify + commit + push**

```bash
git diff HEAD~1 docs/project-changelog.md | grep -c "^+## "  # ≥1
git add docs/
git commit -m "docs(phase-02): trait-centric comp identification"
git push origin feat/v0.1-implementation
```

---

## Success Criteria

- ✅ Comp names are semantic (≥80% of comps have non-concat names).
- ✅ Trait chips render with icons + counts in CompCard.
- ✅ Schema 1.2.0 published; forward-compat 1.1.0 decode still works.
- ✅ All tests green.
- ✅ Manual gate: anh inspects 3+ comps, sees meaningful trait names + chips.

## Risks

- **Trait name map drift** — Set 17 may have traits not yet in `trait_name_map.json` → fallback auto-name kicks in. Mitigation: log unmapped signatures, anh adds curated entries between cron runs.
- **Comp count collapse** — trait grouping may collapse 60 comps into 30. UX still good (each more meaningful) but tier list shorter. Acceptable tradeoff.
- **Trait icon URL pattern unverified** — Phase 1 Task 0 only verified champion icons. Trait icon path is best-guess; first runtime fetch will show 404 if wrong → placeholder ⭐ falls through. Phase 2 Task 7 Step 6 surfaces 404s in os.Logger.

## Next Phase

→ [Phase 3 — Rich comp details](phase-03-rich-comp-details.md)
