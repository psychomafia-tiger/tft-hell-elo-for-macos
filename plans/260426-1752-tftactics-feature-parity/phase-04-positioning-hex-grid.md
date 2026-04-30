# Phase 4 — Positioning Hex Grid

**Parent plan:** [plan.md](plan.md)
**Status:** ⏳ Blocked by Phase 3
**Effort:** 10-14h
**Gaps closed:** A8 (positioning hex grid data), B4 (SwiftUI hex grid component)
**Manual gate before:** Phase 3 merged + anh sees rich comp details live
**Manual gate after:** anh expands top-3 S-tier comp, sees hex board with champion portraits placed in correct positions

---

## Goal

Aggregate per-champion positioning data from Match-v5 (`units[].rarity`, `units[].itemNames`, plus the `companion`/`tactician` data that exposes board layout when available) and render a SwiftUI Canvas-based 4×7 hex board showing where each champion belongs in the top comps. This is the final TFTactics-parity feature.

## Architecture

- **Pipeline (Python)** — `positioning_aggregator.py` extracts per-champion (row, col) coordinates from each top-4 placement. Output: per-comp `positioning: [{championId, hexCol, hexRow, frequency}]`. Note: Match-v5 may not always expose hex coords directly — we read from `units[].pos` if present, else infer from frontline/backline traits as fallback.
- **App (Swift)** — `Models/Position.swift`. New `Views/HexGridView.swift` using SwiftUI `Canvas` with offset coordinate math. Integrate into `ExpandedCardView` as final section.
- **Schema bump** — `1.3.0 → 1.4.0`. Forward-compat retained.

## Files

**Create:**
- `Pipeline/src/tftmac_pipeline/positioning_aggregator.py`
- `Pipeline/tests/test_positioning_aggregator.py`
- `App/TFTMac/Models/Position.swift`
- `App/TFTMac/Views/HexGridView.swift`
- `App/TFTMac/Views/HexCell.swift`
- `App/TFTMacTests/HexGridGeometryTests.swift`
- `App/TFTMacTests/PositionDecodingTests.swift`

**Modify:**
- `Pipeline/src/tftmac_pipeline/json_emitter.py` — emit `positioning[]` + schema 1.4.0
- `App/TFTMac/Models/Comp.swift` — add `positioning: [Position]`
- `App/TFTMac/Models/SchemaVersion.swift` — accept 1.4.0
- `App/TFTMac/Views/ExpandedCardView.swift` — wire HexGridView at bottom

---

## Task 0: Verify Match-v5 positioning availability (research)

**Files:** `plans/260426-1752-tftactics-feature-parity/research/match-v5-positioning.md`

- [ ] **Step 1: Inspect raw match data**

```bash
cd Pipeline && .venv/bin/python -c "
import json, glob
for path in glob.glob('cache/matches/*.json')[:3]:
    m = json.load(open(path))
    p = m['info']['participants'][0]
    print('--- match:', path)
    print('participant keys:', list(p.keys()))
    if p.get('units'):
        print('first unit keys:', list(p['units'][0].keys()))
        print('first unit:', json.dumps(p['units'][0], indent=2))
"
```

- [ ] **Step 2: Document findings**

Write `plans/260426-1752-tftactics-feature-parity/research/match-v5-positioning.md`:
- Does `units[i]` have a `pos` / `position` / `boardPosition` field?
- If yes → coordinate range (e.g. 0-27 for 4×7 = 28 hexes)?
- If no → fallback strategy: classify by trait (frontline/backline/flex), assign default rows.

- [ ] **Step 3: Commit research**

```bash
git add plans/260426-1752-tftactics-feature-parity/research/match-v5-positioning.md
git commit -m "research: Match-v5 positioning data availability"
```

---

## Task 1: Positioning aggregator (Python TDD)

**Files:**
- Create: `Pipeline/src/tftmac_pipeline/positioning_aggregator.py`
- Test: `Pipeline/tests/test_positioning_aggregator.py`

