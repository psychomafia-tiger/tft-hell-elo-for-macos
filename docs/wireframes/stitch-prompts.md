# Stitch Design Generation Prompts — TFT Mac v0.1

**Purpose**: feed these into Google Stitch MCP (or web UI) to generate wireframe mockups for Phase 0 F6 gate.

**Context files to reference**:
- Spec: `docs/product-spec-v0.1.md` (updated 2026-04-24 with BIS items pivot)
- Real fixture data: `Pipeline/tests/fixtures/sample-participant.json`

**Known Stitch quirk** (anh observed 2026-04-24): Stitch defaults to iOS mobile aspect by default. These prompts explicitly emphasize **macOS desktop menu bar app** to counter that bias.

---

## Layout Count: 2 (per F6 decision)

1. **Comp Card** (atomic component, design first, iterate fast)
2. **Full Popover** (composition, only after Card locks)

Layouts deliberately skipped for v0.1 (not worth Stitch):
- Menu bar icon 4 states (18×18, use SF Symbols directly in Xcode)
- Empty/loading/error states (simple text overlays)

---

## Style Vibes (pick one or run all 3)

| Vibe | Reference feel | Palette hints |
|------|----------------|---------------|
| **A. Minimalist Dark** | Raycast, Linear | bg #1E1E1E, text #E0E0E0, SF Mono for numbers |
| **B. TFT-themed** | TFTactics.gg, MetaTFT | bg #0F1B2D navy, metallic gold tier badges, subtle dragon texture |
| **C. Polished SaaS** | Notion, Arc Browser | bg #1A1A2E, purple-blue #7C3AED accent, glassmorphism |

---

## Prompt 1 — Comp Card (START HERE)

```
Design a single "comp tier list card" component for a NATIVE macOS MENU BAR DESKTOP APP.
NOT an iOS mobile app. This is a macOS desktop popover that drops down from the menu bar,
like Raycast, Bartender, or Rectangle Pro. Platform: Apple macOS 14+ on a laptop/desktop
screen, not iPhone, not iPad.

PURPOSE
Teamfight Tactics (TFT, Riot's auto-battler) players open this app mid-game to answer:
"Which meta comp should I play, and what items should I build on my core champions?"
The card is the atomic unit of the tier list. 5-10 cards stack vertically in the popover.

DIMENSIONS (desktop scale — not mobile)
- Width: exactly 400px (fixed, card sits inside 440px popover with 20px padding each side)
- Height: 100-120px (aim for 5 cards visible without scroll in a 600px popover)
- Corner radius: 8px
- Border: 1px subtle outline

CONTENT (all fields must appear)
1. Tier badge — letter "S" in colored pill, top-left corner of card
   - S = gold #FFD700, A = silver #C0C0C0, B = bronze #CD7F32, C = gray #808080
2. Comp name — "Storm Quickdraw Viktor", H2 weight, 14pt
3. Stats row — small muted text 11pt: "avg 3.2 · 5.6% play rate · 22 matches"
4. Champion icons row — 4 circular icons 40x40px, horizontal, 8px gap between
   - Carry champion (Viktor) has gold border glow 2px
   - Labels: "Viktor" (carry, cost 5), "Illaoi" (cost 3), "Nami" (cost 3), "Rhaast" (cost 4)
5. BIS items section BELOW champion row — per core champion:
   - "Viktor → [item icon] Jeweled Gauntlet 77%   [item icon] Archangel's Staff 55%"
   - "Illaoi → [item icon] Gargoyle Stoneplate 59%"
   - "Rhaast → Flex" (gray muted italic text, not a real item)
   - Item icons are small squares 24x24px, agreement % as small badge next to item
6. Optional "Low confidence" state — 50% opacity overlay + yellow warning icon when sample_size < 100

STYLE (pick ONE — paste the matching block)
A) Minimalist dark (Raycast vibe): background #1E1E1E, text #E0E0E0, SF Mono font for
   numbers/percentages, SF Pro for names, sharp 1px borders, no shadows, no decoration.
B) TFT-themed (TFTactics.gg vibe): background #0F1B2D navy, tier badges metallic gold
   shine, subtle dragon-scale texture on card border, champion icons in ornate gold frames.
C) Polished SaaS (Arc Browser vibe): background #1A1A2E, purple-blue #7C3AED accent
   for carry highlight, glassmorphism (slight blur + transparency), clean rounded corners.

CONSTRAINTS
- Dark mode ONLY (TFT players use low brightness)
- Desktop readability: minimum 11pt body text, 14pt heading
- Must stack cleanly in a vertical list — no horizontal overflow
- No illustrations, no hero images — icons and typography only
- macOS native feel: SF Symbols for UI icons, SF Pro for typography
- DO NOT render a phone frame, status bar, or home indicator
- DO NOT include iOS safe areas or mobile navigation tabs

OUTPUT
One high-fidelity card mockup. Provide 3 variants in different tier examples
(one S-tier, one A-tier, one B-tier) so I can see the tier badge color system in context.
All 3 variants use the same selected style.
```

