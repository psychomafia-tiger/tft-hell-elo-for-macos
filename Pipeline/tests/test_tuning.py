"""Test suite cho threshold tuning helper (used by scripts/tune_jaccard_threshold.py).

Rationale: đảm bảo agreement_rate calc đúng trước khi founder rely on its output
cho Weekend 0 Action #4 decision gate.
"""
from tftmac_pipeline.tuning import agreement_rate


def test_agreement_perfect_match_returns_one():
    """Predicted groups exactly match hand-labeled → 100% agreement."""
    expected = [
        ["A+B+C", "A+B+C+D", "A+B+C+E"],
        ["X+Y+Z", "X+Y+W"],
    ]
    predicted = [
        {"variants": ["A+B+C", "A+B+C+D", "A+B+C+E"]},
        {"variants": ["X+Y+Z", "X+Y+W"]},
    ]
    assert agreement_rate(expected, predicted) == 1.0


def test_agreement_perfect_split_returns_zero():
    """Expected pairs all split into different predicted groups → 0%."""
    expected = [["A+B+C", "A+B+D"]]  # expected same group
    predicted = [
        {"variants": ["A+B+C"]},
        {"variants": ["A+B+D"]},
    ]
    assert agreement_rate(expected, predicted) == 0.0


def test_agreement_empty_expected_returns_zero():
    """No hand-labels → 0 (caller should abort, but don't crash)."""
    assert agreement_rate([], []) == 0.0


def test_agreement_half_match_returns_half():
    """3 expected pairs, 1 correctly grouped → agreement = 1/3 ≈ 0.333.

    Expected group has A, B, C → 3 pairs: (A,B), (A,C), (B,C).
    Predicted: {A, B} in group 0; C in group 1.
    Same-group pairs in predicted: only (A, B) = 1 hit out of 3.
    """
    expected = [["A+B+C", "A+B+D", "A+B+E"]]
    predicted = [
        {"variants": ["A+B+C", "A+B+D"]},
        {"variants": ["A+B+E"]},
    ]
    result = agreement_rate(expected, predicted)
    assert abs(result - 1.0 / 3.0) < 0.001
