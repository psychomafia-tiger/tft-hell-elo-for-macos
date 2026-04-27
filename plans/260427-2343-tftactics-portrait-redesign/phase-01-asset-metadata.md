# Phase 1 — Asset Metadata + URL Builder

**Status:** ⏳ Pending
**Estimate:** ~40 min
**Depends on:** Phase 0 complete

## Context

Foundation for item icon rendering. Mirror the Phase 1 (champions) + Phase 2 (traits) pattern: bundle a JSON metadata file at `App/TFTMac/Resources/set17-items.json` with `apiName → (displayName, iconToken, itemClass)` mappings, plus a Swift URL builder `ItemAssetURL` that produces CDragon URLs from iconToken. Existing `ItemCatalog.swift` is hand-coded with 17 entries and `iconAsset: nil` — refactor to load from bundled JSON + expose itemClass.

URL pattern (verified in self-review):
- en_us.json `data['items'][i].icon` = `ASSETS/Maps/TFT/Icons/Items/Hexcore/TFT_Item_GargoyleStoneplate.TFT_Set13.tex`
- Convert: `ASSETS/`→`game/assets/`, `.tex`→`.png`, lowercase entire path
- Final URL: `https://raw.communitydragon.org/latest/game/assets/maps/tft/icons/items/hexcore/tft_item_gargoylestoneplate.tft_set13.png` → 200 OK

## Files

- Create: `Pipeline/scripts/generate-set17-items.py` (fetch CDragon, classify, emit JSON)
- Create: `App/TFTMac/Resources/set17-items.json` (~80-150 entries, generated)
- Create: `App/TFTMac/Generated/ItemAssetURL.swift` (URL builder)
- Modify: `App/TFTMac/Generated/ItemCatalog.swift` (load from JSON + add itemClass)
- Test: `App/TFTMacTests/ItemAssetURLTests.swift`
- Test: `App/TFTMacTests/ItemCatalogTests.swift` (replace existing test if any)

## Tasks

### Task 1.1: Write Pipeline generation script

**Files:**
- Create: `Pipeline/scripts/generate-set17-items.py`

- [ ] **Step 1: Create script with CDragon fetch + classify + JSON emit**

Write to `Pipeline/scripts/generate-set17-items.py`:

