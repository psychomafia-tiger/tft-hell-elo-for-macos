# Phase 1 — Champion Resolution + Real Portraits + Tier Tuning

**Parent plan:** [plan.md](plan.md)
**Status:** ⏳ Ready
**Effort:** 7-12h
**Gaps closed:** A1 (champion name resolution), B1 (real portraits), C1 (tier threshold tuning), Bug #004 (aggregator metadata)
**Manual gate before:** anh confirm CommunityDragon URL pattern works in browser
**Manual gate after:** anh visually inspect popover — real Aatrox/Viktor/Illaoi portraits render, ≥1 S-tier comp visible

---

## Goal

Replace placeholder portrait circles with real Set 17 champion artwork from CommunityDragon CDN, build a name resolution catalog covering all ~60 Set 17 champion IDs (not just 15 hand-coded), and tune tier thresholds so the live VN2 dataset emits ≥1 tier-S comp.

## Architecture

- **Pipeline (Python)** — Bug #004 fix only: aggregator populates `updated_at`, `match_count`, fixes anomalies extraction. Tier thresholds adjusted in `tier_calculator.py`.
- **App (Swift)** — New `Services/AssetCache.swift` (URLSession + FileManager), new `Services/ChampionAssetURL.swift` (URL builder), refactor `Generated/ChampionCatalog.swift` from hand-coded to data-driven (load from bundled JSON), upgrade `Views/ChampionPortrait.swift` to async load via `AssetCache`.

## Files

**Create:**
- `App/TFTMac/Services/AssetCache.swift` — async fetch with 30-day disk cache
- `App/TFTMac/Services/ChampionAssetURL.swift` — URL builder for CommunityDragon
- `App/TFTMac/Resources/set17-champions.json` — full Set 17 champion ID → display name map (~60 entries)
- `App/TFTMacTests/AssetCacheTests.swift`
- `App/TFTMacTests/ChampionAssetURLTests.swift`
- `App/TFTMacTests/ChampionCatalogDataDrivenTests.swift`
- `Pipeline/tests/test_aggregator_metadata.py`

**Modify:**
- `App/TFTMac/Generated/ChampionCatalog.swift` — load from bundled JSON instead of hand-coded dict
- `App/TFTMac/Views/ChampionPortrait.swift` — async portrait load, fall back to placeholder
- `Pipeline/src/tftmac_pipeline/run_aggregator.py` — populate `updated_at`/`match_count` top-level
- `Pipeline/src/tftmac_pipeline/tier_calculator.py` — relax S-tier `play_rate` threshold from 0.10 → 0.05
- `App/TFTMacTests/regression/SampleTierListFixtureTests.swift` — refresh fixture, verify metadata fields

---

## Task 0: Verify CommunityDragon Set 17 endpoint (manual + 1 task)

**Files:** `plans/260426-1752-tftactics-feature-parity/research/communitydragon-set17.md`

- [x] **Step 1-3: ALREADY COMPLETE** — Research file `research/communitydragon-set17.md` written 2026-04-26 18:24 ICT. Verified URL patterns:
  - **Champion**: `https://raw.communitydragon.org/latest/game/assets/characters/{lower_id}/hud/{lower_id}_square.tft_set17.png`
  - **Trait**: `https://raw.communitydragon.org/latest/game/assets/ux/traiticons/trait_icon_17_{lower_name}.tft_set17.png`
  - **Item**: NOT deterministic — needs hand-curated mapping (Phase 3 plan delta noted in research file).

---

## Task 1: Aggregator metadata bug #004 fix (TDD)

**Files:**
- Test: `Pipeline/tests/test_aggregator_metadata.py`
- Modify: `Pipeline/src/tftmac_pipeline/run_aggregator.py`

- [ ] **Step 1: Write the failing test**

```python
# Pipeline/tests/test_aggregator_metadata.py
"""Bug #004 — aggregator must populate top-level metadata fields."""
import json
from pathlib import Path
from tftmac_pipeline.run_aggregator import build_tier_list_payload

def test_payload_has_updated_at_iso8601():
    payload = build_tier_list_payload(matches=[], region="VN2", patch="16.8")
    assert "updated_at" in payload
    # ISO 8601 with timezone, e.g. "2026-04-26T17:42:00+00:00"
    assert "T" in payload["updated_at"]
    assert payload["updated_at"].endswith("+00:00") or payload["updated_at"].endswith("Z")

def test_payload_has_match_count_matching_input():
    fake_matches = [{"info": {"participants": []}} for _ in range(42)]
    payload = build_tier_list_payload(matches=fake_matches, region="VN2", patch="16.8")
    assert payload["match_count"] == 42
    # Backwards-compat alias also populated
    assert payload["total_matches_sampled"] == 42
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd Pipeline && .venv/bin/pytest tests/test_aggregator_metadata.py -v
```

