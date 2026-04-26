"""Unit tests for tier_calculator.classify() — pure function, no fixtures needed.

Covers all tier thresholds + boundary values + None (insufficient sample).
"""
from __future__ import annotations

import pytest
from tftmac_pipeline.tier_calculator import Tier, classify


class TestClassifyTierS:
    def test_s_tier_all_thresholds_met(self) -> None:
        result = classify(play_rate=0.10, avg_placement=3.7, sample_size=100)
        assert result == Tier.S

    def test_s_tier_exact_boundary(self) -> None:
        # New thresholds (Bug #C1 retune): S = play_rate >= 0.05 AND avg_placement <= 4.3 AND sample_size >= 50
        result = classify(play_rate=0.05, avg_placement=4.3, sample_size=50)
        assert result == Tier.S

    def test_s_tier_play_rate_just_below_falls_to_a(self) -> None:
        # play_rate 0.049 < 0.05 → cannot be S; check it falls to A if other A thresholds met
        result = classify(play_rate=0.049, avg_placement=4.0, sample_size=50)
        assert result == Tier.A

    def test_s_tier_placement_just_above_boundary_falls_to_b(self) -> None:
        # avg_placement 4.31 > 4.3 → cannot be S; A also requires avg <= 4.3, so falls to B
        result = classify(play_rate=0.10, avg_placement=4.31, sample_size=50)
        assert result == Tier.B

    def test_s_tier_sample_below_50_cannot_be_s(self) -> None:
        result = classify(play_rate=0.10, avg_placement=3.7, sample_size=49)
        assert result != Tier.S


class TestClassifyTierA:
    def test_a_tier_exact_boundary(self) -> None:
        # New thresholds: A = play_rate >= 0.03 AND avg_placement <= 4.3 AND sample_size >= 50
        result = classify(play_rate=0.03, avg_placement=4.3, sample_size=50)
        assert result == Tier.A

    def test_a_tier_strong_play_rate(self) -> None:
        result = classify(play_rate=0.04, avg_placement=4.2, sample_size=50)
        assert result == Tier.A

    def test_a_tier_placement_just_above_falls_to_b(self) -> None:
        result = classify(play_rate=0.03, avg_placement=4.31, sample_size=50)
        assert result == Tier.B


class TestClassifyTierB:
    def test_b_tier_exact_boundary(self) -> None:
        # New thresholds: B = play_rate >= 0.015 AND avg_placement <= 4.6 AND sample_size >= 50
        result = classify(play_rate=0.015, avg_placement=4.6, sample_size=50)
        assert result == Tier.B

    def test_b_tier_placement_just_above_falls_to_c(self) -> None:
        result = classify(play_rate=0.015, avg_placement=4.61, sample_size=50)
        assert result == Tier.C

    def test_b_tier_sample_below_50_falls_to_c(self) -> None:
        result = classify(play_rate=0.015, avg_placement=4.6, sample_size=49)
        assert result == Tier.C


class TestClassifyTierC:
    def test_c_tier_low_play_rate(self) -> None:
        result = classify(play_rate=0.01, avg_placement=5.0, sample_size=50)
        assert result == Tier.C

    def test_c_tier_exact_minimum_sample(self) -> None:
        result = classify(play_rate=0.01, avg_placement=6.0, sample_size=50)
        assert result == Tier.C

    def test_c_tier_high_placement_poor_performance(self) -> None:
        result = classify(play_rate=0.02, avg_placement=6.5, sample_size=50)
        assert result == Tier.C


class TestClassifyInsufficientData:
    def test_c_when_sample_below_50(self) -> None:
        # New rule: sample_size < 50 → C (too small to trust for higher tier)
        result = classify(play_rate=0.20, avg_placement=2.0, sample_size=49)
        assert result == Tier.C

    def test_c_when_sample_zero(self) -> None:
        result = classify(play_rate=0.0, avg_placement=0.0, sample_size=0)
        assert result == Tier.C

    def test_c_when_sample_exactly_49(self) -> None:
        result = classify(play_rate=0.10, avg_placement=3.5, sample_size=49)
        assert result == Tier.C

    def test_not_c_for_strong_comp_at_sample_50(self) -> None:
        result = classify(play_rate=0.10, avg_placement=3.5, sample_size=50)
        assert result == Tier.S


class TestClassifyReturnTypes:
    def test_returns_tier_enum(self) -> None:
        result = classify(play_rate=0.10, avg_placement=3.7, sample_size=100)
        assert isinstance(result, Tier)

    def test_tier_value_is_string(self) -> None:
        result = classify(play_rate=0.10, avg_placement=3.7, sample_size=100)
        assert isinstance(result.value, str)
        assert result.value in ("S", "A", "B", "C")


class TestBugC1RelaxedThresholds:
    """Bug #C1 — VN2 meta needs ≥5% play / ≤4.3 avg for S (no live comp hits 4.0)."""

    def test_s_tier_emitted_with_relaxed_threshold(self) -> None:
        # Top S candidate from live VN2 data: Illaoi+Nami+Rhaast+Summon+Viktor
        # play_rate 7.32%, avg_placement 4.28, sample 307 → previously not S, now S
        result = classify(play_rate=0.0732, avg_placement=4.28, sample_size=307)
        assert result == Tier.S

    def test_s_tier_emitted_when_playrate_5pct_and_avg_under_4_0(self) -> None:
        # Original Bug #C1 case still works (3.95 ≤ 4.3)
        result = classify(play_rate=0.055, avg_placement=3.95, sample_size=200)
        assert result == Tier.S

    def test_a_tier_for_lower_playrate(self) -> None:
        result = classify(play_rate=0.03, avg_placement=4.20, sample_size=150)
        assert result == Tier.A
