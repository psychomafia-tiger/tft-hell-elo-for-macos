"""Rule-based positioning aggregation (Phase 4 fallback).

Riot Match-v5 does not expose unit positions for Set 17 (verified
2026-04-29 — see plans/260426-1752-tftactics-feature-parity/research/
match-v5-positioning.md). This module assigns hex positions
deterministically from cost + carry status + active comp traits.

Hex grid: 4 rows × 7 cols = 28 hexes (pos 0-27).
- Row 0 (pos 0-6):   backline (carries)
- Row 1 (pos 7-13):  mid-back
- Row 2 (pos 14-20): mid-front
- Row 3 (pos 21-27): frontline (tanks)

`frequency=1.0` on every output signals "rule-inferred" to consumers.
When Riot eventually exposes a `pos` field, swap implementation to
modal-frequency aggregation and `frequency` becomes <1.0.
"""
from __future__ import annotations

# Trait token classifications. Tokens checked as substrings of trait names so
# both `TFT17_HPTank` and a future `TFT18_BrawlerTank` would be classified.
_FRONTLINE_TOKENS = (
    "Tank", "Melee", "Brawler", "Vanguard", "Bastion",
    "Bruiser", "Warrior", "Juggernaut",
)
_BACKLINE_TOKENS = (
    "Ranged", "AP", "AS", "Mana", "Sniper", "Sorcerer",
    "Marksman", "Mage", "Caster",
)

# Carry slot priority order on row 0: center first, then alternating wings.
_CARRY_SLOTS = [3, 1, 5, 0, 6, 2, 4]

# Cost-2 default frontline cluster (row 3).
_FRONTLINE_SLOTS = [22, 25, 23, 26, 24, 21, 27]

# Cost-3 mid-row slots — choice depends on archetype.
_MID_BACK_SLOTS = [11, 9, 12, 8, 10, 13, 7]    # row 1 (backline_heavy)
_MID_FRONT_SLOTS = [17, 15, 18, 14, 16, 19, 20]  # row 2 (frontline_heavy)

# Cost-4 non-carry default — row 1 mid-back, distinct from cost-3 to avoid clash.
_HIGH_COST_BACK_SLOTS = [8, 12, 7, 13]


def classify_archetype(traits: list[dict]) -> str:
    """Return 'frontline_heavy' | 'backline_heavy' | 'flex' from active traits.

    Concrete example: comp activates `TFT17_HPTank` (count 3) and
    `TFT17_Mecha` (count 2). HPTank contains "Tank" → frontline_heavy.

    Tie-break: when both fronts and backs are present, frontline wins —
    rationale: tanky comps anchor harder around their frontline placement
    than backline carries do (carries pivot anywhere on row 0).
    """
    has_front = False
    has_back = False
    for t in traits:
        name = t.get("name", "") if isinstance(t, dict) else ""
        if any(tok in name for tok in _FRONTLINE_TOKENS):
            has_front = True
        if any(tok in name for tok in _BACKLINE_TOKENS):
            has_back = True
    if has_front:
        return "frontline_heavy"
    if has_back:
        return "backline_heavy"
    return "flex"


def _next_free(preferred: list[int], taken: set[int]) -> int | None:
    """Pick first slot from `preferred` not in `taken`. None if all taken."""
    for slot in preferred:
        if slot not in taken:
            return slot
    return None


def _walk_to_free(start_pos: int, taken: set[int]) -> int | None:
    """Linear walk pos+1, pos-1, pos+2, pos-2... within 0-27 range.

    Last-resort fallback when archetype-specific slots are exhausted.
    """
    for delta in range(1, 28):
        for candidate in (start_pos + delta, start_pos - delta):
            if 0 <= candidate <= 27 and candidate not in taken:
                return candidate
    return None


def _assign(positions: dict, taken: set[int], cid: str, slot: int | None,
            fallback_anchor: int = 14) -> None:
    """Assign `cid` to `slot` (or walk to nearest free hex starting at anchor)."""
    if slot is None:
        slot = _walk_to_free(fallback_anchor, taken)
    if slot is None:
        return  # board full (>28 champs) — silently drop, shouldn't happen
    positions[cid] = slot
    taken.add(slot)


def aggregate_positions(champions: list[dict], traits: list[dict]) -> list[dict]:
    """Assign hex positions to champions via rule-based heuristics.

    Args:
        champions: list of champion dicts with `id`, `cost`, `is_carry` keys
                   (output shape from `champion_aggregator.aggregate_champions`).
        traits:    list of trait dicts with `name` key (active comp traits).

    Returns:
        list of `{"championId": str, "pos": int (0-27), "frequency": 1.0}`.
        Output ordered by champion input order. Champions with missing/empty
        `id` are skipped silently.
    """
    archetype = classify_archetype(traits)
    valid = [c for c in champions if c.get("id")]
    if not valid:
        return []

    taken: set[int] = set()
    positions: dict[str, int] = {}

    # Phase 1: carries to row 0 (backline), cost desc within carries
    carries = [c for c in valid if c.get("is_carry")]
    carries.sort(key=lambda c: -c.get("cost", 0))
    for i, c in enumerate(carries):
        slot = _CARRY_SLOTS[i] if i < len(_CARRY_SLOTS) else None
        _assign(positions, taken, c["id"], slot, fallback_anchor=3)

    # Phase 2: non-carries by cost bracket
    non_carries = [c for c in valid if not c.get("is_carry")]
    by_cost = {5: [], 4: [], 3: [], 2: [], 1: [], 7: []}
    for c in non_carries:
        cost = c.get("cost", 1)
        by_cost.setdefault(cost, [])
        by_cost.setdefault(cost, []).append(c) if cost not in by_cost else by_cost[cost].append(c)

    # Cost 7+ (Blitzcrank-unique): pos 24 (row 3 col 3 dead front)
    for c in by_cost.get(7, []):
        _assign(positions, taken, c["id"], 24, fallback_anchor=24)

    # Cost 5 non-carry: bonus row-0 corners (0, 6)
    for i, c in enumerate(by_cost.get(5, [])):
        slot = _next_free([0, 6, 4, 2], taken)
        _assign(positions, taken, c["id"], slot, fallback_anchor=0)

    # Cost 4 non-carry: row 1 (mid-back)
    for c in by_cost.get(4, []):
        slot = _next_free(_HIGH_COST_BACK_SLOTS, taken)
        _assign(positions, taken, c["id"], slot, fallback_anchor=10)

    # Cost 3: archetype-driven row choice
    cost3_slots = (
        _MID_FRONT_SLOTS if archetype == "frontline_heavy" else _MID_BACK_SLOTS
    )
    for c in by_cost.get(3, []):
        slot = _next_free(cost3_slots, taken)
        _assign(positions, taken, c["id"], slot, fallback_anchor=cost3_slots[0])

    # Cost 1-2: frontline (row 3)
    for c in by_cost.get(2, []) + by_cost.get(1, []):
        slot = _next_free(_FRONTLINE_SLOTS, taken)
        _assign(positions, taken, c["id"], slot, fallback_anchor=24)

    # Anything not yet placed (unusual costs): walk from row 2 center.
    placed_ids = set(positions.keys())
    for c in valid:
        if c["id"] not in placed_ids:
            _assign(positions, taken, c["id"], None, fallback_anchor=17)

    return [
        {"championId": c["id"], "pos": positions[c["id"]], "frequency": 1.0}
        for c in valid
        if c["id"] in positions
    ]