- [ ] **Step 1: Write failing test (assume `pos` field present)**

```python
# Pipeline/tests/test_positioning_aggregator.py
"""Per-comp positioning aggregation. pos field range 0-27 (4 rows × 7 cols)."""
from tftmac_pipeline.positioning_aggregator import aggregate_positions

def test_picks_modal_position_per_champion():
    participants = [
        {"placement": 1, "units": [
            {"character_id": "TFT17_Aatrox", "pos": 14},  # row 2 col 0 (frontline left)
            {"character_id": "TFT17_Viktor", "pos": 3},   # row 0 col 3 (backline middle)
        ]},
        {"placement": 2, "units": [
            {"character_id": "TFT17_Aatrox", "pos": 14},  # same
            {"character_id": "TFT17_Viktor", "pos": 4},   # different col
        ]},
        {"placement": 3, "units": [
            {"character_id": "TFT17_Aatrox", "pos": 15},  # different
            {"character_id": "TFT17_Viktor", "pos": 3},   # back to col 3
        ]},
    ]
    positions = aggregate_positions(participants)
    aatrox = next(p for p in positions if p["championId"] == "TFT17_Aatrox")
    viktor = next(p for p in positions if p["championId"] == "TFT17_Viktor")
    # Most frequent
    assert aatrox["pos"] == 14  # 2/3
    assert viktor["pos"] == 3   # 2/3

def test_handles_missing_pos_field():
    participants = [
        {"placement": 1, "units": [{"character_id": "TFT17_Aatrox"}]},
    ]
    positions = aggregate_positions(participants)
    # Champions with no pos data omitted (or default fallback documented in research)
    assert all("pos" in p for p in positions)
```

- [ ] **Step 2: Run test, expect fail**

```bash
cd Pipeline && .venv/bin/pytest tests/test_positioning_aggregator.py -v
```

- [ ] **Step 3: Implement (with fallback strategy from research)**

```python
# Pipeline/src/tftmac_pipeline/positioning_aggregator.py
"""Per-champion positioning extraction.

Pulls modal (most frequent) hex position per champion across top-4 placements.
Pos field is 0-27 (4 rows top-to-bottom × 7 cols left-to-right):
- Row 0 (pos 0-6) = backline (your side, far from enemy)
- Row 3 (pos 21-27) = frontline (closest to enemy)

If `pos` missing, champion omitted from positioning output (UI shows
generic placement based on frontline/backline trait classification fallback,
deferred to a future phase).
"""
from collections import Counter, defaultdict

def aggregate_positions(participants: list[dict], min_frequency: int = 2) -> list[dict]:
    top4 = [p for p in participants if p.get("placement", 8) <= 4]
    pos_counts: dict[str, Counter] = defaultdict(Counter)
    for p in top4:
        for unit in p.get("units", []):
            cid = unit.get("character_id", "")
            pos = unit.get("pos")
            if cid and pos is not None:
                pos_counts[cid][pos] += 1
    out = []
    for cid, counts in pos_counts.items():
        modal_pos, freq = counts.most_common(1)[0]
        if freq < min_frequency:
            continue
        out.append({
            "championId": cid,
            "pos": modal_pos,
            "frequency": freq / sum(counts.values()),
        })
    return out
```

- [ ] **Step 4: Run test, commit**

```bash
cd Pipeline && .venv/bin/pytest tests/test_positioning_aggregator.py -v
git add Pipeline/src/tftmac_pipeline/positioning_aggregator.py Pipeline/tests/test_positioning_aggregator.py
git commit -m "feat(pipeline): positioning_aggregator extracts modal hex position"
```

---

## Task 2: Wire positioning into json_emitter (schema 1.4.0)

**Files:**
- Modify: `Pipeline/src/tftmac_pipeline/json_emitter.py`
- Modify: `Pipeline/src/tftmac_pipeline/run_aggregator.py`

- [ ] **Step 1: Bump SCHEMA_VERSION + emit positioning**

