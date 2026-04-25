"""Integration tests for run_aggregator pipeline — uses KR fixture, no live API.

Exercises the full pipeline from raw match list → grouped comps → TierListOutput,
verifying schema shape, PII absence, determinism, and CLI parser.
"""
from __future__ import annotations

import json
from pathlib import Path

import pytest

from tftmac_pipeline.comp_pipeline import (
    build_comp_id,
    build_comp_name,
    build_comps_from_groups,
    derive_patch_version,
    extract_signatures_from_matches,
    run_pipeline,
    signature_for_participant,
)
from tftmac_pipeline.comp_grouping import group_signatures
from tftmac_pipeline.json_emitter import emit, TierListOutput, make_last_updated
from tftmac_pipeline.run_aggregator import build_parser


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def kr_matches(fixtures_dir: Path) -> list[dict]:
    return json.loads((fixtures_dir / "fetched-matches-kr-2026-04-24.json").read_text())


@pytest.fixture
def ranked_kr_matches(kr_matches: list[dict]) -> list[dict]:
    """Ranked-only subset (queue_id=1100). Falls back to all if none ranked."""
    ranked = [m for m in kr_matches if m.get("info", {}).get("queue_id") == 1100]
    return ranked if ranked else kr_matches


# ---------------------------------------------------------------------------
# derive_patch_version
# ---------------------------------------------------------------------------

class TestDerivePatchVersion:
    def test_extracts_major_minor_from_kr_fixture(self, kr_matches: list[dict]) -> None:
        version = derive_patch_version(kr_matches)
        assert version == "16.8"

    def test_empty_list_returns_unknown(self) -> None:
        assert derive_patch_version([]) == "unknown"

    def test_missing_game_version_returns_unknown(self) -> None:
        assert derive_patch_version([{"info": {}}]) == "unknown"


# ---------------------------------------------------------------------------
# signature_for_participant
# ---------------------------------------------------------------------------

class TestSignatureForParticipant:
    def test_returns_string(self, kr_matches: list[dict]) -> None:
        participant = kr_matches[0]["info"]["participants"][0]
        sig = signature_for_participant(participant)
        assert isinstance(sig, str)

    def test_contains_tft17_units_when_present(self, kr_matches: list[dict]) -> None:
        participant = kr_matches[0]["info"]["participants"][0]
        sig = signature_for_participant(participant)
        if sig:  # may be empty if board has only cost-1/2 units
            assert "TFT17_" in sig

    def test_empty_units_returns_empty_string(self) -> None:
        assert signature_for_participant({"units": []}) == ""

    def test_low_cost_units_filtered_out(self) -> None:
        # rarity=0 → cost=1, rarity=1 → cost=2: both below threshold
        participant = {
            "units": [
                {"character_id": "TFT17_Lissandra", "rarity": 0, "tier": 2, "itemNames": []},
                {"character_id": "TFT17_Akali", "rarity": 1, "tier": 1, "itemNames": []},
            ]
        }
        assert signature_for_participant(participant) == ""

    def test_high_cost_units_included(self) -> None:
        # rarity=4 → cost=5: included in signature
        participant = {
            "units": [
                {"character_id": "TFT17_Viktor", "rarity": 4, "tier": 2, "itemNames": []},
            ]
        }
        sig = signature_for_participant(participant)
        assert "TFT17_Viktor" in sig


# ---------------------------------------------------------------------------
# build_comp_name / build_comp_id
# ---------------------------------------------------------------------------

class TestBuildCompName:
    def test_strips_tft17_prefix(self) -> None:
        assert "TFT17_" not in build_comp_name("TFT17_Viktor+TFT17_Karma")

    def test_joins_with_space_plus_space(self) -> None:
        assert " + " in build_comp_name("TFT17_Viktor+TFT17_Karma")

    def test_single_unit(self) -> None:
        assert build_comp_name("TFT17_Viktor") == "Viktor"

    def test_multiple_units_all_stripped(self) -> None:
        name = build_comp_name("TFT17_Viktor+TFT17_Karma+TFT17_Nami")
        assert name == "Viktor + Karma + Nami"


class TestBuildCompId:
    def test_lowercase_kebab(self) -> None:
        assert build_comp_id("TFT17_Viktor+TFT17_KaiSa") == "viktor-kaisa"

    def test_no_set_prefix_in_id(self) -> None:
        cid = build_comp_id("TFT17_Viktor+TFT17_Karma+TFT17_Nami")
        assert "TFT17_" not in cid
        assert "TFT_" not in cid

    def test_single_unit_id(self) -> None:
        assert build_comp_id("TFT17_Viktor") == "viktor"


# ---------------------------------------------------------------------------
# extract_signatures_from_matches
# ---------------------------------------------------------------------------

