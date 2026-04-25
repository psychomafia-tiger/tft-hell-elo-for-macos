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
        result = classify(play_rate=0.08, avg_placement=4.0, sample_size=30)
        assert result == Tier.S

    def test_s_tier_play_rate_just_below_falls_to_a(self) -> None:
        # play_rate 0.079 < 0.08 → cannot be S; check it falls to A if other A thresholds met
        result = classify(play_rate=0.079, avg_placement=4.0, sample_size=30)
        assert result == Tier.A

    def test_s_tier_placement_just_above_boundary_falls_to_a(self) -> None:
        # avg_placement 4.01 > 4.0 → cannot be S
        result = classify(play_rate=0.10, avg_placement=4.01, sample_size=30)
        assert result == Tier.A

    def test_s_tier_sample_below_30_cannot_be_s(self) -> None:
        result = classify(play_rate=0.10, avg_placement=3.7, sample_size=29)
        assert result != Tier.S


class TestClassifyTierA:
    def test_a_tier_exact_boundary(self) -> None:
        result = classify(play_rate=0.05, avg_placement=4.3, sample_size=20)
        assert result == Tier.A

    def test_a_tier_strong_play_rate(self) -> None:
        result = classify(play_rate=0.07, avg_placement=4.2, sample_size=25)
        assert result == Tier.A

    def test_a_tier_placement_just_above_falls_to_b(self) -> None:
        result = classify(play_rate=0.05, avg_placement=4.31, sample_size=20)
        assert result == Tier.B

    def test_a_tier_sample_below_20_cannot_be_a(self) -> None:
        result = classify(play_rate=0.07, avg_placement=4.2, sample_size=19)
        assert result != Tier.A


class TestClassifyTierB:
    def test_b_tier_exact_boundary(self) -> None:
        result = classify(play_rate=0.03, avg_placement=4.5, sample_size=15)
        assert result == Tier.B

    def test_b_tier_placement_just_above_falls_to_c(self) -> None:
        result = classify(play_rate=0.03, avg_placement=4.51, sample_size=15)
        assert result == Tier.C

    def test_b_tier_sample_below_15_falls_to_c(self) -> None:
        result = classify(play_rate=0.03, avg_placement=4.5, sample_size=14)
        assert result == Tier.C


class TestClassifyTierC:
    def test_c_tier_low_play_rate(self) -> None:
        result = classify(play_rate=0.01, avg_placement=5.0, sample_size=10)
        assert result == Tier.C

    def test_c_tier_exact_minimum_sample(self) -> None:
        result = classify(play_rate=0.01, avg_placement=6.0, sample_size=10)
        assert result == Tier.C

    def test_c_tier_high_placement_poor_performance(self) -> None:
        result = classify(play_rate=0.02, avg_placement=6.5, sample_size=12)
        assert result == Tier.C


class TestClassifyInsufficientData:
    def test_none_when_sample_below_10(self) -> None:
        result = classify(play_rate=0.20, avg_placement=2.0, sample_size=9)
        assert result is None

    def test_none_when_sample_zero(self) -> None:
        result = classify(play_rate=0.0, avg_placement=0.0, sample_size=0)
        assert result is None

    def test_none_when_sample_exactly_9(self) -> None:
        result = classify(play_rate=0.10, avg_placement=3.5, sample_size=9)
        assert result is None

    def test_not_none_when_sample_exactly_10(self) -> None:
        result = classify(play_rate=0.01, avg_placement=6.0, sample_size=10)
        assert result is not None


class TestClassifyReturnTypes:
    def test_returns_tier_enum(self) -> None:
        result = classify(play_rate=0.10, avg_placement=3.7, sample_size=100)
        assert isinstance(result, Tier)

    def test_tier_value_is_string(self) -> None:
        result = classify(play_rate=0.10, avg_placement=3.7, sample_size=100)
        assert isinstance(result.value, str)
        assert result.value in ("S", "A", "B", "C")