Expected: FAIL with `KeyError: 'updated_at'` or `AttributeError: build_tier_list_payload`.

- [ ] **Step 3: Implement fix**

In `Pipeline/src/tftmac_pipeline/run_aggregator.py`, locate the function that builds the final payload dict. Add at top of payload construction:

```python
from datetime import datetime, timezone
# ...
def build_tier_list_payload(matches, region, patch):
    payload = {
        "schema_version": "1.1.0",
        "region": region,
        "patch_version": patch,
        "updated_at": datetime.now(timezone.utc).isoformat(),
        "match_count": len(matches),
        "total_matches_sampled": len(matches),  # backward-compat alias
        "data_window_hours": 12,
        "elo_bracket": "CHALLENGER",
        "comps": [],  # populated below
    }
    # ... existing comp aggregation logic populates payload["comps"]
    return payload
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd Pipeline && .venv/bin/pytest tests/test_aggregator_metadata.py -v
```

Expected: PASS (2 tests).

- [ ] **Step 5: Run full pipeline test suite**

```bash
cd Pipeline && .venv/bin/pytest -v
```

Expected: all green (existing tests untouched).

- [ ] **Step 6: Commit**

```bash
git add Pipeline/tests/test_aggregator_metadata.py Pipeline/src/tftmac_pipeline/run_aggregator.py
git commit -m "fix(pipeline): populate updated_at + match_count metadata (bug #004)"
```

---

## Task 2: Tier threshold tuning (TDD)

**Files:**
- Modify: `Pipeline/src/tftmac_pipeline/tier_calculator.py`
- Test: existing `Pipeline/tests/test_tier_calculator.py`

- [ ] **Step 1: Write failing test**

Append to `Pipeline/tests/test_tier_calculator.py`:

```python
def test_s_tier_emitted_when_playrate_5pct_and_avg_4_0():
    """Bug #C1 — strict 10% threshold prevents any S-tier emission for 527-match samples."""
    from tftmac_pipeline.tier_calculator import classify_tier
    # play_rate 5.5%, avg_placement 3.95 → previously C, should now be S
    tier = classify_tier(play_rate=0.055, avg_placement=3.95, sample_size=200)
    assert tier == "S"

def test_a_tier_for_lower_playrate():
    from tftmac_pipeline.tier_calculator import classify_tier
    tier = classify_tier(play_rate=0.03, avg_placement=4.20, sample_size=150)
    assert tier == "A"
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd Pipeline && .venv/bin/pytest tests/test_tier_calculator.py::test_s_tier_emitted_when_playrate_5pct_and_avg_4_0 -v
```

Expected: FAIL — current code returns "C" or "B".

- [ ] **Step 3: Tune thresholds in tier_calculator.py**

Update `classify_tier`:

```python
def classify_tier(play_rate: float, avg_placement: float, sample_size: int) -> str:
    """
    S = top quality + meaningful presence (≥5% play, avg ≤4.0)
    A = solid (≥3% play, avg ≤4.3)
    B = playable (≥1.5% play, avg ≤4.6)
    C = niche / fringe
    """
    if sample_size < 50:
        return "C"  # too small to trust
    if play_rate >= 0.05 and avg_placement <= 4.0:
        return "S"
    if play_rate >= 0.03 and avg_placement <= 4.3:
        return "A"
    if play_rate >= 0.015 and avg_placement <= 4.6:
        return "B"
    return "C"
```

- [ ] **Step 4: Run all tier tests**

```bash
cd Pipeline && .venv/bin/pytest tests/test_tier_calculator.py -v
```

Expected: all pass (new + existing).

- [ ] **Step 5: Smoke test against live data**

```bash
cd Pipeline && .venv/bin/python -c "
import json
from tftmac_pipeline.tier_calculator import classify_tier
data = json.load(open('../data/tier-list.json'))
for c in data['comps']:
    new = classify_tier(c['play_rate'], c['avg_placement'], c['sample_size'])
    if new != c['tier']:
        print(f\"{c['name'][:40]:40s}  {c['tier']} → {new}  (play={c['play_rate']*100:.1f}% avg={c['avg_placement']:.2f})\")"
```

