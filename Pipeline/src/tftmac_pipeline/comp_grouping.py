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
            for item in unit.get("items", []) or []:
                # Riot returns ints (item ids) or dicts; normalize
                item_id = item if isinstance(item, (str, int)) else item.get("id")
                if item_id is not None:
                    b["items_per_champion"][cid][item_id] += 1
    return dict(buckets)
