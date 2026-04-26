# CommunityDragon Set 17 endpoint research

**Date probed:** 2026-04-26
**Method:** `curl -sIL` against candidate URL patterns; verified HTTP 200 + cross-checked 4+ champion IDs.

## Champion portraits — VERIFIED

**Pattern:** `https://raw.communitydragon.org/latest/game/assets/characters/{lower_id}/hud/{lower_id}_square.tft_set17.png`

Examples (all return HTTP 200):
- `TFT17_Aatrox` → `tft17_aatrox/hud/tft17_aatrox_square.tft_set17.png` ✅
- `TFT17_Viktor` → `tft17_viktor/hud/tft17_viktor_square.tft_set17.png` ✅
- `TFT17_Illaoi` → `tft17_illaoi/hud/tft17_illaoi_square.tft_set17.png` ✅
- `TFT17_KaiSa` → `tft17_kaisa/hud/tft17_kaisa_square.tft_set17.png` ✅ (camelCase flattens)

**Transform**: lowercase whole ID, no separator changes.

## Trait icons — VERIFIED

**Pattern:** `https://raw.communitydragon.org/latest/game/assets/ux/traiticons/trait_icon_17_{lower_name}.tft_set17.png`

Examples (live from directory listing):
- `Set17_Animatech` → `trait_icon_17_animatech.tft_set17.png`
- `Set17_Arbiter` → `trait_icon_17_arbiter.tft_set17.png`
- `Set17_Bulwark` → `trait_icon_17_bulwark.tft_set17.png`
- `Set17_Challenger` → `trait_icon_17_challenger.tft_set17.png`

**Transform**: strip `Set17_` prefix, lowercase remainder, prefix `trait_icon_17_`, suffix `.tft_set17.png`.

## Item icons — NOT DETERMINISTIC

**Pattern (base):** `https://raw.communitydragon.org/latest/game/assets/maps/particles/tft/item_icons/standard/{snake_case_filename}.png`

Filenames are snake_case but **not** derivable from Riot IDs:
- `TFT_Item_JeweledGauntlet` → `jeweled_guantlet.png` (note: upstream typo "guantlet")
- `TFT_Item_GargoyleStoneplate` → `gargoyle_stoneplate.png`
- `TFT_Item_InfinityEdge` → `infinity_edge.png`

**Implication for Phase 3 Task 6**: cannot build URL via simple lowercasing. Need either:
- Hand-curated mapping table (Riot ID → filename) bundled with app, OR
- Lazy lookup against CommunityDragon's tftitems.json (large file, ~10MB), OR
- Try multiple naming conventions with fallback

**Recommended approach** (decided in Phase 3 plan refinement): bundle a small hand-curated `set17-item-icon-map.json` (~40-50 entries covering all items in current `data/tier-list.json`). Update once per Riot patch.

## Negative results (404)

- `_square.tex.png` ❌
- `_square.png` ❌
- `plugins/rcp-be-lol-game-data/...` ❌ (only TFT16 in plugin feed, stale)
- `cdn.communitydragon.org/latest/champion/{id}/square` ❌
- `ddragon.leagueoflegends.com/cdn/.../img/tft-champion/...` ❌

## Plan delta

Update Phase 1 Task 3 (`ChampionAssetURL`) to use `_square.tft_set17.png` suffix (was: `_square.tex.png`).
Update Phase 2 Task 7 (`TraitAssetURL`) to use `trait_icon_17_{name}.tft_set17.png` (was guessed `trait_icon_17_{name}.png`).
Update Phase 3 Task 6 (`ItemAssetURL`) — replace deterministic builder with map-driven lookup.

## Reproducibility

```bash
# Champion (Aatrox)
curl -sIL "https://raw.communitydragon.org/latest/game/assets/characters/tft17_aatrox/hud/tft17_aatrox_square.tft_set17.png" | head -1
# → HTTP/2 200

# Trait (Psionic — list via dir to confirm)
curl -sL "https://raw.communitydragon.org/latest/game/assets/ux/traiticons/" | grep psionic
# → trait_icon_17_psionic.tft_set17.png

# Item (need dir listing to discover filename)
curl -sL "https://raw.communitydragon.org/latest/game/assets/maps/particles/tft/item_icons/standard/" | grep -oE '[a-z_]+\.png'
```
