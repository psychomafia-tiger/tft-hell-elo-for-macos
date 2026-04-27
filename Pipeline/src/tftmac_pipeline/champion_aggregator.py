"""Champion aggregation per comp group — unit frequency + carry detection.

Identifies top-8 units by appearance frequency across comp instances, and marks
carry units based on avg star-level (tier >= 2 = 2-star+ on final board).

Cost convention: unit.rarity + 1 (matches extract_signature convention).
  rarity 0 → cost 1 (e.g. Lissandra)
  rarity 4 → cost 5 (e.g. Karma, 5-cost)
  rarity 6 → cost 7 (Blitzcrank-style special)

Carry heuristic: units where avg tier_current >= 2 are treated as carries.
Players 2-star their carries; 1-stars are fillers. This is a board-snapshot
heuristic — "most participants had this unit at 2+ stars" = it's a carry slot.
"""
from __future__ import annotations

from collections import Counter, defaultdict

_TOP_N_CHAMPIONS = 8
_ANOMALY_PREFIX = "TFT17_EkkoOffering_"


def aggregate_champions(participants: list[dict]) -> list[dict]:
    """Aggregate champion entries from a comp group's participants.

    Args:
        participants: Raw Riot participant dicts belonging to this comp group.

    Returns:
        List of champion dicts (up to 8), sorted by frequency desc:
          {
            "id": "TFT17_Viktor",
            "cost": 5,
            "is_carry": True,
            "star_level": 2,
            "items": [{"id": "TFT_Item_JeweledGauntlet", "agreement": 0.82}, ...]
          }
    """
    if not participants:
        return []

    # Count appearances and track tier sums for carry detection
    unit_count: Counter[str] = Counter()
    unit_rarity: dict[str, int] = {}
    # tier_sum[character_id] = sum of tier values across appearances
    tier_sum: dict[str, int] = defaultdict(int)
    # star_counts[character_id] = Counter of observed tier values (star levels)
    # Modal value = most common observed star level across all appearances.
    # Example: Viktor observed 12× at tier=2, 3× at tier=3, 1× at tier=1
    #          → star_counts["TFT17_Viktor"] = Counter({2:12, 3:3, 1:1})
    #          → modal star_level = 2
    star_counts: dict[str, Counter[int]] = defaultdict(Counter)
    # item counts per character (excluding anomaly items)
    item_counts: dict[str, Counter[str]] = defaultdict(Counter)

    for participant in participants:
        for unit in participant.get("units", []):
            cid = unit.get("character_id", "")
            if not cid:
                continue
            tier_val = unit.get("tier", 1)
            unit_count[cid] += 1
            unit_rarity[cid] = unit.get("rarity", 0)
            tier_sum[cid] += tier_val
            star_counts[cid][tier_val] += 1

            for item_name in unit.get("itemNames", []):
                if not item_name.startswith(_ANOMALY_PREFIX):
                    item_counts[cid][item_name] += 1

    top_units = unit_count.most_common(_TOP_N_CHAMPIONS)
    champions = []
    for cid, appearances in top_units:
        avg_tier = tier_sum[cid] / appearances
        is_carry = avg_tier >= 2.0
        cost = unit_rarity.get(cid, 0) + 1

        # Modal star level: most common observed tier value across appearances.
        # Falls back to 1 if no data (should not occur if unit_count > 0).
        modal_star = star_counts[cid].most_common(1)[0][0] if star_counts[cid] else 1

        # Build item list: top-3 items with agreement >= 0.40
        items = _build_item_list(item_counts[cid], appearances)

        champions.append({
            "id": cid,
            "cost": cost,
            "is_carry": is_carry,
            "star_level": modal_star,
            "items": items,
        })

    return champions


def _build_item_list(item_counter: Counter[str], appearances: int) -> list[dict]:
    """Compute top-3 items for a single champion slot.

    agreement = item_appearances / unit_appearances across the comp group.
    Min agreement 0.40 to surface consistent item choices.
    """
    if appearances == 0:
        return []
    results = []
    for item_id, count in item_counter.most_common():
        agreement = count / appearances
        if agreement >= 0.40:
            results.append({"id": item_id, "agreement": round(agreement, 4)})
        if len(results) >= 3:
            break
    return results
