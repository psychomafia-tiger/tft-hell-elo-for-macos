"""Trait combo signature for comp grouping.

Signature = sorted tuple of (trait_name, tier_current) for all active traits
(tier_current > 0). Used as dict key in comp_grouping to collapse same trait
combos into one canonical comp regardless of which specific carry-equivalents
were played.
"""
from typing import Tuple

def trait_combo_signature(participant: dict) -> Tuple[Tuple[str, int], ...]:
    traits = participant.get("traits", [])
    active = [
        (t["name"], t.get("tier_current", 0))
        for t in traits
        if t.get("tier_current", 0) > 0
    ]
    return tuple(sorted(active))
