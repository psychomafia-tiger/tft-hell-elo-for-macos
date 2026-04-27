# TFTactics-style Champion Portrait Redesign

Date: 2026-04-27
Branch: feat/v0.1-implementation
Approved approach: 3 (pixel-perfect overlay + colored-square fallback)

---

## User goal — plain language

User mở app TFT Hell Elo bên cạnh game đang chạy, glance (liếc nhanh) vào 1 comp card và muốn đọc được:
1. **Champion này có giá bao nhiêu** — nhìn vòng tròn màu quanh portrait là biết (xám=1, xanh lá=2, xanh dương=3, tím=4, vàng=5)
2. **Carry build (chủ lực dùng) item gì** — 3 ô vuông nhỏ overlay (đè lên) đáy portrait carry, không phải đọc text "Illaoi → Gargoyle Stoneplate 49%"
3. **Carry có 3-star (3 sao) không** — pip ⭐⭐⭐ phía trên portrait

**Before** (hiện tại): user nhìn portrait → không biết cost, phải đọc tên + đoán; muốn biết item phải scan text row riêng bên dưới.
**After**: user glance 0.5 giây nhận diện cost + items + stars cùng lúc — match (khớp) experience (trải nghiệm) của TFTactics web mà gamer Việt đã quen.

**Concrete reading time** (thời gian đọc cụ thể): TFTactics đọc 1 carry slot ~0.3-0.5s. Current app text row ~1.5-2s (phải parse "Illaoi → Gargoyle Stoneplate 49%" + map item name → item identity). Target: rút thời gian xuống bằng TFTactics.

---

## Architecture

3 file mới, 1 file modified, 1 file removed:

| File | Status | Purpose |
|---|---|---|
| `App/TFTMac/Resources/set17-items.json` | NEW (~50 entries) | itemId → (displayName, iconToken, itemClass) |
| `App/TFTMac/Generated/ItemAssetURL.swift` | NEW | CDragon (CommunityDragon CDN) item icon URL builder |
| `App/TFTMac/Views/ItemBadge.swift` | NEW | 12pt async-loading view + colored-square fallback |
| `App/TFTMac/Views/ChampionPortrait.swift` | MODIFIED | cost-color border (luôn vẽ), 3-item overlay trên carry |
| `App/TFTMac/Views/CompCardItemsRow.swift` | REMOVED | thay bằng overlay; xóa luôn callsite trong `CompCard.body` |

Pattern (mẫu) tương tự `set17-traits.json` + `TraitCatalog` + `TraitAssetURL` đã build trong Phase 2 — proven path (đường đi đã verify), risk thấp.

---

## Visual layout (ASCII)

```
  ⭐⭐⭐               ← StarLevelIndicator (giữ nguyên position từ Phase 2)
 ┌──────┐
 │ FACE │            ← portrait image (40pt) + costColor border ring 2pt (always — luôn vẽ)
 │ ┌──┐ │            ← 3 items overlay bottom 30% portrait, ZStack alignment .bottom
 │ │II│I│            ← spacing 1pt; total width 38pt < 40pt portrait width
 └──────┘
  Jinx               ← Text(displayName) 9pt
```

**Sizes**: portrait 40×40pt (giữ nguyên), border 2pt stroke, ItemBadge 12×12pt × 3 = 38pt total in HStack(spacing:1).

**Conditional render**: items overlay chỉ show khi `champion.isCarry && !champion.items.isEmpty`. Non-carry chỉ thấy portrait + cost border + name.

---

## Data flow

```
Pipeline ItemBuild{id, agreement} (existing — không đổi schema)
  ↓
Comp.champions[].items: [ItemBuild]  (existing)
  ↓
ChampionPortrait(champion:) sees champion.items
  ↓
ZStack {
    portraitFill (existing)
    if champion.isCarry && !items.isEmpty {
        VStack { Spacer(); HStack(spacing:1) { ForEach(items.prefix(3)) { ItemBadge(itemId: $0.id) } } }
    }
}
  ↓
ItemBadge.task →  ItemAssetURL.icon(for: itemId)  →  AssetCache.shared.data(for:)
  ↓ success: NSImage rendered
  ↓ failure (404 / timeout / unknown id): colored-square fallback
              tint = ItemCatalog.itemClass(itemId).color
              + "?" glyph 6pt nếu unknown id
```

**No schema bump** — `ItemBuild` đã tồn tại từ Phase 1, đang được pipeline emit chuẩn.

---

## CDragon URL probe (Task 0 — BEFORE coding)

CommunityDragon item icon path chưa verify cho Set 17. 2 candidate (ứng viên):

- **Pattern A** (guess): `https://raw.communitydragon.org/latest/game/assets/maps/particles/tft/item_icons/standard/<itemId_lower>.png`
- **Pattern B** (proven path từ trait): từ `https://raw.communitydragon.org/latest/cdragon/tft/en_us.json` → `data['items']` → đọc real `iconPath` per item → derive URL exact

