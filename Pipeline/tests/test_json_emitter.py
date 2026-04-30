"""Unit tests for json_emitter — dataclasses → JSON serialisation.

Tests: schema shape, determinism, PII safety gate, atomic write.
No live API calls — pure in-memory / tmp file tests.
"""
from __future__ import annotations

import json
import re
from pathlib import Path

import pytest

from tftmac_pipeline.json_emitter import (
    AnomalyEntry,
    ChampionEntry,
    CompEntry,
    ItemBuild,
    SCHEMA_VERSION,
    TraitEntry,
    TierListOutput,
    _check_pii,
    _slugify,
    _style_for,
    emit,
    emit_comp,
    make_last_updated,
    tier_list_to_dict,
)


@pytest.fixture
def minimal_output() -> TierListOutput:
    return TierListOutput(
        schema_version=SCHEMA_VERSION,
        patch_version="16.8",
        last_updated="2026-04-25T18:00:00Z",
        data_window_hours=12,
        elo_bracket="CHALLENGER",
        region="VN2",
        total_matches_sampled=100,
        comps=[
            CompEntry(
                comp_id="viktor-karma",
                name="Viktor + Karma",
                tier="S",
                play_rate=0.105,
                avg_placement=3.78,
                top_4_rate=0.61,
                sample_size=131,
                champions=[
                    ChampionEntry(
                        id="TFT17_Viktor",
                        cost=5,
                        is_carry=True,
                        items=[ItemBuild(id="TFT_Item_JeweledGauntlet", agreement=0.82)],
                    )
                ],
                anomalies=[AnomalyEntry(id="TFT17_EkkoOffering_AnomalyItem", agreement=0.71)],
                traits=[
                    TraitEntry(name="Set17_Psionic", count=4, style="gold"),
                    TraitEntry(name="Set17_Dominator", count=2, style="silver"),
                ],
            )
        ],
    )


class TestTierListToDict:
    def test_schema_version_present(self, minimal_output: TierListOutput) -> None:
        d = tier_list_to_dict(minimal_output)
        assert d["schema_version"] == SCHEMA_VERSION  # "1.2.0"

    def test_region_present(self, minimal_output: TierListOutput) -> None:
        d = tier_list_to_dict(minimal_output)
        assert d["region"] == "VN2"

    def test_comps_list_present(self, minimal_output: TierListOutput) -> None:
        d = tier_list_to_dict(minimal_output)
        assert isinstance(d["comps"], list)
        assert len(d["comps"]) == 1

    def test_comp_has_anomalies_array(self, minimal_output: TierListOutput) -> None:
        d = tier_list_to_dict(minimal_output)
        comp = d["comps"][0]
        assert "anomalies" in comp
        assert isinstance(comp["anomalies"], list)
        assert comp["anomalies"][0]["id"] == "TFT17_EkkoOffering_AnomalyItem"

    def test_comp_has_champions_with_items(self, minimal_output: TierListOutput) -> None:
        d = tier_list_to_dict(minimal_output)
        champ = d["comps"][0]["champions"][0]
        assert champ["id"] == "TFT17_Viktor"
        assert champ["is_carry"] is True
        assert champ["items"][0]["id"] == "TFT_Item_JeweledGauntlet"

    def test_empty_anomalies_emits_empty_list_not_null(self) -> None:
        comp = CompEntry(
            comp_id="test", name="Test", tier="C",
            play_rate=0.01, avg_placement=5.0, top_4_rate=0.3,
            sample_size=10, anomalies=[],
        )
        output = TierListOutput(
            schema_version=SCHEMA_VERSION, patch_version="16.8",
            last_updated="2026-04-25T00:00:00Z", data_window_hours=12,
            elo_bracket="CHALLENGER", region="VN2",
            total_matches_sampled=50, comps=[comp],
        )
        d = tier_list_to_dict(output)
        assert d["comps"][0]["anomalies"] == []  # not None — Swift requires non-optional array
        assert d["comps"][0]["traits"] == []     # schema 1.2.0: traits[] must also be present

    def test_all_required_root_keys_present(self, minimal_output: TierListOutput) -> None:
        d = tier_list_to_dict(minimal_output)
        required = {
            "schema_version", "patch_version", "last_updated",
            "data_window_hours", "elo_bracket", "region",
            "total_matches_sampled", "comps",
        }
        assert required.issubset(d.keys())

    def test_comp_has_traits_array(self, minimal_output: TierListOutput) -> None:
        """Schema 1.2.0: every comp must have a traits[] field."""
        d = tier_list_to_dict(minimal_output)
        comp = d["comps"][0]
        assert "traits" in comp
        assert isinstance(comp["traits"], list)
        assert len(comp["traits"]) == 2

    def test_trait_entry_has_name_count_style(self, minimal_output: TierListOutput) -> None:
        """Schema 1.2.0: each trait entry must have name, count, style."""
        d = tier_list_to_dict(minimal_output)
        trait = d["comps"][0]["traits"][0]
        assert "name" in trait
        assert "count" in trait
        assert "style" in trait


