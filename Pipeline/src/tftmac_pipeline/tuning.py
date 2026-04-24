"""Threshold tuning helpers cho Weekend 0 Action #4 decision gate.

agreement_rate quantifies "% of hand-labeled same-group pairs that ended up
in the same predicted group". Higher = algorithm matches human intuition better.
"""


def agreement_rate(
    expected_groups: list[list[str]],
    predicted_groups: list[dict],
) -> float:
    """% of hand-labeled pairs that predicted grouping agrees with.

    Args:
        expected_groups: List of lists — each inner list = signatures that
            human labels as "same comp".
        predicted_groups: List of group dicts từ `group_signatures()` —
            each has `variants` key.

    Returns:
        Float in [0.0, 1.0]. 1.0 = perfect agreement. 0.0 = no hand-labels
        OR algorithm split every pair apart.

    **Ví dụ concrete**:
        expected = [["A", "B", "C"]]  # 1 group, 3 signatures → 3 pairs
        predicted = [{variants: ["A", "B"]}, {variants: ["C"]}]
                    # Predicted: A+B same group, C alone
        Pair (A,B): same predicted group ✓
        Pair (A,C): different ✗
        Pair (B,C): different ✗
        Agreement = 1/3 = 0.333
    """
    if not expected_groups:
        return 0.0

    # Build signature → predicted_group_id lookup
    sig_to_predicted_id: dict[str, int] = {}
    for i, group in enumerate(predicted_groups):
        for sig in group["variants"]:
            sig_to_predicted_id[sig] = i

    hits = 0
    total = 0
    for expected_grp in expected_groups:
        for i, sig1 in enumerate(expected_grp):
            for sig2 in expected_grp[i + 1:]:
                total += 1
                if sig_to_predicted_id.get(sig1) == sig_to_predicted_id.get(sig2):
                    hits += 1

    return hits / total if total else 0.0