```python
"""Generate App/TFTMac/Resources/set17-items.json from CommunityDragon en_us.json.

Usage: python3 Pipeline/scripts/generate-set17-items.py

Filters items by:
  - apiName starts with 'TFT_Item_'
  - excludes augment/anomaly prefixes (TFT_Item_Augment_, TFT17_EkkoOffering_)
  - excludes pure components (no icon path)

Auto-classifies itemClass by keyword scan of `desc` field. Heuristic — manual
override for known items can be added to OVERRIDES dict.
"""
from __future__ import annotations
import json, re, sys, urllib.request
from pathlib import Path

CDRAGON_URL = "https://raw.communitydragon.org/latest/cdragon/tft/en_us.json"
OUTPUT_PATH = Path(__file__).parent.parent.parent / "App/TFTMac/Resources/set17-items.json"

# Manual class overrides for items where keyword heuristic fails
OVERRIDES = {
    "TFT_Item_GargoyleStoneplate": "tank",
    "TFT_Item_BrambleVest":        "tank",
    "TFT_Item_DragonsClaw":        "tank",
    "TFT_Item_Warmogs":            "tank",
    "TFT_Item_SunfireCape":        "tank",
    "TFT_Item_TitansResolve":      "tank",
    "TFT_Item_RedBuff":            "tank",
    "TFT_Item_InfinityEdge":       "ad",
    "TFT_Item_LastWhisper":        "ad",
    "TFT_Item_Bloodthirster":      "ad",
    "TFT_Item_GiantSlayer":        "ad",
    "TFT_Item_Deathblade":         "ad",
    "TFT_Item_GuinsoosRageblade":  "ad",
    "TFT_Item_RunaansHurricane":   "ad",
    "TFT_Item_Runaans":            "ad",
    "TFT_Item_StatikkShiv":        "ad",
    "TFT_Item_HandOfJustice":      "ad",
    "TFT_Item_RabadonsDeathcap":   "ap",
    "TFT_Item_JeweledGauntlet":    "ap",
    "TFT_Item_ArchangelsStaff":    "ap",
    "TFT_Item_BlueBuff":           "ap",
    "TFT_Item_HextechGunblade":    "ap",
    "TFT_Item_IonicSpark":         "ap",
    "TFT_Item_Morellonomicon":     "ap",
    "TFT_Item_Shojin":             "ap",
    "TFT_Item_SpearOfShojin":      "ap",
    "TFT_Item_AdaptiveHelm":       "utility",
    "TFT_Item_Redemption":         "utility",
    "TFT_Item_ZekesHerald":        "utility",
    "TFT_Item_Zephyr":             "utility",
    "TFT_Item_ProtectorsVow":      "utility",
}


def classify(desc: str) -> str:
    """Heuristic itemClass from item description text."""
    if not desc:
        return "unknown"
    d = desc.upper()
    has_armor = any(kw in d for kw in ["ARMOR", "MAGIC RESIST", "@MAGICRESIST", "@HEALTH"])
    has_ad    = any(kw in d for kw in ["ATTACK DAMAGE", "@AD", "CRITICAL STRIKE", "ATTACK SPEED"])
    has_ap    = any(kw in d for kw in ["ABILITY POWER", "@AP", "MANA"])
    has_util  = any(kw in d for kw in ["HEAL", "SHIELD", "ALLIES", "TEAM"])
    if has_armor and not has_ad and not has_ap: return "tank"
    if has_ad and not has_ap: return "ad"
    if has_ap: return "ap"
    if has_util: return "utility"
    return "unknown"


def icon_to_token(icon_path: str) -> str:
    """`ASSETS/Maps/TFT/Icons/Items/Hexcore/TFT_Item_GargoyleStoneplate.TFT_Set13.tex`
    → `tft_item_gargoylestoneplate.tft_set13`. App prepends URL base + `.png`.
    """
    if not icon_path:
        return ""
    # Take filename only (strip directory path), drop .tex, lowercase
    filename = icon_path.split("/")[-1]
    return filename.replace(".tex", "").replace(".TEX", "").lower()


def main() -> None:
    print(f"Fetching {CDRAGON_URL}...")
    req = urllib.request.Request(CDRAGON_URL, headers={"User-Agent": "Mozilla/5.0"})
    raw = urllib.request.urlopen(req).read()
    data = json.loads(raw)

    items = data.get("items", [])
    print(f"Total items in en_us.json: {len(items)}")

    EXCLUDE_PREFIXES = ("TFT_Item_Augment_", "TFT17_EkkoOffering_", "TFT_Item_Component_")
    output = {}
    for item in items:
        api_name = item.get("apiName", "")
        if not api_name.startswith("TFT_Item_"):
            continue
        if any(api_name.startswith(p) for p in EXCLUDE_PREFIXES):
            continue
        icon = item.get("icon")
        if not icon:
            continue
        token = icon_to_token(icon)
        if not token:
            continue
        item_class = OVERRIDES.get(api_name) or classify(item.get("desc", ""))
        output[api_name] = {
            "displayName": item.get("name", api_name),
            "iconToken":   token,
            "itemClass":   item_class,
        }

    print(f"Filtered to {len(output)} items")
    OUTPUT_PATH.write_text(json.dumps(output, sort_keys=True, indent=2, ensure_ascii=False))
    print(f"Wrote {OUTPUT_PATH}")

    # class distribution
    from collections import Counter
    dist = Counter(v["itemClass"] for v in output.values())
    print(f"Class distribution: {dict(dist)}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run script + verify output**

Run: `python3 Pipeline/scripts/generate-set17-items.py`
Expected: `Wrote .../set17-items.json` + class distribution showing non-zero counts in tank/ad/ap/utility (some unknown OK).

- [ ] **Step 3: Sanity check JSON shape**

Run:
```bash
python3 -c "
import json
d = json.load(open('App/TFTMac/Resources/set17-items.json'))
print(f'entries: {len(d)}')
g = d.get('TFT_Item_GargoyleStoneplate', {})
print(f'GargoyleStoneplate: {g}')
"
```
Expected: `entries: 80-150`, `GargoyleStoneplate: {'displayName': 'Gargoyle Stoneplate', 'iconToken': 'tft_item_gargoylestoneplate.tft_set13', 'itemClass': 'tank'}`.

### Task 1.2: Write ItemAssetURL Swift module

**Files:**
- Create: `App/TFTMac/Generated/ItemAssetURL.swift`
- Test: `App/TFTMacTests/ItemAssetURLTests.swift`

- [ ] **Step 1: Write failing test**

Write to `App/TFTMacTests/ItemAssetURLTests.swift`:

```swift
import XCTest
@testable import TFTMac

