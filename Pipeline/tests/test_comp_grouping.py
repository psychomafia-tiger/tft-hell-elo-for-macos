"""Test suite cho comp_grouping — Jaccard-based signature merging."""
from tftmac_pipeline.comp_grouping import group_signatures


def test_single_signature_produces_one_group():
    """Single observation → 1 group, frequency 1."""
    sigs = ["Aatrox+Sivir+Yasuo"]
    groups = group_signatures(sigs, threshold=0.70)
    assert len(groups) == 1
    assert groups[0]["canonical"] == "Aatrox+Sivir+Yasuo"
    assert groups[0]["frequency"] == 1


def test_identical_signatures_merge_by_count():
    """Same signature repeated → single group với frequency = count."""
    sigs = ["Aatrox+Sivir+Yasuo"] * 3
    groups = group_signatures(sigs, threshold=0.70)
    assert len(groups) == 1
    assert groups[0]["frequency"] == 3


def test_similar_above_threshold_merges_into_canonical():
    """Jaccard 0.833 ≥ 0.70 threshold → merge variant into canonical.

    Most frequent signature wins canonical slot.
    5/6 overlap (5-unit A in 6-unit B-superset) = 0.833.
    """
    base = "Aatrox+Kai'Sa+Sivir+Xerath+Yasuo"         # freq 2
    variant = "Aatrox+Kai'Sa+Sivir+Xerath+Yasuo+Syndra"  # freq 1
    sigs = [base, base, variant]
    groups = group_signatures(sigs, threshold=0.70)
    assert len(groups) == 1
    assert groups[0]["canonical"] == base          # most frequent
    assert groups[0]["frequency"] == 3             # merged
    assert set(groups[0]["variants"]) == {base, variant}


def test_below_threshold_stays_separate_groups():
    """Jaccard < threshold → 2 distinct groups.

    A = {Aatrox, Kai'Sa, Sivir, Xerath, Yasuo}
    B = {Aatrox, Kai'Sa, Sivir, Syndra, Yone}
    A∩B = {Aatrox, Kai'Sa, Sivir} = 3
    A∪B = 7 distinct
    → Jaccard 3/7 ≈ 0.429 < 0.70 threshold → no merge.
    """
    sigs = [
        "Aatrox+Kai'Sa+Sivir+Xerath+Yasuo",
        "Aatrox+Kai'Sa+Sivir+Syndra+Yone",
    ]
    groups = group_signatures(sigs, threshold=0.70)
    assert len(groups) == 2


def test_lower_threshold_merges_more_aggressively():
    """Same input with relaxed threshold → more merges.

    Same 0.429 overlap from above test. Threshold 0.40 → merge (0.429 >= 0.40).
    Validates threshold is a tunable parameter (used by tuning script).
    """
    sigs = [
        "Aatrox+Kai'Sa+Sivir+Xerath+Yasuo",
        "Aatrox+Kai'Sa+Sivir+Syndra+Yone",
    ]
    strict = group_signatures(sigs, threshold=0.70)
    loose = group_signatures(sigs, threshold=0.40)
    assert len(strict) == 2
    assert len(loose) == 1
