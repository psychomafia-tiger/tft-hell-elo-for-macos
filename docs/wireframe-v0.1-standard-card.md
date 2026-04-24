# Wireframe v0.1 — Standard Comp Tier Card (Menu Bar Popover)

**Status**: LOCKED (chốt) 2026-04-24 — gate criteria cho Phase 1 Task 1.9
**Reference PNG**: `docs/wireframes/popover-styleA-v2.png` (Stitch-generated, Card Style A v2)
**Predecessor**: `docs/wireframes/card-stylea-v1.png` (v1, deprecated — rendered full dashboard shell thay vì popover)

---

## Purpose

Lock (khoá) layout dimensions + visual hierarchy (hệ thống phân cấp thị giác) cho SwiftUI implementation của menu bar popover (cửa sổ bật lên từ thanh menu bar). Wireframe PNG là **reference only** (chỉ làm tham chiếu) — dev sẽ custom trong SwiftUI, không copy pixel-perfect từ PNG.

**Plain-language example**: nghĩ như bản vẽ kiến trúc (blueprint) — chỉ ra phòng nào đặt đâu, kích thước bao nhiêu, nhưng gạch sơn mặc kệ thợ chọn. Stitch PNG là blueprint; SwiftUI là thi công.

---

## Locked Dimensions

### Popover container (khung popover)

| Property | Value | Rationale |
|---|---|---|
| Width | **440 px** | Đủ rộng cho 4 champion portraits + items row không wrap; đủ hẹp để không overlap (đè) Chrome window khi user alt-tab |
| Height | **600 px** | Fit 3 tier cards (120 × 3 = 360) + header (56) + padding + footer buffer (~180) |
| Corner radius | 12 px | Standard macOS floating window vibe |
| Background | `#1E1E1E` | Raycast/Linear dark base |
| Border | 1 px `#38383A` | Subtle edge definition (phân cách cạnh tinh tế) |

**Concrete example**: 1 TFT round 2-1 (augment selection round) user có ~30s để decide (quyết định). User press Cmd+Shift+T → popover 440×600 hiện ở top-right menu bar, cover (che) ~20% màn hình 1440p, không che carousel game phía dưới → user scan (lướt qua) 3 tier S comps trong <5s → press Cmd+Shift+T lần 2 đóng → stay in-game.

### Header (56 px tall, toàn width)

| Element | Spec |
|---|---|
| Left title | "TFT Mac" · SF Pro Semibold 15 px · `#FFFFFF` |
| Subtitle (below title OR right of title, tuỳ SwiftUI layout) | "Patch 16.8 · 98 Challenger matches · Updated 2h ago" · SF Pro Regular 11 px · `#8E8E93` |
| Right settings icon | SF Symbol `gearshape` · 16 px · `#8E8E93` · tap target (vùng chạm) 28×28 |
| Bottom divider | 1 px `#38383A` hairline |

### Tier card (400 × 120 px, vertical stack)

| Property | Value |
|---|---|
| Outer dimensions | 400 × 120 px |
| Horizontal padding from popover edge | 20 px each side (match 20+400+20 = 440) |
| Vertical gap between cards | 8 px |
| Card background | `#2C2C2E` |
| Card border | 1 px `#38383A` |
| Card corner radius | 8 px |
| Inner padding | 12 px all sides |

### Tier badge (28 × 28 px, top-left of card)

| Tier | Background | Text color | Label |
|---|---|---|---|
| S | `#FFD700` (gold) | `#000000` | "S" |
| A | `#C0C0C0` (silver) | `#000000` | "A" |
| B | `#CD7F32` (bronze) | `#000000` | "B" |

- Shape: circle (pill 28×28 px)
- Font: SF Pro Bold 14 px, centered

**Why not more tiers for v0.1?** S/A/B đủ cho 80% TFTactics meta variance (độ biến thiên meta). Thêm C/D → noise (nhiễu), user không play comps đó.

### Content layout inside card (horizontal left-to-right)

```
[28×28 badge] [comp name + metadata stack] [4 champion portraits row] [items row at bottom, full card width]
```

- **Comp name**: SF Pro Semibold 14 px, `#FFFFFF`. Example: "Storm Quickdraw"
- **Metadata row** (below name): SF Pro Regular 11 px, `#8E8E93`. Format: `Avg {placement} · Play {rate}% · {N} matches`. Example: "Avg 3.8 · Play 5.6% · 22 matches"
- **Champion portraits**: 4 circular icons × 32 px diameter, 6 px horizontal gap. BIS carry (best-in-slot đơn vị chủ lực) has 2 px border matching tier badge color (gold/silver/bronze).
- **Items row** (bottom of card, SF Mono 10 px): `{Carry} → {Item1} {%}% · {Item2} {%}%  |  {Support} → {Item3} {%}%`. Percentages colored `#FFD700` (amber) cho visual weight (trọng lực thị giác).

