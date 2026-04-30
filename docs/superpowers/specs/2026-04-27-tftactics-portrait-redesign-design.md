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

## CDragon URL pattern (verified 2026-04-27 self-review)

**Pattern locked**: derive URL from CDragon `en_us.json` icon path field.

Source-of-truth flow:
1. Fetch `https://raw.communitydragon.org/latest/cdragon/tft/en_us.json` (~24MB, 3565 items total — needs `User-Agent: Mozilla/5.0` to bypass 403 on default Python urllib).
2. For each item in `data['items']`: read `apiName` (e.g. `TFT_Item_GargoyleStoneplate`) and `icon` (e.g. `ASSETS/Maps/TFT/Icons/Items/Hexcore/TFT_Item_GargoyleStoneplate.TFT_Set13.tex`).
3. Convert icon path → URL:
   ```
   ASSETS/...    → game/assets/...
   .tex          → .png
   <lowercase entire path>
   ```
4. Final URL: `https://raw.communitydragon.org/latest/game/assets/maps/tft/icons/items/hexcore/tft_item_gargoylestoneplate.tft_set13.png` ← probe-verified 200 OK.

**Concrete example**: `TFT_Item_GargoyleStoneplate` icon path = `ASSETS/Maps/TFT/Icons/Items/Hexcore/TFT_Item_GargoyleStoneplate.TFT_Set13.tex` → URL `.../tft_item_gargoylestoneplate.tft_set13.png` → 200 OK with PNG bytes. Even though Set 13 is in the suffix, the item is reused in Set 17 — Riot's icon naming reflects when the texture was last refreshed, not the active set.

**Scope (số lượng items)**: Pipeline emits top-3 items per champion × 8 champions × 37 comps = up to 888 item slots, with dedup likely <100 unique itemIds. Bundle metadata for items present in current `data/tier-list.json` + buffer (e.g. all items with `apiName` matching `^TFT_Item_[A-Z]` excluding augment/anomaly/component prefixes). Estimated ~80-150 entries → JSON ~30-50KB.

**`iconToken` field**: derived from CDragon `icon` path during bundle generation — full lowercase relative path minus `.png` suffix (e.g. `tft_item_gargoylestoneplate.tft_set13`). `ItemAssetURL` builder concatenates: `BASE + path_prefix + iconToken + ".png"`.

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

- `CompCardItemsRow.swift` deleted — only callsite is `CompCard.swift:45` (verified via grep). Comments in `CompCardAnomaliesRow.swift:5,12` reference `CompCardItemsRow` for layout pattern — update comments post-removal (cosmetic, ~1 LOC).
- Tier-color border (S/A/B/C tint, applied to carry only) replaced by **cost-color border (always)**. Tier indicator visual signal not lost — tier badge already rendered as left-aligned circle ("A", "B" with colored fill) at top of each comp card — duplicate signal removed.
- Card height giảm ~24pt (item row removed). Density tighter (gọn hơn) → list view fit nhiều comps cùng screen — UX win.
- Schema không bump — full backward-compat (tương thích lùi). Nếu cần rollback: revert commit, fixture/cron data nguyên không touch.

## Performance budget (self-review note)

First-launch cold cache: 37 comps × 8 champions × (1 portrait + up to 3 items) = ~1184 fetches max. CDragon CDN p50 latency ~80-150ms per fetch; with `AssetCache` 2 parallel workers (URLSession default config) → cold launch ~30-60s to fully populate. UI degrades gracefully (placeholder shown until image arrives). After cold launch: cache hit rate >99% for steady-state (12h cron refresh changes <5% of comps).

`AssetCache` LRU 50MB ceiling: items ~3-5KB each × 100 items = ~400KB; portraits ~10-15KB × 59 = ~700KB. Total <1.5MB. No eviction risk for v0.1 scale.

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

## Self-review log (2026-04-27, before invoke writing-plans)

Holes identified + resolution:

| # | Hole | Resolution |
|---|---|---|
| 1 | CDragon item URL pattern unverified | Probed live — pattern locked: derive from `en_us.json[items][i].icon` field, lowercase + `.tex`→`.png` (200 OK on 2 known items). Spec section "CDragon URL pattern" updated with concrete derivation rule. |
| 2 | `CompCardItemsRow` external refs not verified | Grep done — 1 callsite (`CompCard.swift:45`), 2 stale comments in `CompCardAnomaliesRow.swift`. Both addressed in Migration section. |
| 3 | Star indicator vs cost border position conflict | Verified math: stars at `offset(y: -8)` above portrait, border `lineWidth: 2` on portrait edge — no overlap. ZStack frame `size + 6` already accommodates. |
| 4 | Tests assuming `CompCardItemsRow` | Grep — only `TierListDecodingTests` matches item patterns; tests JSON decoding, not view tree. No breakage expected. |
| 5 | "~50 items" assumption — actual count unknown | en_us.json has 3565 items total. Bundle scoped to items present in current `tier-list.json` + buffer (~80-150 entries, ~30-50KB JSON). |
| 6 | Tier-color border drop = lost signal? | No — tier badge already rendered as standalone circle at comp card top. Duplicate signal. |
| 7 | Performance: 1184 fetches first launch | Documented in Performance budget — async parallel, 30-60s cold launch acceptable, >99% cache hit steady-state. |
| 8 | `iconToken` extraction method ambiguous | Spec'd: lowercase relative path minus `.png` suffix, derived from CDragon `icon` field. |

No remaining blockers. Spec ready for writing-plans.

---

## Cross-references

- Approval thread: this conversation (anh approved 2026-04-27)
- Pattern reference: Phase 2 TraitCatalog/TraitAssetURL/TraitChip implementation (commits `299ac6d`, `268be11`)
- Related bugs: #007 (cost: 0 in trait-bucket emission — fixed in `e20df94`); none for items