Expected: ≥1 line printed showing a B/C → S/A promotion. If 0 promotions, anh review thresholds before commit.

- [ ] **Step 6: Commit**

```bash
git add Pipeline/src/tftmac_pipeline/tier_calculator.py Pipeline/tests/test_tier_calculator.py
git commit -m "tune(pipeline): relax S-tier thresholds (5% play / 4.0 avg) for VN2 sample size"
```

---

## Task 3: ChampionAssetURL builder (TDD)

**Files:**
- Create: `App/TFTMac/Services/ChampionAssetURL.swift`
- Test: `App/TFTMacTests/ChampionAssetURLTests.swift`

- [ ] **Step 1: Write failing test**

```swift
// App/TFTMacTests/ChampionAssetURLTests.swift
import XCTest
@testable import TFTMac

final class ChampionAssetURLTests: XCTestCase {

    func test_buildsLowercaseSet17URL() {
        let url = ChampionAssetURL.squarePortrait(forChampionId: "TFT17_Aatrox")
        XCTAssertEqual(
            url?.absoluteString,
            "https://raw.communitydragon.org/latest/game/assets/characters/tft17_aatrox/hud/tft17_aatrox_square.tft_set17.png"
        )
    }

    func test_handlesCamelCaseChampionIds() {
        let url = ChampionAssetURL.squarePortrait(forChampionId: "TFT17_KaiSa")
        XCTAssertEqual(
            url?.absoluteString,
            "https://raw.communitydragon.org/latest/game/assets/characters/tft17_kaisa/hud/tft17_kaisa_square.tft_set17.png"
        )
    }

    func test_returnsNilForBlankId() {
        XCTAssertNil(ChampionAssetURL.squarePortrait(forChampionId: ""))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild test -project App/TFTMac.xcodeproj -scheme TFTMac -destination 'platform=macOS' -only-testing:TFTMacTests/ChampionAssetURLTests 2>&1 | tail -20
```

Expected: FAIL — `ChampionAssetURL` undefined.

- [ ] **Step 3: Implement (and confirm URL pattern from Task 0)**

```swift
// App/TFTMac/Services/ChampionAssetURL.swift
import Foundation

/// Builds CommunityDragon CDN URLs for Set 17 champion assets.
///
/// Pattern verified Task 0 (research/communitydragon-set17.md):
/// `https://raw.communitydragon.org/latest/game/assets/characters/{lower_id}/hud/{lower_id}_square.tft_set17.png`
///
/// IDs are lowercased; embedded camelCase (e.g. `KaiSa`) flattens to `kaisa`.
enum ChampionAssetURL {
    private static let base = "https://raw.communitydragon.org/latest/game/assets/characters"

    static func squarePortrait(forChampionId id: String) -> URL? {
        guard !id.isEmpty else { return nil }
        let lower = id.lowercased()
        return URL(string: "\(base)/\(lower)/hud/\(lower)_square.tft_set17.png")
    }
}
```

- [ ] **Step 4: Register file in Xcode project**

Use Ruby xcodeproj gem (per memory: agent-created .swift don't auto-register; Python pbxproj broken for objectVersion=77):

```bash
ruby -e "
require 'xcodeproj'
proj = Xcodeproj::Project.open('App/TFTMac.xcodeproj')
target = proj.targets.find { |t| t.name == 'TFTMac' }
group = proj.main_group.find_subpath('TFTMac/Services', true)
file = group.new_file('App/TFTMac/Services/ChampionAssetURL.swift')
target.add_file_references([file])
test_target = proj.targets.find { |t| t.name == 'TFTMacTests' }
test_group = proj.main_group.find_subpath('TFTMacTests', true)
test_file = test_group.new_file('App/TFTMacTests/ChampionAssetURLTests.swift')
test_target.add_file_references([test_file])
proj.save
puts 'Registered'
"
```

- [ ] **Step 5: Run test to verify it passes**

```bash
xcodebuild test -project App/TFTMac.xcodeproj -scheme TFTMac -destination 'platform=macOS' -only-testing:TFTMacTests/ChampionAssetURLTests 2>&1 | tail -20
```

Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add App/TFTMac/Services/ChampionAssetURL.swift App/TFTMacTests/ChampionAssetURLTests.swift App/TFTMac.xcodeproj
git commit -m "feat(app): ChampionAssetURL builder for CommunityDragon CDN"
```