```python
SCHEMA_VERSION = "1.4.0"

# In emit_comp:
def emit_comp(grouped_comp, derived_name, participants):
    return {
        # ... all existing Phase 3 fields
        "positioning": aggregate_positions(participants),
    }
```

Add import:

```python
from .positioning_aggregator import aggregate_positions
```

- [ ] **Step 2: Update tests**

```python
# tests/test_json_emitter.py
def test_schema_is_1_4_0():
    from tftmac_pipeline.json_emitter import SCHEMA_VERSION
    assert SCHEMA_VERSION == "1.4.0"

def test_comp_has_positioning_field():
    # ... call emit_comp with fake participants
    assert "positioning" in comp
```

- [ ] **Step 3: Run full Pipeline suite**

```bash
cd Pipeline && .venv/bin/pytest -v
```

- [ ] **Step 4: Commit**

```bash
git add Pipeline/src/tftmac_pipeline/json_emitter.py Pipeline/src/tftmac_pipeline/run_aggregator.py Pipeline/tests/
git commit -m "feat(pipeline): emit positioning per comp (schema 1.4.0)"
```

---

## Task 3: Position Swift model + Comp extension (TDD)

**Files:**
- Create: `App/TFTMac/Models/Position.swift`
- Modify: `App/TFTMac/Models/Comp.swift`
- Create: `App/TFTMacTests/PositionDecodingTests.swift`

- [ ] **Step 1: Write failing test**

```swift
// App/TFTMacTests/PositionDecodingTests.swift
import XCTest
@testable import TFTMac

final class PositionDecodingTests: XCTestCase {

    func test_decodesPositionFromV1_4_0() throws {
        let json = #"""
        {"championId": "TFT17_Aatrox", "pos": 14, "frequency": 0.85}
        """#.data(using: .utf8)!
        let p = try JSONDecoder().decode(Position.self, from: json)
        XCTAssertEqual(p.championId, "TFT17_Aatrox")
        XCTAssertEqual(p.pos, 14)
        XCTAssertEqual(p.row, 2)  // 14 / 7
        XCTAssertEqual(p.col, 0)  // 14 % 7
    }

    func test_compForwardCompatMissingPositioning() throws {
        let json = #"""
        {"comp_id": "x", "name": "X", "tier": "B",
         "play_rate": 0.02, "avg_placement": 4.5, "top_4_rate": 0.4,
         "sample_size": 50, "champions": [], "anomalies": [], "traits": []}
        """#.data(using: .utf8)!
        let dec = JSONDecoder(); dec.keyDecodingStrategy = .convertFromSnakeCase
        let comp = try dec.decode(Comp.self, from: json)
        XCTAssertEqual(comp.positioning, [])
    }
}
```

- [ ] **Step 2: Run test, expect fail**

```bash
xcodebuild test -project App/TFTMac.xcodeproj -scheme TFTMac -destination 'platform=macOS' -only-testing:TFTMacTests/PositionDecodingTests 2>&1 | tail -10
```

- [ ] **Step 3: Implement Position.swift**

```swift
// App/TFTMac/Models/Position.swift
import Foundation

/// Champion hex position on the 4×7 board.
///
/// `pos` is 0-27 (4 rows × 7 cols). Row 0 = backline (your side), row 3 =
/// frontline (closest to enemy). `frequency` is fraction of top-4 placements
/// where this champion was at this hex.
struct Position: Codable, Equatable {
    let championId: String
    let pos: Int
    let frequency: Double

    var row: Int { pos / 7 }
    var col: Int { pos % 7 }
}
```

- [ ] **Step 4: Extend Comp.swift**

Add property + decode (same forward-compat pattern):

```swift
struct Comp: Encodable {
    // ... existing
    let positioning: [Position]   // NEW

    init(
        // ... existing
        positioning: [Position] = []
    ) {
        // ...
        self.positioning = positioning
    }
}

extension Comp: Decodable {
    enum CodingKeys: String, CodingKey {
        // ... existing
        case positioning
    }
    init(from decoder: Decoder) throws {
        // ... existing decodes
        self.positioning = (try? c.decodeIfPresent([Position].self, forKey: .positioning)) ?? []
    }
}
```