class TestExtractSignatures:
    def test_returns_tuple_of_list_and_dict(self, ranked_kr_matches: list[dict]) -> None:
        sigs, sig_map = extract_signatures_from_matches(ranked_kr_matches)
        assert isinstance(sigs, list)
        assert isinstance(sig_map, dict)

    def test_all_sigs_are_strings(self, ranked_kr_matches: list[dict]) -> None:
        sigs, _ = extract_signatures_from_matches(ranked_kr_matches)
        assert all(isinstance(s, str) for s in sigs)

    def test_sig_map_values_are_participant_lists(self, ranked_kr_matches: list[dict]) -> None:
        _, sig_map = extract_signatures_from_matches(ranked_kr_matches)
        for participants in sig_map.values():
            assert isinstance(participants, list)
            assert all(isinstance(p, dict) for p in participants)

    def test_total_count_bounded_by_8_per_match(self, ranked_kr_matches: list[dict]) -> None:
        sigs, _ = extract_signatures_from_matches(ranked_kr_matches)
        # Upper bound: 8 participants × n matches (some may have empty sigs)
        assert len(sigs) <= len(ranked_kr_matches) * 8


# ---------------------------------------------------------------------------
# Full pipeline on KR fixture
# ---------------------------------------------------------------------------

class TestPipelineOnKrFixture:
    def test_pipeline_runs_without_error(self, ranked_kr_matches: list[dict]) -> None:
        comps, total_participants, patch = run_pipeline(ranked_kr_matches)
        assert isinstance(comps, list)
        assert isinstance(total_participants, int)
        assert isinstance(patch, str)

    def test_patch_version_from_kr_fixture(self, ranked_kr_matches: list[dict]) -> None:
        _, _, patch = run_pipeline(ranked_kr_matches)
        assert patch == "16.8"

    def test_tier_values_all_valid(self, ranked_kr_matches: list[dict]) -> None:
        comps, _, _ = run_pipeline(ranked_kr_matches)
        valid_tiers = {"S", "A", "B", "C"}
        for comp in comps:
            assert comp.tier in valid_tiers

    def test_comps_sorted_tier_then_play_rate(self, ranked_kr_matches: list[dict]) -> None:
        comps, _, _ = run_pipeline(ranked_kr_matches)
        tier_order = {"S": 0, "A": 1, "B": 2, "C": 3}
        keys = [(tier_order[c.tier], -c.play_rate) for c in comps]
        assert keys == sorted(keys)

    def test_no_puuid_in_emitted_json(self, ranked_kr_matches: list[dict], tmp_path: Path) -> None:
        """PII safety: emitted JSON must contain zero PUUID-like strings."""
        comps, _, patch = run_pipeline(ranked_kr_matches)
        output = TierListOutput(
            schema_version="1.1.0",
            patch_version=patch,
            last_updated="2026-04-25T18:00:00Z",
            data_window_hours=12,
            elo_bracket="CHALLENGER",
            region="KR",
            total_matches_sampled=len(ranked_kr_matches),
            comps=comps,
        )
        out_path = tmp_path / "tier-list.json"
        emit(output, out_path)
        text = out_path.read_text()

        assert "puuid" not in text.lower()
        assert "riotidgamename" not in text.lower()
        assert "RGAPI-" not in text

    def test_output_deterministic(self, ranked_kr_matches: list[dict], tmp_path: Path) -> None:
        """Same fixture + fixed timestamp → byte-identical output on two runs."""
        comps, _, patch = run_pipeline(ranked_kr_matches)

        def _make_output() -> TierListOutput:
            return TierListOutput(
                schema_version="1.1.0",
                patch_version=patch,
                last_updated="2026-04-25T18:00:00Z",
                data_window_hours=12,
                elo_bracket="CHALLENGER",
                region="KR",
                total_matches_sampled=len(ranked_kr_matches),
                comps=comps,
            )

        path1 = tmp_path / "run1.json"
        path2 = tmp_path / "run2.json"
        emit(_make_output(), path1)
        emit(_make_output(), path2)
        assert path1.read_text() == path2.read_text()

    def test_schema_version_in_output(self, ranked_kr_matches: list[dict], tmp_path: Path) -> None:
        comps, _, patch = run_pipeline(ranked_kr_matches)
        output = TierListOutput(
            schema_version="1.1.0",
            patch_version=patch,
            last_updated="2026-04-25T18:00:00Z",
            data_window_hours=12,
            elo_bracket="CHALLENGER",
            region="KR",
            total_matches_sampled=len(ranked_kr_matches),
            comps=comps,
        )
        out_path = tmp_path / "tier-list.json"
        emit(output, out_path)
        parsed = json.loads(out_path.read_text())
        assert parsed["schema_version"] == "1.1.0"
        assert parsed["region"] == "KR"
        assert isinstance(parsed["comps"], list)


# ---------------------------------------------------------------------------
# CLI parser
# ---------------------------------------------------------------------------

class TestBuildParser:
    def test_defaults(self) -> None:
        args = build_parser().parse_args([])
        assert args.output == "data/tier-list.json"
        assert args.max_matches == 1500
        assert args.workers == 2
        assert args.match_ids_per_puuid == 20

    def test_region_override(self) -> None:
        args = build_parser().parse_args(["--region", "kr"])
        assert args.region == "kr"

    def test_output_override(self) -> None:
        args = build_parser().parse_args(["--output", "/tmp/test.json"])
        assert args.output == "/tmp/test.json"

    def test_max_matches_override(self) -> None:
        args = build_parser().parse_args(["--max-matches", "100"])
        assert args.max_matches == 100

    def test_workers_override(self) -> None:
        args = build_parser().parse_args(["--workers", "4"])
        assert args.workers == 4
