"""Unit tests for Bug #005 — data-driven star_level in champion aggregation.

Tests:
  - aggregate_champions emits star_level == modal observed tier
  - majority 2-star → star_level 2
  - majority 3-star → star_level 3
  - single appearance defaults to that tier
  - empty participants → []
  - _emit_champions_from_bucket with champion_star_counts → correct star_level
  - _emit_champions_from_bucket without champion_star_counts → default 1
  - _emit_champions_from_bucket cost derivation from rarity (not hardcoded 0)
"""
from __future__ import annotations

import pytest

from tftmac_pipeline.champion_aggregator import aggregate_champions
from tftmac_pipeline.json_emitter import _emit_champions_from_bucket


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_unit(character_id: str, tier: int = 1, rarity: int = 0,
               item_names: list[str] | None = None) -> dict:
    return {
        "character_id": character_id,
        "tier": tier,
        "rarity": rarity,
        "itemNames": item_names or [],
    }


def _make_participant(units: list[dict]) -> dict:
    return {"units": units}


# ---------------------------------------------------------------------------
# aggregate_champions — star_level modal tests
# ---------------------------------------------------------------------------

class TestAggregateChampionsStarLevel:

    def test_modal_star_level_2_when_majority_at_tier_2(self):
        """Viktor appears 10× at tier=2, 2× at tier=1 → modal = 2."""
        participants = (
            [_make_participant([_make_unit("TFT17_Viktor", tier=2)])] * 10
            + [_make_participant([_make_unit("TFT17_Viktor", tier=1)])] * 2
        )
        result = aggregate_champions(participants)
        assert len(result) == 1
        champion = result[0]
        assert champion["id"] == "TFT17_Viktor"
        assert champion["star_level"] == 2

    def test_modal_star_level_3_when_majority_at_tier_3(self):
        """Jinx appears 7× at tier=3, 3× at tier=2 → modal = 3."""
        participants = (
            [_make_participant([_make_unit("TFT17_Jinx", tier=3)])] * 7
            + [_make_participant([_make_unit("TFT17_Jinx", tier=2)])] * 3
        )
        result = aggregate_champions(participants)
        assert len(result) == 1
        assert result[0]["star_level"] == 3

    def test_modal_star_level_1_for_filler_unit(self):
        """Support champion always at tier=1 → star_level=1."""
        participants = [
            _make_participant([_make_unit("TFT17_Nami", tier=1)])
        ] * 5
        result = aggregate_champions(participants)
        assert len(result) == 1
        assert result[0]["star_level"] == 1

    def test_single_appearance_uses_that_tier(self):
        """Single observation at tier=3 → star_level=3."""
        participants = [_make_participant([_make_unit("TFT17_Aatrox", tier=3)])]
        result = aggregate_champions(participants)
        assert len(result) == 1
        assert result[0]["star_level"] == 3

    def test_empty_participants_returns_empty_list(self):
        assert aggregate_champions([]) == []

    def test_star_level_field_present_in_all_champions(self):
        """Every champion dict in result must have star_level key."""
        participants = [
            _make_participant([
                _make_unit("TFT17_Viktor", tier=2, rarity=4),
                _make_unit("TFT17_Nami", tier=1, rarity=1),
                _make_unit("TFT17_Jinx", tier=3, rarity=3),
            ])
        ] * 5
        result = aggregate_champions(participants)
        for champ in result:
            assert "star_level" in champ, f"Missing star_level in {champ['id']}"

    def test_star_level_independent_of_is_carry(self):
        """star_level reflects observed tier, not derived from is_carry."""
        # avg tier=1.5 → is_carry=False, but modal=2 should still be emitted
        participants = (
            [_make_participant([_make_unit("TFT17_Lissandra", tier=2, rarity=0)])] * 3
            + [_make_participant([_make_unit("TFT17_Lissandra", tier=1, rarity=0)])] * 5
        )
        result = aggregate_champions(participants)
        assert len(result) == 1
        champ = result[0]
        # avg_tier = (2*3 + 1*5)/8 = 1.625 → is_carry=False
        assert champ["is_carry"] is False
        # modal = 1 (appeared 5×)
        assert champ["star_level"] == 1


# ---------------------------------------------------------------------------
# _emit_champions_from_bucket — star_level + cost fix
# ---------------------------------------------------------------------------

class TestEmitChampionsFromBucket:

    def _make_bucket(self, champ_id: str = "TFT17_Viktor",
                     freq: int = 10, sample_size: int = 10,
                     rarity: int | None = None,
                     star_counts: dict[int, int] | None = None) -> dict:
        bucket: dict = {
            "sample_size": sample_size,
            "champion_freq": {champ_id: freq},
            "items_per_champion": {},
        }
        if rarity is not None:
            bucket["champion_rarity"] = {champ_id: rarity}
        if star_counts is not None:
            bucket["champion_star_counts"] = {champ_id: star_counts}
        return bucket

    def test_star_level_from_counts_modal(self):
        """champion_star_counts provided → modal value used."""
        bucket = self._make_bucket(
            star_counts={1: 2, 2: 7, 3: 1}
        )
        result = _emit_champions_from_bucket(bucket)
        assert len(result) == 1
        assert result[0]["star_level"] == 2

    def test_star_level_defaults_to_1_when_no_counts(self):
        """No champion_star_counts key → star_level = 1."""
        bucket = self._make_bucket()
        result = _emit_champions_from_bucket(bucket)
        assert len(result) == 1
        assert result[0]["star_level"] == 1

    def test_star_level_3_modal(self):
        """Majority 3-star → star_level = 3."""
        bucket = self._make_bucket(star_counts={2: 2, 3: 8})
        result = _emit_champions_from_bucket(bucket)
        assert result[0]["star_level"] == 3

    def test_cost_derived_from_rarity(self):
        """rarity=4 → cost=5 (not the old hardcoded 0)."""
        bucket = self._make_bucket(rarity=4)
        result = _emit_champions_from_bucket(bucket)
        assert result[0]["cost"] == 5

    def test_cost_defaults_to_1_when_no_rarity(self):
        """No champion_rarity → cost=1 (not 0)."""
        bucket = self._make_bucket()
        result = _emit_champions_from_bucket(bucket)
        assert result[0]["cost"] == 1

    def test_cost_rarity_0_gives_cost_1(self):
        """rarity=0 (e.g. Lissandra) → cost=1."""
        bucket = self._make_bucket(rarity=0)
        result = _emit_champions_from_bucket(bucket)
        assert result[0]["cost"] == 1

    def test_cost_rarity_6_gives_cost_7(self):
        """rarity=6 (special Blitzcrank-style) → cost=7."""
        bucket = self._make_bucket(rarity=6)
        result = _emit_champions_from_bucket(bucket)
        assert result[0]["cost"] == 7

    def test_star_level_key_always_present(self):
        """star_level key must be present regardless of bucket shape."""
        bucket = self._make_bucket()
        result = _emit_champions_from_bucket(bucket)
        for champ in result:
            assert "star_level" in champ

    def test_empty_bucket_returns_empty(self):
        bucket = {"sample_size": 10, "champion_freq": {}, "items_per_champion": {}}
        result = _emit_champions_from_bucket(bucket)
        assert result == []