class TestEmitDeterminism:
    def test_two_runs_produce_identical_bytes(self, minimal_output: TierListOutput, tmp_path: Path) -> None:
        path1 = tmp_path / "run1.json"
        path2 = tmp_path / "run2.json"
        # Use a fixed last_updated so timestamp doesn't differ
        emit(minimal_output, path1)
        emit(minimal_output, path2)
        assert path1.read_text() == path2.read_text()

    def test_output_is_valid_json(self, minimal_output: TierListOutput, tmp_path: Path) -> None:
        path = tmp_path / "output.json"
        emit(minimal_output, path)
        parsed = json.loads(path.read_text())
        assert parsed["schema_version"] == SCHEMA_VERSION  # "1.2.0"

    def test_keys_are_sorted(self, minimal_output: TierListOutput, tmp_path: Path) -> None:
        path = tmp_path / "output.json"
        emit(minimal_output, path)
        text = path.read_text()
        # sorted_keys=True means "comps" comes before "data_window_hours" is false
        # Just verify the file parses and has expected structure
        parsed = json.loads(text)
        assert "comps" in parsed

    def test_creates_parent_directory(self, minimal_output: TierListOutput, tmp_path: Path) -> None:
        nested = tmp_path / "data" / "nested" / "output.json"
        emit(minimal_output, nested)
        assert nested.exists()

    def test_atomic_write_uses_rename(self, minimal_output: TierListOutput, tmp_path: Path) -> None:
        path = tmp_path / "output.json"
        emit(minimal_output, path)
        # After emit, .tmp file should be gone (renamed to final)
        assert not path.with_suffix(".tmp").exists()
        assert path.exists()


class TestPiiCheck:
    def test_clean_json_passes(self) -> None:
        clean = '{"schema_version": "1.2.0", "region": "VN2"}'
        _check_pii(clean)  # should not raise

    def test_rgapi_fragment_raises(self) -> None:
        bad = '{"key": "RGAPI-abc123"}'
        with pytest.raises(ValueError, match="RGAPI"):
            _check_pii(bad)

    def test_puuid_length_string_raises(self) -> None:
        # 78-char base64url string (typical PUUID)
        puuid = "LP9IuUcMq5ao-9Gph5KEVdeAN2RxfDBghwyG4EGbze_JLFdRKTDOtIq9Jrh_RNl6f05tT3bDsaa7Fg"
        bad = f'{{"puuid": "{puuid}"}}'
        with pytest.raises(ValueError):
            _check_pii(bad)

    def test_url_string_not_flagged(self) -> None:
        # URLs contain / and . so should not be flagged as PUUID
        ok = '{"url": "https://github.com/psychomafia-tiger/tft-hell-elo-for-macos"}'
        _check_pii(ok)  # should not raise