- [ ] **Step 5: Update SchemaVersion**

```swift
enum SchemaVersion {
    static let app: String = "1.4.0"
    static let acceptedRemote: Set<String> = ["1.0.0", "1.1.0", "1.2.0", "1.3.0", "1.4.0"]
}
```

- [ ] **Step 6: Register, run tests, commit**

```bash
ruby -e "
require 'xcodeproj'
proj = Xcodeproj::Project.open('App/TFTMac.xcodeproj')
target = proj.targets.find { |t| t.name == 'TFTMac' }
test_target = proj.targets.find { |t| t.name == 'TFTMacTests' }
target.add_file_references([proj.main_group.find_subpath('TFTMac/Models', true).new_file('App/TFTMac/Models/Position.swift')])
test_target.add_file_references([proj.main_group.find_subpath('TFTMacTests', true).new_file('App/TFTMacTests/PositionDecodingTests.swift')])
proj.save
"
xcodebuild test -project App/TFTMac.xcodeproj -scheme TFTMac -destination 'platform=macOS' -only-testing:TFTMacTests/PositionDecodingTests 2>&1 | tail -20

git add App/TFTMac/Models/ App/TFTMacTests/PositionDecodingTests.swift App/TFTMac.xcodeproj
git commit -m "feat(app): Position model + Comp.positioning forward-compat decode"
```

---

## Task 4: Hex grid geometry (TDD)

**Files:**
- Create: `App/TFTMac/Views/HexCell.swift`
- Test: `App/TFTMacTests/HexGridGeometryTests.swift`

- [ ] **Step 1: Write failing test for hex coordinate math**

```swift
// App/TFTMacTests/HexGridGeometryTests.swift
import XCTest
@testable import TFTMac

final class HexGridGeometryTests: XCTestCase {

    /// TFT board is 4 rows × 7 cols, offset coordinates: even rows shifted
    /// right by half a hex width. Hex size: 30pt diameter (24pt portrait + 3pt margin).
    func test_centerForRow0Col0() {
        let center = HexGeometry.center(row: 0, col: 0, hexSize: 30)
        // Row 0 (top row, your backline) at y = 15 (radius). Col 0 at x = 15.
        // Even row offset: row 0 is even, so no horizontal shift.
        XCTAssertEqual(center.x, 15, accuracy: 0.5)
        XCTAssertEqual(center.y, 15, accuracy: 0.5)
    }

    func test_centerForRow1Col0_oddRowShifted() {
        let center = HexGeometry.center(row: 1, col: 0, hexSize: 30)
        // Row 1 is odd → shifted right by hexSize/2 = 15. So x = 15 + 15 = 30.
        // Y: row spacing = hexSize * sqrt(3)/2 ≈ 26. Row 1 y = 15 + 26 = 41.
        XCTAssertEqual(center.x, 30, accuracy: 0.5)
        XCTAssertEqual(center.y, 41, accuracy: 1.0)
    }

    func test_totalGridSizeFor4Rows7Cols() {
        let size = HexGeometry.totalSize(rows: 4, cols: 7, hexSize: 30)
        // Width: 7 cols + 0.5 offset for odd rows = 7.5 hexes wide. 7.5 * 30 = 225.
        // Height: 4 rows = 1 + (4-1)*sqrt(3)/2 ≈ 1 + 2.6 ≈ 3.6 * 30 = 108.
        XCTAssertEqual(size.width, 225, accuracy: 1.0)
        XCTAssertEqual(size.height, 108, accuracy: 2.0)
    }
}
```

- [ ] **Step 2: Run test, expect fail**

```bash
xcodebuild test -project App/TFTMac.xcodeproj -scheme TFTMac -destination 'platform=macOS' -only-testing:TFTMacTests/HexGridGeometryTests 2>&1 | tail -10
```

