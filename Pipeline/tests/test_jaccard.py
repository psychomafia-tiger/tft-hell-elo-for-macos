"""Test suite cho Jaccard similarity — foundation cho comp grouping."""
from tftmac_pipeline.jaccard import jaccard_similarity


def test_jaccard_empty_sets_returns_zero():
    """Empty sets = undefined mathematically (0/0); contract: return 0.0."""
    assert jaccard_similarity(set(), set()) == 0.0


def test_jaccard_identical_sets_returns_one():
    """Full overlap → 1.0."""
    units = {"Aatrox", "Sivir", "Kai'Sa"}
    assert jaccard_similarity(units, units) == 1.0


def test_jaccard_disjoint_sets_returns_zero():
    """No overlap → 0.0 (characterization test — locks contract)."""
    a = {"Aatrox", "Sivir"}
    b = {"Xerath", "Yasuo"}
    assert jaccard_similarity(a, b) == 0.0


def test_jaccard_spec_below_threshold_example():
    """Spec §Step 2 exact numbers: intersect=4, union=6 → 4/6 ≈ 0.667.

    A = {Aatrox, Kai'Sa, Sivir, Xerath, Yasuo}
    B = {Aatrox, Kai'Sa, Sivir, Syndra, Yasuo}  (Xerath ↔ Syndra swap)
    Per spec, 0.667 < 0.70 threshold → NOT merge.
    """
    a = {"Aatrox", "Kai'Sa", "Sivir", "Xerath", "Yasuo"}
    b = {"Aatrox", "Kai'Sa", "Sivir", "Syndra", "Yasuo"}
    assert abs(jaccard_similarity(a, b) - 0.667) < 0.001


def test_jaccard_above_threshold_83_percent():
    """5 of 6 units overlap → 5/6 ≈ 0.833. Above 0.70 threshold → merge.

    A = {Aatrox, Kai'Sa, Sivir, Xerath, Yasuo} (5 units)
    B = {Aatrox, Kai'Sa, Sivir, Xerath, Yasuo, Syndra} (6 units, superset of A)
    |A∩B|=5, |A∪B|=6.
    """
    a = {"Aatrox", "Kai'Sa", "Sivir", "Xerath", "Yasuo"}
    b = {"Aatrox", "Kai'Sa", "Sivir", "Xerath", "Yasuo", "Syndra"}
    assert abs(jaccard_similarity(a, b) - 0.833) < 0.001