---

## Task 4: AssetCache service (TDD)

**Files:**
- Create: `App/TFTMac/Services/AssetCache.swift`
- Test: `App/TFTMacTests/AssetCacheTests.swift`

- [ ] **Step 1: Write failing test**

```swift
// App/TFTMacTests/AssetCacheTests.swift
import XCTest
@testable import TFTMac

final class AssetCacheTests: XCTestCase {

    func test_returnsNilForUnreachableURL() async throws {
        let cache = AssetCache(directory: FileManager.default.temporaryDirectory.appendingPathComponent("ac-test-\(UUID())"))
        let url = URL(string: "https://raw.communitydragon.org/latest/game/assets/characters/tft17_doesnotexist/hud/tft17_doesnotexist_square.tex.png")!
        let data = try await cache.data(for: url)
        XCTAssertNil(data)
    }

    func test_diskCachePersistsAcrossInstances() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ac-test-\(UUID())")
        let url = URL(string: "https://raw.communitydragon.org/latest/game/assets/characters/tft17_aatrox/hud/tft17_aatrox_square.tex.png")!

        let first = AssetCache(directory: dir)
        let firstData = try await first.data(for: url)
        XCTAssertNotNil(firstData, "expected fetch to succeed (network test — skip if offline)")

        let second = AssetCache(directory: dir)
        let secondData = try await second.data(for: url)
        XCTAssertEqual(firstData?.count, secondData?.count)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild test -project App/TFTMac.xcodeproj -scheme TFTMac -destination 'platform=macOS' -only-testing:TFTMacTests/AssetCacheTests 2>&1 | tail -20
```

Expected: FAIL — `AssetCache` undefined.

- [ ] **Step 3: Implement**

```swift
// App/TFTMac/Services/AssetCache.swift
import Foundation
import os

/// On-disk asset cache backed by URLSession.
///
/// Strategy: SHA-256 of URL → filename in `directory`. Disk hit returns immediately;
/// miss triggers fetch + persist. 30-day TTL via file mtime check. 50MB ceiling
/// enforced lazily on each write (LRU eviction by mtime).
///
/// Returns nil on 4xx/5xx/timeout — callers fall back to placeholder UI.
final class AssetCache {
    static let shared = AssetCache(
        directory: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("io.psychomafia.tfthellelo.assets")
    )

    private let directory: URL
    private let session: URLSession
    private let logger = Logger(subsystem: "io.psychomafia.tfthellelo", category: "AssetCache")
    private let ttl: TimeInterval = 30 * 24 * 3600
    private let maxBytes: Int = 50 * 1024 * 1024

    init(directory: URL, session: URLSession = .shared) {
        self.directory = directory
        self.session = session
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func data(for url: URL) async throws -> Data? {
        let path = cachePath(for: url)
        if let cached = readFromDisk(path: path) { return cached }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                logger.notice("asset miss \(url.absoluteString, privacy: .public): non-200")
                return nil
            }
            try? data.write(to: path)
            evictIfNeeded()
            return data
        } catch {
            logger.notice("asset fetch failed \(url.absoluteString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func cachePath(for url: URL) -> URL {
        let hash = url.absoluteString.data(using: .utf8)!.sha256Hex()
        return directory.appendingPathComponent(hash)
    }

    private func readFromDisk(path: URL) -> Data? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path.path),
              let mtime = attrs[.modificationDate] as? Date,
              Date().timeIntervalSince(mtime) < ttl else {
            return nil
        }
        return try? Data(contentsOf: path)
    }

    private func evictIfNeeded() {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
        ) else { return }
        var totalBytes = 0
        var withMeta: [(URL, Int, Date)] = []
        for u in entries {
            let v = try? u.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let size = v?.fileSize ?? 0
            let mtime = v?.contentModificationDate ?? .distantPast
            totalBytes += size
            withMeta.append((u, size, mtime))
        }
        guard totalBytes > maxBytes else { return }
        // LRU eviction
        let sorted = withMeta.sorted { $0.2 < $1.2 }
        var bytes = totalBytes
        for (u, size, _) in sorted where bytes > maxBytes {
            try? FileManager.default.removeItem(at: u)
            bytes -= size
        }
    }
}

import CryptoKit
private extension Data {
    func sha256Hex() -> String {
        SHA256.hash(data: self).map { String(format: "%02x", $0) }.joined()
    }
}
```

