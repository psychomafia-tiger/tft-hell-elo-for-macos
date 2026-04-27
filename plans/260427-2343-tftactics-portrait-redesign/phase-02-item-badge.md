# Phase 2 — ItemBadge View (TDD)

**Status:** ⏳ Pending
**Estimate:** ~30 min
**Depends on:** Phase 1 complete

## Context

Self-contained 12×12pt async-loading view. Renders item icon from `ItemAssetURL` via `AssetCache` (existing service from Phase 1 portraits). Falls back to a class-tinted square (with "?" glyph for unknown IDs) when icon URL miss or itemId not in `ItemCatalog`.

Pattern mirrors `TraitChip.swift` async load (Phase 2 commit `268be11`) but smaller (12pt vs 16pt) and class-color fallback instead of text.

## Files

- Create: `App/TFTMac/Views/ItemBadge.swift`
- Test: `App/TFTMacTests/ItemBadgeTests.swift`

## Tasks

### Task 2.1: Write failing tests for ItemBadge

**Files:**
- Test: `App/TFTMacTests/ItemBadgeTests.swift`

- [ ] **Step 1: Write failing tests**

Write to `App/TFTMacTests/ItemBadgeTests.swift`:

```swift
import XCTest
import SwiftUI
@testable import TFTMac

final class ItemBadgeTests: XCTestCase {

    // MARK: - Tint color resolution (pure)

    func test_tintColor_tankClass() {
        XCTAssertEqual(ItemBadge.tintColor(for: .tank), Color.blue)
    }

    func test_tintColor_adClass() {
        XCTAssertEqual(ItemBadge.tintColor(for: .ad), Color.red)
    }

    func test_tintColor_apClass() {
        XCTAssertEqual(ItemBadge.tintColor(for: .ap), Color.purple)
    }

    func test_tintColor_utilityClass() {
        XCTAssertEqual(ItemBadge.tintColor(for: .utility), Color.green)
    }

    func test_tintColor_unknownClass() {
        XCTAssertEqual(ItemBadge.tintColor(for: .unknown), Color.gray)
    }

    // MARK: - View construction (compile-only smoke)

    func test_constructsForKnownItemId() {
        // Compile-only assertion: known item id should construct without crashing.
        let badge = ItemBadge(itemId: "TFT_Item_GargoyleStoneplate")
        XCTAssertNotNil(badge.body)
    }

    func test_constructsForUnknownItemId() {
        // Unknown id falls through to gray-square fallback path.
        let badge = ItemBadge(itemId: "TFT_Item_DoesNotExist_X")
        XCTAssertNotNil(badge.body)
    }

    func test_constructsForEmptyItemId() {
        let badge = ItemBadge(itemId: "")
        XCTAssertNotNil(badge.body)
    }
}
```

- [ ] **Step 2: Run test — verify FAIL (compile error)**

Run:
```bash
xcodebuild -project App/TFTMac.xcodeproj -scheme TFTMac \
  -only-testing:TFTMacTests/ItemBadgeTests test 2>&1 | tail -8
```
Expected: TEST FAILED — `Cannot find 'ItemBadge' in scope`.

### Task 2.2: Implement ItemBadge

**Files:**
- Create: `App/TFTMac/Views/ItemBadge.swift`

- [ ] **Step 1: Write implementation**

Write to `App/TFTMac/Views/ItemBadge.swift`:

```swift
import SwiftUI

/// 12×12pt async-loading badge for a single item slot on a carry champion.
///
/// Loading flow:
///   1. On `.task`, look up `iconToken` via `ItemCatalog`.
///   2. If token exists, build URL via `ItemAssetURL` and fetch via `AssetCache`.
///   3. If fetch succeeds → render NSImage clipped to a small rounded square.
///   4. If fetch fails OR token missing → render class-tinted square fallback.
///   5. For unknown itemIds (not in catalog) → fallback always wins, with a
///      "?" glyph 6pt to signal "data missing" rather than "art missing".
///
/// Fallback tint chosen by `ItemCatalog.itemClass(forId:)` so a tank item slot
/// reads "blue square" even before art arrives — preserves visual semantics
/// even on a fresh cache or CDN miss.
struct ItemBadge: View {

    let itemId: String

    /// Loaded NSImage, nil while loading or on miss.
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                fallback
            }
        }
        .frame(width: 12, height: 12)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .task {
            guard image == nil,
                  let token = ItemCatalog.iconToken(forId: itemId),
                  let url = ItemAssetURL.icon(forIconToken: token),
                  let data = try? await AssetCache.shared.data(for: url),
                  let nsImage = NSImage(data: data) else { return }
            self.image = nsImage
        }
    }

    /// Class-tinted square. Renders "?" glyph for items not in the catalog
    /// (signals "we don't know what this is" vs "art is loading / failed").
    private var fallback: some View {
        let cls = ItemCatalog.itemClass(forId: itemId)
        return ZStack {
            Self.tintColor(for: cls).opacity(0.85)
            if cls == .unknown {
                Text("?")
                    .font(.system(size: 6, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    /// Pure function — exposed `static` for tests.
    static func tintColor(for itemClass: ItemCatalog.ItemClass) -> Color {
        switch itemClass {
        case .tank:    return .blue
        case .ad:      return .red
        case .ap:      return .purple
        case .utility: return .green
        case .unknown: return .gray
        }
    }
}
```

- [ ] **Step 2: Add files to Xcode targets**

Run:
```bash
ruby -rxcodeproj -e "
proj = Xcodeproj::Project.open('App/TFTMac.xcodeproj')

target_app = proj.targets.find { |t| t.name == 'TFTMac' }
views_group = proj.main_group['App']['TFTMac']['Views']
file_ref = views_group.new_reference('ItemBadge.swift')
target_app.source_build_phase.add_file_reference(file_ref)

target_test = proj.targets.find { |t| t.name == 'TFTMacTests' }
tests_group = proj.main_group['App']['TFTMacTests']
test_ref = tests_group.new_reference('ItemBadgeTests.swift')
target_test.source_build_phase.add_file_reference(test_ref)

proj.save
puts 'Added ItemBadge.swift + ItemBadgeTests.swift'
"
```

- [ ] **Step 3: Run tests — verify PASS**

Run:
```bash
xcodebuild -project App/TFTMac.xcodeproj -scheme TFTMac \
  -only-testing:TFTMacTests/ItemBadgeTests test 2>&1 | tail -8
```
Expected: 8 tests passed.

### Task 2.3: Commit Phase 2

- [ ] **Step 1: Verify no broader regression**

Run:
```bash
xcodebuild -project App/TFTMac.xcodeproj -scheme TFTMac \
  -only-testing:TFTMacTests/ItemBadgeTests \
  -only-testing:TFTMacTests/ItemCatalogTests \
  -only-testing:TFTMacTests/ItemAssetURLTests \
  -only-testing:TFTMacTests/CompCardV2Tests test 2>&1 | tail -8
```
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 2: Commit**

```bash
git add App/TFTMac/Views/ItemBadge.swift \
        App/TFTMacTests/ItemBadgeTests.swift \
        App/TFTMac.xcodeproj/project.pbxproj
git commit -m "feat(app): ItemBadge view (12pt async icon + class-tinted fallback)

Self-contained 12x12pt SwiftUI view for a single item slot on a carry
portrait. Loads NSImage via AssetCache.shared + ItemAssetURL when
ItemCatalog has a token; otherwise renders class-tinted square (tank=
blue, ad=red, ap=purple, utility=green, unknown=gray) with '?' glyph
on unknown ids.

Tests: 8 (5 tintColor pure + 3 view construction smoke). Zero
regression on existing CompCard tests."
```

## Success criteria

- ✅ ItemBadgeTests 8 green
- ✅ Zero regression on CompCardV2Tests / ItemCatalogTests / ItemAssetURLTests

## Risk assessment

- AssetCache thread safety: existing actor-isolated singleton from Phase 1, no concern.
- View body re-render fetches: `.task` modifier guards via `image == nil` check (same pattern as ChampionPortrait Phase 1 commit `6605802`). Cheap.
- Color contrast on fallback square: 0.85 opacity sufficient against dark theme background. If anh reports unreadable in manual smoke, bump to 1.0 in Phase 4.

## Next phase

→ [Phase 3 — ChampionPortrait integration](phase-03-portrait-integration.md)
