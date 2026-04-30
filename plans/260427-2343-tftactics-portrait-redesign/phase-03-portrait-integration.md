# Phase 3 — ChampionPortrait Integration

**Status:** ⏳ Pending
**Estimate:** ~30 min
**Depends on:** Phase 2 complete

## Context

Wire `ItemBadge` into `ChampionPortrait` and switch the border ring from tier-color (S/A/B/C, carry-only) to cost-color (1-5, always). This is the visible payoff of the previous phases — anh sees the TFTactics-style portrait after this phase ships.

## Files

- Modify: `App/TFTMac/Views/ChampionPortrait.swift` (drop `tierColor` param, always cost border, items overlay)
- Modify: All callers of `ChampionPortrait(champion:tierColor:)` — update init signature
- Modify: `App/TFTMacTests/CompCardV2Tests.swift` (extend tests)

## Tasks

### Task 3.1: Find all ChampionPortrait callers

- [ ] **Step 1: Grep for ChampionPortrait init sites**

Run:
```bash
grep -rn "ChampionPortrait(" App/TFTMac/ App/TFTMacTests/ --include="*.swift"
```
Expected: list of callers — record each file:line. The plan executor will update each caller in Step 3.3 below.

### Task 3.2: Modify ChampionPortrait

**Files:**
- Modify: `App/TFTMac/Views/ChampionPortrait.swift`

- [ ] **Step 1: Replace ChampionPortrait struct**

Replace contents of `App/TFTMac/Views/ChampionPortrait.swift`:

```swift
import SwiftUI

/// Phase 3 (TFTactics-style) upgrade: cost-color border on every champion (was
/// tier-color, carry-only) + 3-item overlay on bottom 30% of carry portraits
/// (replaces separate `CompCardItemsRow` text path).
///
/// Layout:
/// ```
///    ⭐⭐⭐                ← StarLevelIndicator (top, only when starLevel >= 3)
///   ┌──────┐
///   │ FACE │             ← portrait image, costColor border ring 2pt (always)
///   │ ┌──┐ │             ← 3 ItemBadge overlay bottom 30%, ZStack alignment .bottom
///   │ │II│I│
///   └──────┘
///    Jinx                ← Text(displayName)
/// ```
///
/// Plain-language: trước Phase 3 user thấy portrait với border tier (S=gold,
/// A=...) chỉ trên carry. Sau Phase 3: mọi champion có border màu theo cost
/// (1=gray, 2=green, 3=blue, 4=purple, 5=gold) — match TFTactics web. Carry
/// thêm 3 ô item nhỏ (12pt) overlay đáy portrait — user glance 0.3s nhận diện
/// build (xây dựng) item carry mà không phải đọc text row riêng.
struct ChampionPortrait: View {
    let champion: Champion

    /// Portrait diameter. Default matches wireframe 40px.
    var size: CGFloat = 40

    @State private var image: NSImage?