- [ ] **Step 3: Implement HexCell.swift with HexGeometry helper**

```swift
// App/TFTMac/Views/HexCell.swift
import SwiftUI

/// Hex coordinate math. Offset coordinates: even rows aligned, odd rows
/// shifted right by half a hex width. Vertical spacing = hexSize * sqrt(3)/2.
enum HexGeometry {
    static let sqrt3Over2: CGFloat = 0.8660254  // sqrt(3) / 2

    static func center(row: Int, col: Int, hexSize: CGFloat) -> CGPoint {
        let radius = hexSize / 2
        let xOffset = (row % 2 == 1) ? radius : 0
        let x = radius + CGFloat(col) * hexSize + xOffset
        let y = radius + CGFloat(row) * hexSize * sqrt3Over2
        return CGPoint(x: x, y: y)
    }

    static func totalSize(rows: Int, cols: Int, hexSize: CGFloat) -> CGSize {
        let width = CGFloat(cols) * hexSize + (rows > 1 ? hexSize / 2 : 0)
        let height = hexSize + CGFloat(rows - 1) * hexSize * sqrt3Over2
        return CGSize(width: width, height: height)
    }
}

/// One hex cell with optional champion portrait inside.
struct HexCell: View {
    let championId: String?
    let hexSize: CGFloat
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            // Hex shape outline
            HexagonShape()
                .stroke(Theme.Colors.borderDefault, lineWidth: 1)
                .background(HexagonShape().fill(Theme.Colors.bgCard.opacity(0.4)))

            if let cid = championId {
                if let img = image {
                    Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                        .frame(width: hexSize * 0.7, height: hexSize * 0.7)
                        .clipShape(Circle())
                } else {
                    Circle().fill(Theme.Colors.bgCard)
                        .frame(width: hexSize * 0.7, height: hexSize * 0.7)
                }
            }
        }
        .frame(width: hexSize, height: hexSize)
        .help(championId.map { ChampionCatalog.displayName(forId: $0) } ?? "")
        .task(id: championId) {
            guard let cid = championId, image == nil,
                  let url = ChampionAssetURL.squarePortrait(forChampionId: cid),
                  let data = try? await AssetCache.shared.data(for: url),
                  let img = NSImage(data: data) else { return }
            self.image = img
        }
    }
}

/// Pointy-top hexagon path.
struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let r = min(rect.width, rect.height) / 2
        let cx = rect.midX
        let cy = rect.midY
        var path = Path()
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 2
            let x = cx + r * cos(angle)
            let y = cy + r * sin(angle)
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.closeSubpath()
        return path
    }
}
```

- [ ] **Step 4: Register, run tests, commit**

```bash
ruby -e "
require 'xcodeproj'
proj = Xcodeproj::Project.open('App/TFTMac.xcodeproj')
target = proj.targets.find { |t| t.name == 'TFTMac' }
test_target = proj.targets.find { |t| t.name == 'TFTMacTests' }
target.add_file_references([proj.main_group.find_subpath('TFTMac/Views', true).new_file('App/TFTMac/Views/HexCell.swift')])
test_target.add_file_references([proj.main_group.find_subpath('TFTMacTests', true).new_file('App/TFTMacTests/HexGridGeometryTests.swift')])
proj.save
"
xcodebuild test -project App/TFTMac.xcodeproj -scheme TFTMac -destination 'platform=macOS' -only-testing:TFTMacTests/HexGridGeometryTests 2>&1 | tail -20

git add App/TFTMac/Views/HexCell.swift App/TFTMacTests/HexGridGeometryTests.swift App/TFTMac.xcodeproj
git commit -m "feat(app): HexGeometry math + HexCell view"
```

---

## Task 5: HexGridView assembling 4×7 board

**Files:**
- Create: `App/TFTMac/Views/HexGridView.swift`

- [ ] **Step 1: Implement**