- [ ] **Step 4: Register in Xcode**

```bash
ruby -e "
require 'xcodeproj'
proj = Xcodeproj::Project.open('App/TFTMac.xcodeproj')
target = proj.targets.find { |t| t.name == 'TFTMac' }
group = proj.main_group.find_subpath('TFTMac/Services', true)
file = group.new_file('App/TFTMac/Services/AssetCache.swift')
target.add_file_references([file])
test_target = proj.targets.find { |t| t.name == 'TFTMacTests' }
test_group = proj.main_group.find_subpath('TFTMacTests', true)
test_file = test_group.new_file('App/TFTMacTests/AssetCacheTests.swift')
test_target.add_file_references([test_file])
proj.save
"
```

- [ ] **Step 5: Run tests**

```bash
xcodebuild test -project App/TFTMac.xcodeproj -scheme TFTMac -destination 'platform=macOS' -only-testing:TFTMacTests/AssetCacheTests 2>&1 | tail -20
```

Expected: 2 PASS (network-dependent test will skip if offline; mark `XCTSkip` if executor is offline).

- [ ] **Step 6: Commit**

```bash
git add App/TFTMac/Services/AssetCache.swift App/TFTMacTests/AssetCacheTests.swift App/TFTMac.xcodeproj
git commit -m "feat(app): AssetCache service with disk persistence + LRU eviction"
```

---

## Task 5: Set 17 champion catalog from JSON (TDD + data file)

**Files:**
- Create: `App/TFTMac/Resources/set17-champions.json`
- Modify: `App/TFTMac/Generated/ChampionCatalog.swift`
- Test: `App/TFTMacTests/ChampionCatalogDataDrivenTests.swift`

- [ ] **Step 1: Generate set17-champions.json from live tier-list**

```bash
jq '[.comps[].champions[].id] | unique | sort | map({id: ., displayName: (. | sub("^TFT17_"; ""))})' \
  data/tier-list.json > App/TFTMac/Resources/set17-champions.json
```

Manually correct any displayName quirks (e.g. `KaiSa` → `Kai'Sa`, `Aurelionsol` → `Aurelion Sol`) by editing the JSON. Expected ~50-60 entries.

- [ ] **Step 2: Write failing test**

```swift
// App/TFTMacTests/ChampionCatalogDataDrivenTests.swift
import XCTest
@testable import TFTMac

final class ChampionCatalogDataDrivenTests: XCTestCase {

    func test_loadsAllChampionsFromBundledJSON() {
        XCTAssertGreaterThan(ChampionCatalog.entries.count, 40,
            "expected ~50+ Set 17 champion entries from set17-champions.json")
    }

    func test_lookupsCommonChampions() {
        XCTAssertEqual(ChampionCatalog.displayName(forId: "TFT17_Aatrox"), "Aatrox")
        XCTAssertEqual(ChampionCatalog.displayName(forId: "TFT17_Viktor"), "Viktor")
    }

    func test_fallsBackToRawIdWhenUnknown() {
        XCTAssertEqual(ChampionCatalog.displayName(forId: "TFT17_NewChamp"), "TFT17_NewChamp")
    }
}
```

- [ ] **Step 3: Run test, observe current behavior**

```bash
xcodebuild test -project App/TFTMac.xcodeproj -scheme TFTMac -destination 'platform=macOS' -only-testing:TFTMacTests/ChampionCatalogDataDrivenTests 2>&1 | tail -20
```

Expected: `test_loadsAllChampionsFromBundledJSON` FAILS — only 15 hand-coded entries.

- [ ] **Step 4: Refactor ChampionCatalog.swift**

Replace hand-coded dict with bundled JSON load:

```swift
// App/TFTMac/Generated/ChampionCatalog.swift
import Foundation
import os

/// Static lookup from champion ID to display metadata.
///
/// Loaded once at app start from `Resources/set17-champions.json` (bundled).
/// Source of truth: derived from data/tier-list.json champion IDs + manual
/// displayName corrections for camelCase quirks (KaiSa → Kai'Sa).
///
/// Fallback: unknown IDs return the raw ID string — UI degrades gracefully.
enum ChampionCatalog {

    struct Entry: Decodable {
        let id: String
        let displayName: String
    }

    static let entries: [String: Entry] = loadFromBundle()

    static func displayName(forId id: String) -> String {
        entries[id]?.displayName ?? id
    }

    private static func loadFromBundle() -> [String: Entry] {
        let logger = Logger(subsystem: "io.psychomafia.tfthellelo", category: "ChampionCatalog")
        guard let url = Bundle.main.url(forResource: "set17-champions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let arr = try? JSONDecoder().decode([Entry].self, from: data) else {
            logger.error("set17-champions.json missing or malformed — falling back to empty catalog")
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: arr.map { ($0.id, $0) })
    }
}
```

- [ ] **Step 5: Register JSON in Xcode bundle**

```bash
ruby -e "
require 'xcodeproj'
proj = Xcodeproj::Project.open('App/TFTMac.xcodeproj')
target = proj.targets.find { |t| t.name == 'TFTMac' }
group = proj.main_group.find_subpath('TFTMac/Resources', true)
file = group.new_file('App/TFTMac/Resources/set17-champions.json')
target.add_resources([file])
proj.save
"
```

- [ ] **Step 6: Run tests**

```bash
xcodebuild test -project App/TFTMac.xcodeproj -scheme TFTMac -destination 'platform=macOS' -only-testing:TFTMacTests/ChampionCatalogDataDrivenTests 2>&1 | tail -20
```

Expected: 3 PASS.

- [ ] **Step 7: Run full app test suite (regression check)**

```bash
xcodebuild test -project App/TFTMac.xcodeproj -scheme TFTMac -destination 'platform=macOS' 2>&1 | tail -30
```

Expected: all green.

- [ ] **Step 8: Commit**

```bash
git add App/TFTMac/Resources/set17-champions.json App/TFTMac/Generated/ChampionCatalog.swift App/TFTMacTests/ChampionCatalogDataDrivenTests.swift App/TFTMac.xcodeproj
git commit -m "feat(app): data-driven Set 17 champion catalog (~60 entries)"
```

---

## Task 6: ChampionPortrait async load (TDD)

**Files:**
- Modify: `App/TFTMac/Views/ChampionPortrait.swift`
- Test: existing `App/TFTMacTests/CompCardV2Tests.swift` (assert no crash on async path)

- [ ] **Step 1: Read current ChampionPortrait.swift**

```bash
cat App/TFTMac/Views/ChampionPortrait.swift
```

- [ ] **Step 2: Replace placeholder with AsyncImage-style load**

```swift
// App/TFTMac/Views/ChampionPortrait.swift
import SwiftUI

/// Wave 5c v2 portrait — Phase 1 upgrade: real CommunityDragon artwork via
/// `AssetCache`, falls back to placeholder circle on miss/offline.
///
/// 40px diameter, tier-color border ring, optional star overlay (1/2/3 stars).
struct ChampionPortrait: View {
    let champion: Champion
    let tierColor: Color

    @State private var image: NSImage?

    private var displayName: String { ChampionCatalog.displayName(forId: champion.id) }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                if let img = image {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    placeholder
                }
                StarLevelIndicator(stars: starsFor(cost: champion.cost))
                    .offset(y: 14)
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            .overlay(Circle().stroke(tierColor, lineWidth: 2))

            Text(displayName)
                .font(Theme.Fonts.captionSmall)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: 48)
        }
        .task {
            guard image == nil,
                  let url = ChampionAssetURL.squarePortrait(forChampionId: champion.id),
                  let data = try? await AssetCache.shared.data(for: url),
                  let img = NSImage(data: data) else { return }
            self.image = img
        }
    }

    private var placeholder: some View {
        ZStack {
            Circle().fill(costColor(champion.cost))
            Image(systemName: "person.fill")
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private func costColor(_ cost: Int) -> Color {
        switch cost {
        case 1: return .gray
        case 2: return .green
        case 3: return .blue
        case 4: return .purple
        case 5: return Theme.Colors.accentGold
        default: return .black
        }
    }

    private func starsFor(cost: Int) -> Int {
        // Most carries appear at 2-star in winning comps; placeholder until
        // Phase 3 (carousel/star aggregation) feeds real values.
        cost >= 4 ? 1 : 2
    }
}
```

- [ ] **Step 3: Run existing CompCard tests (regression)**