---

## Prompt 2 — Full Popover (AFTER Card locks)

```
Design a native macOS MENU BAR POPOVER containing a scrollable tier list of Teamfight
Tactics meta comps. DESKTOP APP — NOT iOS, NOT iPad, NOT web.

CONTEXT
User presses Cmd+Shift+T hotkey while playing TFT (the game runs in background). The
popover drops down from a menu bar icon in the top-right of the macOS screen, like
Raycast or Bartender. It must feel like a first-class native macOS app.

DIMENSIONS (desktop scale)
- Width: 440px fixed
- Height: 600px max with internal scroll for overflow
- Corner radius: 10px
- Anchor indicator: small triangle pointing UP at the top edge, toward the (invisible)
  menu bar icon

LAYOUT (top to bottom)
1. HEADER (56px tall, sticky at top)
   - App title: "TFT Mac" left-aligned, 16pt weight semibold
   - Subtitle small text 10pt muted: "Patch 16.8 · 98 Challenger matches · Updated 2h ago"
   - Right-side: settings gear SF Symbol icon 16x16

2. BODY (scrollable content area)
   - Vertical stack of 5-8 Comp Cards (same design as Prompt 1 output)
   - Cards separated by 8px vertical spacing
   - Sorted by tier: S → A → B
   - Section divider between tier groups: thin horizontal line + small uppercase label
     "S TIER (3 comps)" in muted gray

3. FOOTER (40px tall, sticky at bottom)
   - Text: "Auto-refreshes every 6 hours · Data source: GitHub" (10pt muted)

STYLE
Same vibe as Prompt 1 (keep consistent). Reference Prompt 1's style choice.

CONSTRAINTS
- Dark mode only
- Native macOS scrollbar (thin, fades in on hover)
- Header sticky during scroll
- No close button (popover closes on outside click — native behavior)
- No iOS tab bar, no bottom navigation
- No phone/tablet frame around the popover

OUTPUT
One full popover mockup showing:
- 2 S-tier cards
- 2 A-tier cards
- 1 B-tier card with "Low confidence" grayed-out state (sample < 100)
- Header fully rendered with real data
- Scrollbar visible (hovered state, top-right inside body)
- Rendered as if floating on a dark macOS desktop — no phone chrome
```

---

## How to iterate

1. Run Prompt 1 with Style A (safest default)
2. If output looks like iOS (phone frame, tab bar, etc.) — regenerate with emphasis: "DESKTOP MACOS ONLY, NOT MOBILE, NOT iPhone"
3. If output looks good but proportions off — tweak specific dimensions inline ("make width exactly 400px", "make tier badge 32x32px")
4. When Card is approved, save final PNG → `docs/wireframes/card-standard-v1.png`
5. Run Prompt 2 with same style
6. Save Popover PNG → `docs/wireframes/popover-full-v1.png`
7. Write `docs/wireframe-v0.1-standard-card.md` with locked dimensions table

## Locked dimensions template (fill after picking a variant)

```markdown
# Wireframe v0.1 — Locked Dimensions

## Popover
- Width: 440px
- Height: max 600px
- Corner radius: 10px
- Header height: 56px
- Footer height: 40px
- Body padding: 20px horizontal, 12px top/bottom

## Comp Card
- Width: 400px
- Height: 120px
- Corner radius: 8px
- Border: 1px #333

## Typography
- App title: SF Pro Semibold 16pt
- Comp name: SF Pro Medium 14pt
- Stats line: SF Pro Regular 11pt muted
- BIS items: SF Mono 11pt for % values

## Icons
- Champion circle: 40x40px, 8px gap
- Item square: 24x24px
- Tier badge: 28x28 pill

## Colors (Dark mode)
- Background: [#XXXXXX]
- Card bg: [#XXXXXX]
- Text primary: [#XXXXXX]
- Text muted: [#XXXXXX]
- Accent (carry highlight): [#XXXXXX]
```