final class ItemAssetURLTests: XCTestCase {

    func test_buildsCDragonURL_forKnownToken() {
        let token = "tft_item_gargoylestoneplate.tft_set13"
        let url = ItemAssetURL.icon(forIconToken: token)
        XCTAssertEqual(
            url?.absoluteString,
            "https://raw.communitydragon.org/latest/game/assets/maps/tft/icons/items/hexcore/tft_item_gargoylestoneplate.tft_set13.png"
        )
    }

    func test_returnsNil_forEmptyToken() {
        XCTAssertNil(ItemAssetURL.icon(forIconToken: ""))
    }

    func test_returnsNil_forWhitespaceToken() {
        XCTAssertNil(ItemAssetURL.icon(forIconToken: "   "))
    }
}
```

- [ ] **Step 2: Run test to verify FAIL (compile error — ItemAssetURL doesn't exist)**

Run:
```bash
xcodebuild -project App/TFTMac.xcodeproj -scheme TFTMac \
  -only-testing:TFTMacTests/ItemAssetURLTests test 2>&1 | tail -8
```
Expected: TEST FAILED — "Cannot find 'ItemAssetURL' in scope".

- [ ] **Step 3: Implement ItemAssetURL**

Write to `App/TFTMac/Generated/ItemAssetURL.swift`:

```swift
import Foundation

/// CommunityDragon CDN URL builder for TFT item icons.
///
/// Pattern verified 2026-04-27: en_us.json `data['items'][i].icon` field
/// (e.g. `ASSETS/Maps/TFT/Icons/Items/Hexcore/TFT_Item_GargoyleStoneplate.TFT_Set13.tex`)
/// converts to URL by:
///   1. Take filename only (drop directory prefix)
///   2. Drop `.tex` suffix
///   3. Lowercase
///   4. Append `.png` and prepend CDN base
///
/// The set suffix (`.tft_set13`, `.tft_set17`) varies per item and reflects
/// when Riot last refreshed the texture — NOT the active TFT set. It is part
/// of the canonical filename and must be preserved exactly.
enum ItemAssetURL {

    private static let cdnBase =
        "https://raw.communitydragon.org/latest/game/assets/maps/tft/icons/items/hexcore"

    /// Builds the icon URL for a bundled `iconToken` from `set17-items.json`.
    /// Returns nil for empty / whitespace-only tokens.
    static func icon(forIconToken token: String) -> URL? {
        let trimmed = token.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: "\(cdnBase)/\(trimmed).png")
    }
}
```

- [ ] **Step 4: Add file to Xcode target**

Run (per `project_xcode_pbxproj_sync.md` memory — Ruby xcodeproj gem is the working tool):
```bash
ruby -rxcodeproj -e "
proj = Xcodeproj::Project.open('App/TFTMac.xcodeproj')
target = proj.targets.find { |t| t.name == 'TFTMac' }
group = proj.main_group['App']['TFTMac']['Generated']
file_ref = group.new_reference('ItemAssetURL.swift')
target.source_build_phase.add_file_reference(file_ref)
proj.save
puts 'Added ItemAssetURL.swift to TFTMac target'
"
```
Expected: `Added ItemAssetURL.swift to TFTMac target`. If Ruby/xcodeproj missing: `gem install xcodeproj` first.

- [ ] **Step 5: Add ItemAssetURLTests to test target**

Run:
```bash
ruby -rxcodeproj -e "
proj = Xcodeproj::Project.open('App/TFTMac.xcodeproj')
target = proj.targets.find { |t| t.name == 'TFTMacTests' }
group = proj.main_group['App']['TFTMacTests']
file_ref = group.new_reference('ItemAssetURLTests.swift')
target.source_build_phase.add_file_reference(file_ref)
proj.save
puts 'Added ItemAssetURLTests.swift to TFTMacTests target'
"
```

- [ ] **Step 6: Run test to verify PASS**

Run:
```bash
xcodebuild -project App/TFTMac.xcodeproj -scheme TFTMac \
  -only-testing:TFTMacTests/ItemAssetURLTests test 2>&1 | tail -8