```bash
xcodebuild test -project App/TFTMac.xcodeproj -scheme TFTMac -destination 'platform=macOS' -only-testing:TFTMacTests/CompCardV2Tests 2>&1 | tail -20
```

Expected: all PASS (placeholder still renders synchronously; async load is best-effort).

- [ ] **Step 4: Build app + manual smoke**

```bash
xcodebuild build -project App/TFTMac.xcodeproj -scheme TFTMac -destination 'platform=macOS' 2>&1 | tail -5
open App/build/Debug/TFTMac.app
```

Then anh: Cmd+Shift+T to open popover, scroll comps, verify champion icons load (network required first run). Second open should hit disk cache.

- [ ] **Step 5: Commit**

```bash
git add App/TFTMac/Views/ChampionPortrait.swift
git commit -m "feat(app): ChampionPortrait loads real Set 17 art from CommunityDragon"
```

---

## Task 7: Phase Completion Protocol

- [ ] **Step 1: Update docs/system-architecture.md**

Add note: AssetCache + ChampionAssetURL added to Services layer; Generated catalog now data-driven.

- [ ] **Step 2: Create docs/asset-pipeline-architecture.md**

Mermaid diagram showing: Champion ID → ChampionAssetURL → AssetCache → URLSession → CommunityDragon CDN → disk cache → SwiftUI view.

- [ ] **Step 3: Append to docs/project-changelog.md**

```markdown
## [phase-01-champion-portraits] — 2026-04-26

### Added
- AssetCache service (URLSession + 30-day disk cache, 50MB LRU eviction).
- ChampionAssetURL builder for CommunityDragon Set 17 CDN.
- Bundled set17-champions.json (~60 Set 17 IDs, replaces 15 hand-coded entries).

### Changed
- ChampionPortrait renders real artwork (was: placeholder circles).
- Tier thresholds: S = ≥5% play / ≤4.0 avg (was: 10% / 4.0). At least 1 S-tier emitted on VN2 dataset.

### Fixed
- Bug #004: aggregator populates `updated_at` + `match_count` (was: missing top-level).

### Architecture impact
- New Services layer member (AssetCache singleton). Disk cache directory: ~/Library/Caches/io.psychomafia.tfthellelo.assets.
```

- [ ] **Step 4: Append to docs/bugs-log.md**

```markdown
### Bug #004 — Aggregator missing top-level metadata
- Status: ✅ Fixed (Phase 1 Task 1)
- Phase: phase-01-champion-portraits
- Symptom: tier-list.json missing `updated_at`, `match_count`; HeaderBar showed "—" for "X min ago".
- Root cause: `build_tier_list_payload` in run_aggregator.py only populated `comps`, forgot top-level fields.
- Fix: explicit dict construction with `datetime.now(timezone.utc).isoformat()` + `len(matches)`.
- Lesson: golden fixture test must assert ALL top-level keys, not just structural shape.
```

- [ ] **Step 5: Verify changelog incremented**

```bash
git diff HEAD~1 docs/project-changelog.md | grep -c "^+## "
```

Expected: ≥1.

- [ ] **Step 6: Commit docs**

```bash
git add docs/
git commit -m "docs(phase-01): champion portraits + asset pipeline + bugs log"
```

- [ ] **Step 7: Push branch**

```bash
git push origin feat/v0.1-implementation
```

---

## Success Criteria

- ✅ All 7 tasks committed.
- ✅ Manual gate passed: anh sees real Aatrox/Viktor/Illaoi portraits in popover; ≥1 S-tier comp visible.
- ✅ All tests green (Pipeline pytest + Xcode test suite).
- ✅ Bundle size <8MB (assets fetched lazily, not bundled).
- ✅ Bug #004 closed (header shows real "X min ago" timestamp).

## Risks

- **CommunityDragon URL drift** — if `.tex.png` extension changes, every portrait 404s silently (placeholder fallback). Mitigation: Task 0 manual probe locks current URL; future Phase 2 may add a `RemoteFetcher`-style cache schema bump trigger.
- **First-launch network blast** — 60 champions × ~50KB = ~3MB on first popover open. Mitigation: AsyncImage streams progressively, placeholder shows immediately.
- **Tier threshold over-relaxation** — too many S-tier comps dilutes signal. Mitigation: Task 2 Step 5 prints proposed promotions for anh review before commit.

## Next Phase

→ [Phase 2 — Trait-centric comp identification](phase-02-trait-centric-comp.md)