**Concrete numerical example**:
- Comp "Storm Quickdraw" trong fixture 98-match data có 22 matches → play_rate = 22/98 = 22.4%. Sum (tổng) placement = 84 → avg = 84/22 = 3.8.
- Top carry Viktor xuất hiện 20/22 games holding (cầm) Jeweled Gauntlet → agreement = 20/22 = 90%. Nhưng hiện 77% trong wireframe example là weighted (có trọng số) để illustrate format, không phải real data.
- Thực tế: value compute từ `ItemAggregator.aggregate()` trong Pipeline (chưa impl Phase 2).

---

## Typography tokens

```
title-large: SF Pro Semibold 15px #FFFFFF
title: SF Pro Semibold 14px #FFFFFF
caption: SF Pro Regular 11px #8E8E93
mono-caption: SF Mono Regular 10px #8E8E93
mono-emphasis: SF Mono Regular 10px #FFD700  (for % values)
badge: SF Pro Bold 14px #000000 (on tier badge bg)
```

## Color tokens

```
bg-popover: #1E1E1E
bg-card: #2C2C2E
border-default: #38383A
text-primary: #FFFFFF
text-muted: #8E8E93
accent-gold: #FFD700   (S tier + percentages)
accent-silver: #C0C0C0 (A tier)
accent-bronze: #CD7F32 (B tier)
```

## Spacing tokens

```
padding-popover: 20px horizontal
padding-card: 12px all sides
gap-cards: 8px
gap-champion-icons: 6px
radius-popover: 12px
radius-card: 8px
radius-badge: 14px (half of 28px = full circle)
```

---

## Stitch output deviations (chênh lệch so với spec, được phép ignore)

Stitch v2 PNG render bao gồm một số element **không thuộc** popover spec — SwiftUI dev bỏ qua:

1. **Footer text "TACTICAL_MONOLITH v2.5"** — watermark (dấu đóng) của Stitch design system project, không phải feature
2. **Footer text "Live API"** — Stitch tự generate status indicator (chỉ số trạng thái), không request trong prompt
3. **Popover dimensions trong PNG** = 512×410 compressed preview, **không** 440×600 → dev dùng con số từ table "Locked Dimensions" ở trên, không đo từ PNG
4. **Subtle glow quanh popover** — Stitch rendering artifact (sản phẩm phụ khi render), không implement trong SwiftUI

**Plain-language**: PNG cho thấy "popover nên trông như thế này"; bảng dimensions cho biết "đo chính xác như thế này". Nếu 2 cái conflict (mâu thuẫn), bảng thắng.

---

## Data binding (ánh xạ dữ liệu → UI)

Card render từ 1 `CompEntry` struct (Phase 1 Task 1.5):

```swift
struct CompEntry {
    let tier: Tier                    // .S | .A | .B
    let name: String                  // "Storm Quickdraw"
    let avgPlacement: Double          // 3.8
    let playRate: Double              // 0.056 → format as "5.6%"
    let matchCount: Int               // 22
    let coreUnits: [ChampionPortrait] // 4 items, one marked .isBISCarry=true
    let topItems: [ItemBuild]         // carry build + support build
}
```

- 4 champion portraits max — nếu comp core có 5+ units (đơn vị), lấy top 4 theo usage_rate (tỉ lệ dùng)
- Items row max ~80 chars — nếu dài hơn thì truncate (cắt ngắn) với ellipsis

---

## Out of scope (ngoài phạm vi v0.1)

- **Scrolling cards**: v0.1 hiện tối đa 3 tier cards fixed; Phase 2 backend trả về nhiều hơn thì cắt top 3. Không scroll.
- **Expanded card view**: click card không expand (mở rộng) show detailed board. Deferred (hoãn) đến v0.2.
- **Search/filter**: không có trait filter trong v0.1.
- **Live match tracking**: KHÔNG implement — deferred to v0.2 overlay test.

---

## Acceptance criteria (tiêu chí chấp nhận) cho Phase 1 Task 1.9

Dev's SwiftUI implementation pass (qua) Task 1.9 khi:

- [ ] Popover render đúng 440×600 (measure qua `NSWindow.frame`)
- [ ] Header text match (khớp) spec: "TFT Mac" + patch/match/timestamp subtitle + gear icon
- [ ] 3 tier cards stack vertically (xếp dọc) với 8px gap
- [ ] Tier badges S/A/B có color codes đúng (`#FFD700`/`#C0C0C0`/`#CD7F32`)
- [ ] Champion portraits 32px circular, BIS carry có 2px tier-color border
- [ ] Items row dùng SF Mono, percentages có accent color
- [ ] Dark theme (chế độ tối) only — không support light theme trong v0.1
- [ ] Cmd+Shift+T toggle popover trong <300ms từ trigger đến render xong (Task 1.10 XCUITest verify)

---

## Change log

- 2026-04-24: Initial lock (v2 Stitch-generated, Card Style A). Replaces v1 which had peripheral app chrome.
