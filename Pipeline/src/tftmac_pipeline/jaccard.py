"""Jaccard similarity — foundation cho comp grouping (spec §Step 2)."""


def jaccard_similarity(a: set[str], b: set[str]) -> float:
    """Compute Jaccard similarity coefficient between two sets of unit IDs.

    Formula: |A ∩ B| / |A ∪ B|

    Returns 0.0 for two empty sets (contract choice vs mathematical 0/0).
    """
    if not a and not b:
        return 0.0
    intersect = len(a & b)
    union = len(a | b)
    return intersect / union if union else 0.0