**Strategy**: probe Pattern A bằng curl 2-3 known itemIds (`TFT_Item_GargoyleStoneplate`, `TFT_Item_StatikkShiv`, `TFT_Item_JeweledGauntlet`). Nếu fail (404) → default sang Pattern B.

**Concrete example**: TraitAssetURL Phase 2 đã verify pattern `trait_icon_17_<token>.tft_set17.png` (KHÔNG phải `.png` thuần) qua probe. Items có thể có suffix tương tự. Pattern B ăn chắc 100% vì đọc direct từ CDragon metadata.

---

## ItemClass enum + tint colors

```swift
enum ItemClass: String, Codable {
    case tank, ad, ap, utility, unknown
}
```

Mapping per known item — manual hardcode trong `set17-items.json` build script (~50 items, ~10 phút manual review):

| Class | Examples | Tint color |
|---|---|---|
| tank | Gargoyle Stoneplate, Bramble Vest, Warmog's | `.blue` |
| ad | Infinity Edge, Last Whisper, Bloodthirster | `.red` |
| ap | Jeweled Gauntlet, Rabadon's, Archangel | `.purple` |
| utility | Statikk Shiv, Hand of Justice, Shojin | `.green` |
| unknown | (catalog miss) | `.gray` |

**Why class color, not random**: gamer reading patterns (mẫu đọc) — TFT players quen identify item type theo color trong game UI. Tank items thường blue/cyan border in-game; AP items purple. Mirror (phản chiếu) convention này → fallback dễ recognize ngay cả khi không có icon thật.

---

## Error handling

| Case | Behavior |
|---|---|
| URL miss (404 / timeout) | ItemBadge → class-tinted square + "?" 6pt glyph |
| ItemId unknown (không có trong ItemCatalog) | Square `.gray` + "?" |
| Cost outside 1-5 (Riot edge cases: 7, 10) | Border `.black` (existing fallback) |
| Empty items + non-carry | No overlay (existing behavior) |
| Items > 3 | Take first 3 (pipeline already filters top-3 ≥0.40 agreement) |
| Items[].id missing | Skip slot (defensive) |

---

## Testing

| Suite | Coverage |
|---|---|
| `ItemAssetURLTests` (NEW) | URL builder per known + unknown item |
| `ItemBadgeTests` (NEW) | Render success path + 4 fallback paths (404, unknown id, network fail, empty id) |
| `ChampionPortraitTests` (extend) | Cost border color matches cost (cost 1-5 + edge); carry shows ≤3 items; non-carry shows none |
| `set17ItemsCatalogTests` (NEW) | JSON loads, ~50 entries, no duplicate keys, all itemClass values valid |
| Manual UI smoke | Anh relaunch app + visual compare vs TFTactics screenshot |

**Skip per `feedback_xcodebuild_test_pops_app.md`**: full `xcodebuild test` pops app window. Use `-only-testing:TFTMacTests/{ItemAssetURLTests,ItemBadgeTests,ChampionPortraitTests}` per task.

---

## Migration / rollback

- `CompCardItemsRow.swift` deleted — internal view, không có external reference (đã grep verify).
- Card height giảm ~24pt (item row removed). Density tighter (gọn hơn) → list view fit nhiều comps cùng screen — UX win.
- Schema không bump — full backward-compat (tương thích lùi). Nếu cần rollback: revert commit, fixture/cron data nguyên không touch.

---

## Implementation phases (high-level — chi tiết → writing-plans)

1. **Probe CDragon item URL** (Task 0, ~10 min) — lock URL pattern trước
2. **Generate `set17-items.json`** (~30 min) — script + manual itemClass review
3. **`ItemAssetURL.swift`** (~10 min) — URL builder
4. **`ItemBadge.swift`** (~30 min) — view + tests
5. **`ChampionPortrait.swift` modify** (~20 min) — wire border + overlay
6. **Remove `CompCardItemsRow`** + callsite (~5 min)
7. **Tests + manual smoke** (~20 min)

Total estimate: **~2 hours**.

---

## Out of scope (Phase 3+ defer)

- Item agreement % display (text "49%" mất khi remove text row — giả định gamer dùng portrait visual đủ rồi, không cần precision metric on-portrait)
- Hover tooltip showing item name + agreement (UX bonus, defer)
- Item upgrade indicators (radiant items, support items distinguished by glow) — TFTactics có; defer
- Border color edge case for cost 6/7/10 (Riot rarity high values) — currently → `.black` fallback (acceptable)

---

## Cross-references

- Approval thread: this conversation (anh approved 2026-04-27)
- Pattern reference: Phase 2 TraitCatalog/TraitAssetURL/TraitChip implementation (commits `299ac6d`, `268be11`)
- Related bugs: #007 (cost: 0 in trait-bucket emission — fixed in `e20df94`); none for items