```
Expected: 3 tests passed.

### Task 1.3: Refactor ItemCatalog to load from JSON + expose itemClass

**Files:**
- Modify: `App/TFTMac/Generated/ItemCatalog.swift`
- Test: `App/TFTMacTests/ItemCatalogTests.swift`

- [ ] **Step 1: Add set17-items.json to Xcode bundle resources**

Run:
```bash
ruby -rxcodeproj -e "
proj = Xcodeproj::Project.open('App/TFTMac.xcodeproj')
target = proj.targets.find { |t| t.name == 'TFTMac' }
group = proj.main_group['App']['TFTMac']['Resources']
file_ref = group.new_reference('set17-items.json')
target.resources_build_phase.add_file_reference(file_ref)
proj.save
puts 'Added set17-items.json to TFTMac resources'
"
```

- [ ] **Step 2: Write failing tests for new ItemCatalog API**

Write to `App/TFTMacTests/ItemCatalogTests.swift` (replace any existing content):

```swift
import XCTest
@testable import TFTMac

final class ItemCatalogTests: XCTestCase {

    func test_displayName_knownItem_returnsCatalogName() {
        XCTAssertEqual(
            ItemCatalog.displayName(forId: "TFT_Item_GargoyleStoneplate"),
            "Gargoyle Stoneplate"
        )
    }

    func test_displayName_unknownItem_returnsRawId() {
        let id = "TFT_Item_DoesNotExist_X"
        XCTAssertEqual(ItemCatalog.displayName(forId: id), id)
    }

    func test_iconToken_knownItem_returnsToken() {
        let token = ItemCatalog.iconToken(forId: "TFT_Item_GargoyleStoneplate")
        XCTAssertNotNil(token)
        XCTAssertTrue(token?.contains("gargoylestoneplate") ?? false)
    }

    func test_iconToken_unknownItem_returnsNil() {
        XCTAssertNil(ItemCatalog.iconToken(forId: "TFT_Item_DoesNotExist_X"))
    }

    func test_itemClass_tankItem_returnsTank() {
        XCTAssertEqual(
            ItemCatalog.itemClass(forId: "TFT_Item_GargoyleStoneplate"),
            .tank
        )
    }

    func test_itemClass_unknownItem_returnsUnknown() {
        XCTAssertEqual(
            ItemCatalog.itemClass(forId: "TFT_Item_DoesNotExist_X"),
            .unknown
        )
    }
}
```

- [ ] **Step 3: Run test to verify FAIL**

Run:
```bash
xcodebuild -project App/TFTMac.xcodeproj -scheme TFTMac \
  -only-testing:TFTMacTests/ItemCatalogTests test 2>&1 | tail -8
```
Expected: FAIL — `iconToken` and `itemClass` methods not found.

- [ ] **Step 4: Refactor ItemCatalog**

Replace contents of `App/TFTMac/Generated/ItemCatalog.swift`:

```swift
import Foundation

/// Static lookup from item ID (e.g. `TFT_Item_GargoyleStoneplate`) to display
/// metadata, loaded from bundled `set17-items.json` (generated by
/// `Pipeline/scripts/generate-set17-items.py`).
///
/// `iconToken` is a CDragon-derived asset filename minus extension (e.g.
/// `tft_item_gargoylestoneplate.tft_set13`) — combine with `ItemAssetURL`
/// for the full CDN URL.
///
/// `itemClass` is a heuristic classification (tank/ad/ap/utility) used as a
/// tinted-square fallback color when the icon URL fails to load.
enum ItemCatalog {

    enum ItemClass: String, Codable {
        case tank, ad, ap, utility, unknown
    }

    struct Entry: Codable {
        let displayName: String
        let iconToken: String
        let itemClass: ItemClass
    }

    /// Lazy-loaded bundled JSON. Empty dict if resource missing (defensive —
    /// app still renders, fallback to id-as-name + class .unknown).
    private static let entries: [String: Entry] = loadBundle()

    private static func loadBundle() -> [String: Entry] {
        guard let url = Bundle.main.url(forResource: "set17-items", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) else {
            return [:]
        }
        return decoded
    }