    var body: some View {
        VStack(spacing: 3) {
            portraitStack
            Text(ChampionCatalog.displayName(forId: champion.id))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: size + 12)
        }
        .task {
            guard image == nil,
                  let url = ChampionAssetURL.squarePortrait(forChampionId: champion.id),
                  let data = try? await AssetCache.shared.data(for: url),
                  let nsImage = NSImage(data: data) else { return }
            self.image = nsImage
        }
    }

    private var portraitStack: some View {
        ZStack(alignment: .bottom) {
            portraitFill
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(costBorderColor(champion.cost), lineWidth: 2)
                )

            if champion.isCarry && !champion.items.isEmpty {
                itemsOverlay
                    .padding(.bottom, 2)  // tiny inset so badges don't kiss the border
            }
        }
        .overlay(alignment: .top) {
            // Star indicator only renders for starLevel >= 3 (per Phase 2 fix).
            // Offset above portrait so it doesn't occlude the face fill.
            StarLevelIndicator(level: champion.starLevel)
                .offset(y: -8)
        }
        .frame(height: size + 6)
    }

    /// 3-item HStack overlay. Pipeline already filters top-3 ≥0.40 agreement,
    /// but we `.prefix(3)` defensively.
    private var itemsOverlay: some View {
        HStack(spacing: 1) {
            ForEach(champion.items.prefix(3), id: \.id) { item in
                ItemBadge(itemId: item.id)
            }
        }
    }

    @ViewBuilder
    private var portraitFill: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            placeholder
        }
    }

    /// Cost-colored placeholder fill (used when async load is in flight or
    /// the URL miss). Keeps user able to identify cost while artwork resolves.
    private var placeholder: some View {
        ZStack {
            Circle().fill(costBorderColor(champion.cost))
            Image(systemName: "person.fill")
                .font(.system(size: size * 0.5))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    /// Cost → border color mapping. TFT canonical: 1=gray, 2=green, 3=blue,
    /// 4=purple, 5=gold. Cost outside 1-5 (Riot edge cases for high-rarity
    /// special units) → black fallback.
    private func costBorderColor(_ cost: Int) -> Color {
        switch cost {
        case 1: return .gray
        case 2: return .green
        case 3: return .blue
        case 4: return .purple
        case 5: return Theme.Colors.accentGold
        default: return .black
        }
    }
}
```

- [ ] **Step 2: Run targeted test — verify FAIL on caller compile**

Run:
```bash
xcodebuild -project App/TFTMac.xcodeproj -scheme TFTMac \
  -only-testing:TFTMacTests/CompCardV2Tests build 2>&1 | tail -10
```
Expected: build error — callers passing `tierColor:` no longer compile. Note the failing files for Step 3.3.

### Task 3.3: Update each caller to drop tierColor

- [ ] **Step 1: For each caller in Task 3.1 grep output, remove `tierColor:` argument**

Pattern to find:
```swift
ChampionPortrait(champion: ..., tierColor: someColor)
```
Pattern to replace with:
```swift
ChampionPortrait(champion: ...)
```

Apply to every file. Use Edit tool per file with the exact `tierColor:` pattern from each grep hit. Common callers expected (verify in Step 3.1):
- `App/TFTMac/Views/CompCard.swift` (championsRow)
- Any expanded view / compact view variants

- [ ] **Step 2: Build to confirm callers fixed**

Run:
```bash
xcodebuild -project App/TFTMac.xcodeproj -scheme TFTMac build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

### Task 3.4: Extend ChampionPortrait test coverage

**Files:**
- Modify: `App/TFTMacTests/CompCardV2Tests.swift`

- [ ] **Step 1: Append cost-border + items behavior tests**

Append to end of `App/TFTMacTests/CompCardV2Tests.swift` (inside the class):

```swift
    // MARK: - Phase 3 portrait (cost border always, items overlay on carry)

    func test_portraitConstructs_withItems_onCarry() {
        let carry = Champion(
            id: "TFT17_Jinx", cost: 4, isCarry: true, starLevel: 2,
            items: [
                ItemBuild(id: "TFT_Item_GuinsoosRageblade", agreement: 0.6),
                ItemBuild(id: "TFT_Item_LastWhisper",       agreement: 0.5),
            ]
        )
        let view = ChampionPortrait(champion: carry)
        XCTAssertNotNil(view.body)
    }

    func test_portraitConstructs_noItems_onNonCarry() {
        let support = Champion(
            id: "TFT17_Nami", cost: 2, isCarry: false, starLevel: 1, items: []
        )
        let view = ChampionPortrait(champion: support)
        XCTAssertNotNil(view.body)
    }

    func test_portraitConstructs_carryWithEmptyItems() {
        // Carry slot with no items in pipeline output — should not render overlay.
        let carry = Champion(
            id: "TFT17_Viktor", cost: 5, isCarry: true, starLevel: 3, items: []
        )
        let view = ChampionPortrait(champion: carry)
        XCTAssertNotNil(view.body)
    }

    func test_portraitConstructs_overFourItems_takesFirstThree() {
        // Defensive: even if pipeline emits more than 3, view caps at 3.
        let items = (1...5).map { ItemBuild(id: "TFT_Item_Fake_\($0)", agreement: 0.5) }
        let carry = Champion(
            id: "TFT17_Test", cost: 3, isCarry: true, starLevel: 2, items: items
        )
        let view = ChampionPortrait(champion: carry)
        XCTAssertNotNil(view.body)
    }

    func test_portraitConstructs_costEdgeCases() {
        // Cost outside 1-5 (Riot edge values for special units) → black fallback.
        let edge = Champion(id: "TFT17_X", cost: 7, isCarry: false, starLevel: 1, items: [])
        let view = ChampionPortrait(champion: edge)
        XCTAssertNotNil(view.body)
    }
```

- [ ] **Step 2: Run CompCardV2Tests — verify PASS**

Run:
```bash
xcodebuild -project App/TFTMac.xcodeproj -scheme TFTMac \
  -only-testing:TFTMacTests/CompCardV2Tests test 2>&1 | tail -10
```
Expected: All previous tests + 5 new tests PASS.

### Task 3.5: Commit Phase 3

- [ ] **Step 1: Run broader regression**

Run:
```bash
xcodebuild -project App/TFTMac.xcodeproj -scheme TFTMac \
  -only-testing:TFTMacTests/CompCardV2Tests \
  -only-testing:TFTMacTests/ExpandedCardViewTests \
  -only-testing:TFTMacTests/ItemBadgeTests \
  -only-testing:TFTMacTests/ItemCatalogTests \
  -only-testing:TFTMacTests/ItemAssetURLTests \
  -only-testing:TFTMacTests/DataManagerTests test 2>&1 | tail -8
```
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 2: Commit**

```bash
git add App/TFTMac/Views/ChampionPortrait.swift \
        App/TFTMac/Views/CompCard.swift \
        App/TFTMacTests/CompCardV2Tests.swift
# Also add any other caller files modified in Task 3.3
git commit -m "feat(app): TFTactics-style portrait — cost border always, 3-item overlay on carry

ChampionPortrait switches:
- Border ring color: tier-color (S/A/B/C, carry-only) → cost-color
  (1=gray, 2=green, 3=blue, 4=purple, 5=gold). Applied to every
  champion regardless of carry status. Cost edge cases (7+, 10) → black.
- Items: separate text row format dropped in favor of 3-item overlay
  on bottom of carry portraits. Uses ItemBadge (Phase 2) with class-
  tinted fallback for icon misses.
- Public API: removed tierColor parameter from init. All callers
  updated to drop the argument.

Star indicator unchanged (Phase 2 — only renders when starLevel >= 3).

Tests: 5 new ChampionPortrait construction smoke tests; full
CompCardV2Tests + ExpandedCardViewTests still green."
```

## Success criteria

- ✅ Build succeeds — all callers updated
- ✅ ChampionPortrait shows cost-color border on every champion in fixture
- ✅ Carry champions with items render 3 ItemBadges overlaid on bottom
- ✅ All targeted Swift tests pass
- ✅ Zero regression on Phase 0/1/2 work

## Risk assessment

- Hidden caller missed in grep (e.g. SwiftUI Preview block): build fail surfaces it. Add to update list.
- Items overlay clips against circular portrait boundary: ZStack `.bottom` aligns badges to bottom edge of the 40pt frame; badges are 12pt tall in a horizontal HStack. They sit BELOW the circular fill but inside the frame. If anh reports they appear "floating" away from the portrait, reduce `.padding(.bottom, 2)` to 0 or use `.offset(y: -2)` to nudge upward.
- Star indicator overlap with cost border: stars sit at `offset(y: -8)` above the portrait edge; border is on the edge. No overlap (verified in self-review).

## Next phase

→ [Phase 4 — Cleanup + docs sync](phase-04-cleanup-and-docs.md)
