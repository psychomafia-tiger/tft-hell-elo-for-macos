"""Comp grouping via Jaccard similarity (spec §Comp Detection Step 2-3)."""
from collections import Counter, defaultdict

from tftmac_pipeline.jaccard import jaccard_similarity
from tftmac_pipeline.trait_signature import trait_combo_signature


def _sig_to_set(signature: str) -> set[str]:
    """Parse `"A+B+C"` → {A, B, C}. Empty string → empty set."""
    return set(signature.split("+")) if signature else set()


def group_signatures(signatures: list[str], threshold: float) -> list[dict]:
    """Group signatures by Jaccard similarity.

    Each group has:
    - `canonical`: most frequent signature (group name source)
    - `frequency`: total count including merged variants
    - `variants`: all signatures that merged into group

    Algorithm: iterate signatures in descending frequency order. For each,
    check Jaccard vs existing group canonicals. If any >= threshold, merge;
    else create new group.

    **Ví dụ concrete**: threshold=0.70, 3 signatures:
    - `"A+B+C+D+E"` × 2 → freq 2 (first to process → canonical of group 1)
    - `"A+B+C+D+E+F"` × 1 → Jaccard vs canonical = 5/6 = 0.833 ≥ 0.70 → merge
    Result: 1 group, canonical `"A+B+C+D+E"`, frequency 3.
    """
    counter = Counter(signatures)
    groups: list[dict] = []
    for sig, freq in counter.most_common():
        sig_set = _sig_to_set(sig)
        matched = False
        for group in groups:
            canonical_set = _sig_to_set(group["canonical"])
            if jaccard_similarity(sig_set, canonical_set) >= threshold:
                group["frequency"] += freq
                group["variants"].append(sig)
                matched = True
                break
        if not matched:
            groups.append({"canonical": sig, "frequency": freq, "variants": [sig]})
    return groups


def group_comps_by_trait_signature(participants: list[dict]) -> dict:
    """Group participants by trait combo signature.

    Returns dict[signature_tuple → aggregated comp dict] where each comp dict
    has: sample_size, placements (for avg + top4), trait_signature, champions
    (union with frequency).
    """
    buckets = defaultdict(lambda: {
        "sample_size": 0,
        "placements": [],
        "trait_signature": None,
        "champion_freq": defaultdict(int),
        "items_per_champion": defaultdict(lambda: defaultdict(int)),
        # Bug #007 producer side — wire per-champion rarity (cost = rarity+1)
        # and modal-star aggregation. Consumer is `_emit_champions_from_bucket`
        # in json_emitter.py: reads `champion_rarity[cid]` and
        # `champion_star_counts[cid]` (Counter of tier→count).
        "champion_rarity": {},
        "champion_star_counts": defaultdict(lambda: defaultdict(int)),
    })
    for p in participants:
        sig = trait_combo_signature(p)
        if not sig:
            continue
        b = buckets[sig]
        b["trait_signature"] = sig
        b["sample_size"] += 1
        b["placements"].append(p.get("placement", 8))
        for unit in p.get("units", []):
            cid = unit.get("character_id")
            if not cid:
                continue
            b["champion_freq"][cid] += 1
            # rarity is stable per champion (cost class 0-6); last write wins —
            # all participants in this bucket should report the same value.
            b["champion_rarity"][cid] = unit.get("rarity", 0)
            # tier is the observed star level (1/2/3) on this participant's
            # board. Modal across the bucket = "what star level players
            # actually hit on this carry slot".
            tier = unit.get("tier", 1)
            if 1 <= tier <= 3:
                b["champion_star_counts"][cid][tier] += 1
            # Bug #008 — Riot Set 17 leaves `items` (int IDs) empty; populates
            # `itemNames` (strings like "TFT_Item_GargoyleStoneplate") instead.
            # Prefer itemNames; fall back to items for older sets / safety.
            raw_items = unit.get("itemNames") or unit.get("items") or []
            for item in raw_items:
                item_id = item if isinstance(item, str) else (
                    item if isinstance(item, int) else item.get("id") if isinstance(item, dict) else None
                )
                if item_id is not None:
                    b["items_per_champion"][cid][item_id] += 1
    return dict(buckets)