    /// Human-readable display name; falls back to raw id when missing.
    static func displayName(forId id: String) -> String {
        entries[id]?.displayName ?? id
    }

    /// CDragon icon token; nil when item not in catalog.
    static func iconToken(forId id: String) -> String? {
        entries[id]?.iconToken
    }

    /// Item class (for fallback tint); `.unknown` when item not in catalog.
    static func itemClass(forId id: String) -> ItemClass {
        entries[id]?.itemClass ?? .unknown
    }
}
```

- [ ] **Step 5: Add ItemCatalogTests file to test target**

Run:
```bash
ruby -rxcodeproj -e "
proj = Xcodeproj::Project.open('App/TFTMac.xcodeproj')
target = proj.targets.find { |t| t.name == 'TFTMacTests' }
group = proj.main_group['App']['TFTMacTests']
existing = group.children.find { |c| c.path == 'ItemCatalogTests.swift' }
unless existing
  file_ref = group.new_reference('ItemCatalogTests.swift')
  target.source_build_phase.add_file_reference(file_ref)
  proj.save
  puts 'Added ItemCatalogTests.swift'
else
  puts 'Already in target'
end
"
```

- [ ] **Step 6: Run test to verify PASS**

Run:
```bash
xcodebuild -project App/TFTMac.xcodeproj -scheme TFTMac \
  -only-testing:TFTMacTests/ItemCatalogTests test 2>&1 | tail -8
```
Expected: 6 tests passed.

### Task 1.4: Commit Phase 1

- [ ] **Step 1: Run regression check on broader test scope**

Run:
```bash
xcodebuild -project App/TFTMac.xcodeproj -scheme TFTMac \
  -only-testing:TFTMacTests/ItemCatalogTests \
  -only-testing:TFTMacTests/ItemAssetURLTests \
  -only-testing:TFTMacTests/DataManagerTests \
  -only-testing:TFTMacTests/TierListDecodingTests \
  -only-testing:TFTMacTests/SampleTierListFixtureTests test 2>&1 | tail -8
```
Expected: `** TEST SUCCEEDED **` — no regression from ItemCatalog refactor.

- [ ] **Step 2: Commit**

```bash
git add Pipeline/scripts/generate-set17-items.py \
        App/TFTMac/Resources/set17-items.json \
        App/TFTMac/Generated/ItemAssetURL.swift \
        App/TFTMac/Generated/ItemCatalog.swift \
        App/TFTMacTests/ItemAssetURLTests.swift \
        App/TFTMacTests/ItemCatalogTests.swift \
        App/TFTMac.xcodeproj/project.pbxproj
git commit -m "feat(app): set17 item asset metadata + CDragon URL builder

Generated set17-items.json (~100 entries) from CommunityDragon en_us.json
with itemClass heuristic + manual overrides for ~30 known items.
Refactored ItemCatalog to load from bundle + expose iconToken and
itemClass. New ItemAssetURL builds CDragon icon URLs from token.

Pattern mirrors Phase 1 ChampionAssetURL/ChampionCatalog and Phase 2
TraitAssetURL/TraitCatalog. URL format verified live:
  https://raw.communitydragon.org/latest/game/assets/maps/tft/icons/items/hexcore/<token>.png

Tests: 9 new (3 ItemAssetURL + 6 ItemCatalog), zero regression."
```

## Success criteria

- ✅ `set17-items.json` exists with 80-150 entries
- ✅ `ItemAssetURL.icon(forIconToken:)` returns valid CDragon URLs
- ✅ `ItemCatalog.displayName/iconToken/itemClass` work for known + unknown items
- ✅ All targeted tests pass
- ✅ Existing data manager / decoding / fixture tests not regressed

## Risk assessment

- CDragon en_us.json schema change (apiName field renamed): script fails fast, manual JSON edit fallback. Unlikely — schema stable across recent sets.
- Manual OVERRIDES out-of-date for new items: itemClass falls back to keyword classifier or `.unknown`. Acceptable degradation.
- Xcode project sync via Ruby gem fails: per memory `project_xcode_pbxproj_sync.md` Ruby is the working tool (Python pbxproj broken for objectVersion=77). If gem missing: `gem install xcodeproj`.

## Next phase

→ [Phase 2 — ItemBadge view](phase-02-item-badge.md)