```swift
// App/TFTMac/Views/HexGridView.swift
import SwiftUI

/// 4×7 TFT board rendering with champion portraits at modal positions.
///
/// Pos field maps: pos 0-6 = row 0 (your backline), pos 21-27 = row 3 (frontline).
/// Empty hexes render as outline only.
struct HexGridView: View {
    let positioning: [Position]
    var hexSize: CGFloat = 36

    private var positionMap: [Int: String] {
        Dictionary(uniqueKeysWithValues: positioning.map { ($0.pos, $0.championId) })
    }

    var body: some View {
        let totalSize = HexGeometry.totalSize(rows: 4, cols: 7, hexSize: hexSize)
        ZStack(alignment: .topLeading) {
            ForEach(0..<4, id: \.self) { row in
                ForEach(0..<7, id: \.self) { col in
                    let pos = row * 7 + col
                    let center = HexGeometry.center(row: row, col: col, hexSize: hexSize)
                    HexCell(championId: positionMap[pos], hexSize: hexSize)
                        .position(x: center.x, y: center.y)
                }
            }
        }
        .frame(width: totalSize.width, height: totalSize.height)
    }
}

struct PositioningSection: View {
    let positioning: [Position]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Positioning")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textMuted)
            HexGridView(positioning: positioning)
                .padding(.vertical, 4)
        }
    }
}
```

- [ ] **Step 2: Build app**

```bash
xcodebuild build -project App/TFTMac.xcodeproj -scheme TFTMac 2>&1 | tail -5
```

- [ ] **Step 3: Register + commit**

```bash
ruby -e "
require 'xcodeproj'
proj = Xcodeproj::Project.open('App/TFTMac.xcodeproj')
target = proj.targets.find { |t| t.name == 'TFTMac' }
target.add_file_references([proj.main_group.find_subpath('TFTMac/Views', true).new_file('App/TFTMac/Views/HexGridView.swift')])
proj.save
"
git add App/TFTMac/Views/HexGridView.swift App/TFTMac.xcodeproj
git commit -m "feat(app): HexGridView 4x7 board renders positioned champions"
```

---

## Task 6: Wire HexGridView into ExpandedCardView

**Files:**
- Modify: `App/TFTMac/Views/ExpandedCardView.swift`

- [ ] **Step 1: Append PositioningSection at bottom**

In `body`, after `LevelNineAltsSection`:

```swift
if !comp.positioning.isEmpty {
    PositioningSection(positioning: comp.positioning)
        .padding(.top, 8)
}
```

- [ ] **Step 2: Run regression suite + manual smoke**

```bash
xcodebuild test -project App/TFTMac.xcodeproj -scheme TFTMac -destination 'platform=macOS' 2>&1 | tail -20
xcodebuild build -project App/TFTMac.xcodeproj -scheme TFTMac
open App/build/Debug/TFTMac.app
```

Anh: tap a top-tier comp → verify hex board renders below LV.9 alts with portraits in correct hex cells.

- [ ] **Step 3: Commit**

```bash
git add App/TFTMac/Views/ExpandedCardView.swift
git commit -m "feat(app): wire PositioningSection into ExpandedCardView"
```

---

## Task 7: Refresh bundled fixture to schema 1.4.0

**Files:**
- Modify: `App/TFTMac/Resources/sample-tier-list.json`

- [ ] **Step 1: Run pipeline against live cache to regenerate fixture**

```bash
cd Pipeline && .venv/bin/python scripts/run_aggregator.py --output ../App/TFTMac/Resources/sample-tier-list.json
```

- [ ] **Step 2: Run regression**

```bash
xcodebuild test -project App/TFTMac.xcodeproj -scheme TFTMac -destination 'platform=macOS' -only-testing:TFTMacTests/SampleTierListFixtureTests 2>&1 | tail -10
```

Update `test_fixtureSchemaIs1_2_0` → `test_fixtureSchemaIs1_4_0` and assert `positioning` key present on ≥1 comp.

