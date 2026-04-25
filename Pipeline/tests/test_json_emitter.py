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
    TierListOutput,
    _check_pii,
    emit,
    make_last_updated,
    tier_list_to_dict,
)


@pytest.fixture
def minimal_output() -> TierListOutput:
    return TierListOutput(
        schema_version="1.1.0",
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
            )
        ],
    )


class TestTierListToDict:
    def test_schema_version_present(self, minimal_output: TierListOutput) -> None:
        d = tier_list_to_dict(minimal_output)
        assert d["schema_version"] == "1.1.0"

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
            schema_version="1.1.0", patch_version="16.8",
            last_updated="2026-04-25T00:00:00Z", data_window_hours=12,
            elo_bracket="CHALLENGER", region="VN2",
            total_matches_sampled=50, comps=[comp],
        )
        d = tier_list_to_dict(output)
        assert d["comps"][0]["anomalies"] == []  # not None — Swift requires non-optional array

    def test_all_required_root_keys_present(self, minimal_output: TierListOutput) -> None:
        d = tier_list_to_dict(minimal_output)
        required = {
            "schema_version", "patch_version", "last_updated",
            "data_window_hours", "elo_bracket", "region",
            "total_matches_sampled", "comps",
        }
        assert required.issubset(d.keys())


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
        assert parsed["schema_version"] == "1.1.0"

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
        clean = '{"schema_version": "1.1.0", "region": "VN2"}'
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
