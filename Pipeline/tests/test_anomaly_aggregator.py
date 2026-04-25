"""Unit tests for anomaly_aggregator.aggregate_anomalies().

Uses minimal synthetic participant dicts — no live API, no large fixtures.
"""
from __future__ import annotations

import pytest
from tftmac_pipeline.anomaly_aggregator import aggregate_anomalies


def _make_participant(anomaly_ids: list[str]) -> dict:
    """Build a minimal participant dict with anomaly items on unit 0."""
    return {
        "placement": 1,
        "units": [{"character_id": "TFT17_Viktor", "itemNames": anomaly_ids, "rarity": 4, "tier": 2}],
    }


class TestAggregateAnomalies:
    def test_empty_participants_returns_empty(self) -> None:
        result = aggregate_anomalies([], sample_size=0)
        assert result == []

    def test_no_anomaly_items_returns_empty(self) -> None:
        participants = [
            _make_participant(["TFT_Item_JeweledGauntlet"]),
            _make_participant(["TFT_Item_InfinityEdge"]),
        ]
        result = aggregate_anomalies(participants, sample_size=2)
        assert result == []

    def test_single_anomaly_above_threshold(self) -> None:
        # 4 out of 5 participants carry same anomaly → agreement=0.80
        anomaly = "TFT17_EkkoOffering_AnomalyItem"
        participants = [_make_participant([anomaly])] * 4 + [_make_participant([])]
        result = aggregate_anomalies(participants, sample_size=5)
        assert len(result) == 1
        assert result[0]["id"] == anomaly
        assert abs(result[0]["agreement"] - 0.8) < 0.001

    def test_anomaly_below_threshold_excluded(self) -> None:
        # 1 out of 5 → agreement=0.20 < 0.40
        anomaly = "TFT17_EkkoOffering_AnomalyItem"
        participants = [_make_participant([anomaly])] + [_make_participant([])] * 4
        result = aggregate_anomalies(participants, sample_size=5)
        assert result == []

    def test_exactly_at_threshold_included(self) -> None:
        # 2 out of 5 → agreement=0.40 (exact boundary — should include)
        anomaly = "TFT17_EkkoOffering_AnomalyItem"
        participants = [_make_participant([anomaly])] * 2 + [_make_participant([])] * 3
        result = aggregate_anomalies(participants, sample_size=5)
        assert len(result) == 1
        assert abs(result[0]["agreement"] - 0.4) < 0.001

    def test_top_3_cap(self) -> None:
        # 4 different anomalies all above threshold — only top 3 returned
        sample_size = 10
        participants = (
            [_make_participant(["TFT17_EkkoOffering_A"])] * 8 +
            [_make_participant(["TFT17_EkkoOffering_B"])] * 7 +
            [_make_participant(["TFT17_EkkoOffering_C"])] * 6 +
            [_make_participant(["TFT17_EkkoOffering_D"])] * 5
        )
        result = aggregate_anomalies(participants, sample_size=sample_size)
        assert len(result) <= 3

    def test_sorted_by_agreement_descending(self) -> None:
        # A: 8/10=0.80, B: 6/10=0.60, C: 5/10=0.50
        sample_size = 10
        participants = (
            [_make_participant(["TFT17_EkkoOffering_A"])] * 8 +
            [_make_participant(["TFT17_EkkoOffering_B"])] * 6 +
            [_make_participant(["TFT17_EkkoOffering_C"])] * 5
        )
        result = aggregate_anomalies(participants, sample_size=sample_size)
        agreements = [r["agreement"] for r in result]
        assert agreements == sorted(agreements, reverse=True)

    def test_non_anomaly_items_ignored(self) -> None:
        participants = [
            _make_participant(["TFT_Item_JeweledGauntlet", "TFT17_Item_Something"]),
        ] * 5
        result = aggregate_anomalies(participants, sample_size=5)
        assert result == []

    def test_agreement_rounded_to_4_decimal_places(self) -> None:
        # 1/3 = 0.3333... → rounds to 0.3333
        anomaly = "TFT17_EkkoOffering_AnomalyItem"
        participants = [_make_participant([anomaly])] * 2 + [_make_participant([])] * 1
        # sample_size=3, count=2, agreement=0.6667
        result = aggregate_anomalies(participants, sample_size=3)
        if result:
            assert result[0]["agreement"] == round(2 / 3, 4)

    def test_sample_size_zero_returns_empty(self) -> None:
        participants = [_make_participant(["TFT17_EkkoOffering_AnomalyItem"])]
        result = aggregate_anomalies(participants, sample_size=0)
        assert result == []

    def test_result_contains_id_and_agreement_keys(self) -> None:
        anomaly = "TFT17_EkkoOffering_AnomalyItem"
        participants = [_make_participant([anomaly])] * 3
        result = aggregate_anomalies(participants, sample_size=3)
        assert len(result) == 1
        assert "id" in result[0]
        assert "agreement" in result[0]
        assert result[0]["id"] == anomaly