- [ ] **Step 3: Commit**

```bash
git add App/TFTMac/Resources/sample-tier-list.json App/TFTMacTests/regression/SampleTierListFixtureTests.swift
git commit -m "data: refresh fixture to schema 1.4.0 (positioning included)"
```

---

## Task 8: Cleanup pending items (rotate keys + bug closure)

- [ ] **Step 1: Rotate Riot API key**

Anh: open https://developer.riotgames.com → regenerate dev key → update `.env` locally + GitHub Actions secret `RIOT_API_KEY`.

- [ ] **Step 2: Rotate PAT**

Anh: https://github.com/settings/tokens → revoke `ghp_1Zu...` → reauth `gh auth login` if needed.

- [ ] **Step 3: Verify pipeline still runs after secret rotation**

```bash
gh workflow run "<aggregator workflow name>" --ref feat/v0.1-implementation
gh run watch
```

Expected: green run with new key.

---

## Task 9: Phase Completion Protocol (final phase)

- [ ] **Step 1: Update docs/system-architecture.md** — final state diagram with all schema 1.4.0 fields.

- [ ] **Step 2: Create docs/positioning-architecture.md** — Mermaid: Match-v5 units[].pos → positioning_aggregator → emit_comp → HexGridView Canvas render.

- [ ] **Step 3: Append docs/project-changelog.md**

```markdown
## [phase-04-positioning-hex-grid] — 2026-04-26

### Added
- positioning_aggregator (Pipeline) — modal hex per champion from top-4 placements.
- Position model + Comp.positioning field (App).
- HexGeometry math + HexCell + HexGridView + PositioningSection (App).
- Hex board renders inside ExpandedCardView.

### Changed
- Schema bumped 1.3.0 → 1.4.0. Forward-compat decoder retains 1.0.0–1.4.0.
- Fixture refreshed to 1.4.0.

### Architecture impact
- App now feature-complete vs TFTactics Windows reference for Champions tab.
- v0.1 ship-ready pending Traits + Search tabs (deferred v0.2).

### Cleanup
- 🔐 Riot API key rotated.
- 🔐 PAT rotated.
- Bug #004 closed in Phase 1; no Phase 4 bugs.
```

- [ ] **Step 4: Final verification + push**

```bash
git diff HEAD~1 docs/project-changelog.md | grep -c "^+## "  # ≥1
git add docs/
git commit -m "docs(phase-04): positioning hex grid + final v0.1 state"
git push origin feat/v0.1-implementation
```

- [ ] **Step 5: Tag release**

```bash
git tag -a v0.1.0 -m "v0.1.0 — TFTactics feature parity (Champions tab)"
git push origin v0.1.0
```

---

## Success Criteria

- ✅ Top-3 S/A tier comps in popover show hex board with ≥4 placed champions.
- ✅ Positions visually correct (frontline tank in row 3, backline carry in row 0).
- ✅ Empty hexes render as outline.
- ✅ All tests green.
- ✅ Bundle size <8MB; app launch <500ms p95.
- ✅ Both API keys rotated.

## Risks

- **`pos` field absence in Match-v5** — if Task 0 research finds `pos` not exposed, fallback strategy (frontline/backline trait inference) needs implementing. Adds 4-6h to phase.
- **Hex math off-by-one** — coordinate convention (which row is your side vs enemy) may flip between TFT and our render. Mitigation: Task 4 tests pin row 0 = backline; manual smoke confirms visually.
- **Performance on slow Macs** — 60 comps × 28 hexes = 1680 cells if all expanded simultaneously. Mitigation: HexCell only loads image when championId present; SwiftUI lazy by default in scroll context.

## v0.1 Done — Next

After Phase 4 ships, anh dogfood (sử dụng thực tế) for ~2 weeks. Deferred to v0.2:
- Traits tab (filter comps by trait)
- Search tab (find comp by champion name)
- Multi-region beyond VN2
- Tier list freshness banner refinements
- Sound/notification on patch updates