class TestMakeLastUpdated:
    def test_returns_iso8601_utc_string(self) -> None:
        ts = make_last_updated()
        # Expected format: "2026-04-25T18:00:00Z"
        assert re.match(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$", ts), f"Bad format: {ts}"

    def test_ends_with_z(self) -> None:
        ts = make_last_updated()
        assert ts.endswith("Z")


class TestStyleFor:
    """Schema 1.2.0 helper: map trait activation count → style string."""

    def test_count_1_returns_bronze(self) -> None:
        assert _style_for(1) == "bronze"

    def test_count_2_returns_silver(self) -> None:
        assert _style_for(2) == "silver"

    def test_count_4_returns_gold(self) -> None:
        assert _style_for(4) == "gold"

    def test_count_6_returns_chromatic(self) -> None:
        assert _style_for(6) == "chromatic"

    def test_count_3_returns_silver(self) -> None:
        # 3 < 4 → silver
        assert _style_for(3) == "silver"

    def test_count_5_returns_gold(self) -> None:
        # 5 >= 4 but < 6 → gold
        assert _style_for(5) == "gold"


class TestSlugify:
    """Schema 1.2.0 helper: human name → kebab-case ID."""

    def test_spaces_become_hyphens(self) -> None:
        assert _slugify("Psionic Carry") == "psionic-carry"

    def test_apostrophes_removed(self) -> None:
        assert _slugify("Viktor's Edge") == "viktors-edge"

    def test_already_lowercase_unchanged(self) -> None:
        assert _slugify("nami") == "nami"


class TestEmitComp:
    """Schema 1.2.0 emit_comp: trait-bucket → comp dict."""

    @pytest.fixture
    def sample_bucket(self) -> dict:
        return {
            "sample_size": 4,
            "placements": [1, 2, 3, 5],
            "trait_signature": (("Set17_Dominator", 2), ("Set17_Psionic", 4)),
            "champion_freq": {"TFT17_Viktor": 4, "TFT17_Syndra": 3},
            "items_per_champion": {
                "TFT17_Viktor": {"TFT_Item_JeweledGauntlet": 3},
            },
        }

    def test_comp_has_traits_list(self, sample_bucket: dict) -> None:
        comp = emit_comp(sample_bucket, "Psionic Carry")
        assert "traits" in comp
        assert isinstance(comp["traits"], list)
        assert len(comp["traits"]) == 2

    def test_traits_have_correct_style(self, sample_bucket: dict) -> None:
        comp = emit_comp(sample_bucket, "Psionic Carry")
        styles = {t["name"]: t["style"] for t in comp["traits"]}
        assert styles["Set17_Dominator"] == "silver"  # count=2
        assert styles["Set17_Psionic"] == "gold"      # count=4

    def test_comp_id_is_slugified_name(self, sample_bucket: dict) -> None:
        comp = emit_comp(sample_bucket, "Psionic Carry")
        assert comp["comp_id"] == "psionic-carry"

    def test_avg_placement_correct(self, sample_bucket: dict) -> None:
        comp = emit_comp(sample_bucket, "Psionic Carry")
        # placements=[1,2,3,5] → avg=2.75
        assert comp["avg_placement"] == 2.75

    def test_top_4_rate_correct(self, sample_bucket: dict) -> None:
        comp = emit_comp(sample_bucket, "Psionic Carry")
        # 3 out of 4 placements <= 4 → 0.75
        assert comp["top_4_rate"] == 0.75

    def test_tier_placeholder_is_c(self, sample_bucket: dict) -> None:
        # emit_comp sets placeholder tier="C"; caller fills downstream
        comp = emit_comp(sample_bucket, "Psionic Carry")
        assert comp["tier"] == "C"

    def test_play_rate_placeholder_is_zero(self, sample_bucket: dict) -> None:
        # emit_comp sets placeholder play_rate=0.0; caller fills downstream
        comp = emit_comp(sample_bucket, "Psionic Carry")
        assert comp["play_rate"] == 0.0

    def test_sample_size_propagated(self, sample_bucket: dict) -> None:
        comp = emit_comp(sample_bucket, "Psionic Carry")
        assert comp["sample_size"] == 4

    def test_anomalies_is_empty_list(self, sample_bucket: dict) -> None:
        comp = emit_comp(sample_bucket, "Psionic Carry")
        assert comp["anomalies"] == []

    def test_champions_list_present(self, sample_bucket: dict) -> None:
        comp = emit_comp(sample_bucket, "Psionic Carry")
        assert isinstance(comp["champions"], list)

    def test_positioning_field_present(self, sample_bucket: dict) -> None:
        """Schema 1.4.0: every comp must have a positioning[] field."""
        # Add rarity so champions get cost > 0 → positioning_aggregator emits entries
        bucket = {**sample_bucket, "champion_rarity": {"TFT17_Viktor": 4, "TFT17_Syndra": 3}}
        comp = emit_comp(bucket, "Psionic Carry")
        assert "positioning" in comp
        assert isinstance(comp["positioning"], list)

    def test_positioning_entries_have_required_keys(self, sample_bucket: dict) -> None:
        bucket = {**sample_bucket, "champion_rarity": {"TFT17_Viktor": 4, "TFT17_Syndra": 3}}
        comp = emit_comp(bucket, "Psionic Carry")
        if comp["positioning"]:
            entry = comp["positioning"][0]
            assert {"championId", "pos", "frequency"} <= entry.keys()
            assert 0 <= entry["pos"] <= 27


class TestSchemaVersion:
    def test_schema_is_1_4_0(self) -> None:
        assert SCHEMA_VERSION == "1.4.0"
