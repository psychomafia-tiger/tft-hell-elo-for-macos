"""Parse Riot TFT Match-v5 sample against Phase 0 schema assumptions.

Fixture: tests/fixtures/sample-participant.json (real Challenger data, KR, 2026-04-24).
Reference checklist: docs/pre-spike-api-verify.md.

These tests lock in the actual schema shape as of TFT Set 17 so any upstream
Riot schema change will break tests immediately rather than producing bad
tier-list output silently.
"""
from __future__ import annotations

import json
from pathlib import Path

import pytest


@pytest.fixture
def participant(fixtures_dir: Path) -> dict:
    return json.loads((fixtures_dir / "sample-participant.json").read_text())


@pytest.fixture
def matches(fixtures_dir: Path) -> list[dict]:
    return json.loads((fixtures_dir / "fetched-matches-kr-2026-04-24.json").read_text())


def test_participant_has_units_list(participant: dict) -> None:
    assert isinstance(participant.get("units"), list)
    assert len(participant["units"]) >= 1


def test_unit_has_character_id_string(participant: dict) -> None:
    unit = participant["units"][0]
    assert isinstance(unit.get("character_id"), str)
    assert unit["character_id"].startswith("TFT"), f"Unexpected character_id format: {unit['character_id']}"


def test_unit_has_integer_tier(participant: dict) -> None:
    unit = participant["units"][0]
    assert isinstance(unit.get("tier"), int)
    assert 1 <= unit["tier"] <= 3, "Tier out of expected star-level range"


def test_unit_has_integer_rarity(participant: dict) -> None:
    unit = participant["units"][0]
    assert isinstance(unit.get("rarity"), int)
    assert 0 <= unit["rarity"] <= 9, "Rarity out of expected range"


def test_unit_has_item_names_list(participant: dict) -> None:
    unit = participant["units"][0]
    assert isinstance(unit.get("itemNames"), list)


def test_participant_has_integer_placement(participant: dict) -> None:
    assert isinstance(participant.get("placement"), int)
    assert 1 <= participant["placement"] <= 8


def test_participant_has_traits_list(participant: dict) -> None:
    assert isinstance(participant.get("traits"), list)
    assert len(participant["traits"]) >= 1
    trait = participant["traits"][0]
    assert isinstance(trait.get("name"), str)
    assert isinstance(trait.get("num_units"), int)
    assert isinstance(trait.get("tier_current"), int)


def test_augments_field_absent_in_set_17(participant: dict) -> None:
    """Locked-in finding from F3: Set 17 Match-v5 response omits augments entirely.

    Spec §Feature 2 (Augment Cheat Sheet) assumed augments exist. Reality deviates.
    This test documents the deviation so the decision is visible, not silent.
    """
    assert "augments" not in participant, (
        "augments field returned! Spec §Feature 2 may be buildable — revisit scope decision."
    )


def test_match_is_tft_set_17(matches: list[dict]) -> None:
    """Lock in current TFT set number. Spec was written against Set 14 assumptions."""
    assert matches, "fixture should contain matches"
    for m in matches:
        assert m["info"]["tft_set_number"] == 17
        assert m["info"]["tft_set_core_name"] == "TFTSet17"


def test_character_ids_use_set_17_prefix(matches: list[dict]) -> None:
    """Character IDs are TFT17_*, not TFT14_* as spec hardcoded examples suggested."""
    for m in matches[:5]:
        for p in m["info"]["participants"]:
            for u in p["units"]:
                assert u["character_id"].startswith("TFT17_"), (
                    f"Non-Set-17 unit found: {u['character_id']}"
                )


def test_item_names_use_known_tft_prefix(matches: list[dict]) -> None:
    """Items carry a TFT{set}_{category}_ or TFT_Item_ prefix.

    Taxonomy observed in 98 KR matches:
      TFT_Item_*          core (InfinityEdge, etc.) — stable across sets
      TFT{N}_Item_*       set-scoped items, N = set number (emblems, radiants, Ornn)
      TFT17_EkkoOffering_*  Set 17 Anomaly mechanic (possible augment analog)
      TFT17_AnimaSquadItem_* trait-specific items (Anima Squad trait)

    Schema check: start with 'TFT', contain '_'. Category-specific logic lives
    elsewhere (item classifier), not here.
    """
    saw_any_item = False
    for m in matches:
        for p in m["info"]["participants"]:
            for u in p["units"]:
                for item in u.get("itemNames", []):
                    saw_any_item = True
                    assert item.startswith("TFT"), f"Item doesn't start with TFT: {item}"
                    assert "_" in item, f"Item missing category separator: {item}"
    assert saw_any_item, "expected at least one equipped item across 98 matches"


def test_set_17_ekko_offering_items_present(matches: list[dict]) -> None:
    """TFT17_EkkoOffering_* items appear in Set 17 — likely the Anomaly/augment analog.

    Lock this presence in so Phase 1 scope decision about Feature 2 (cheat sheet)
    can pivot to Anomaly cheat sheet instead of Augment cheat sheet if needed.
    """
    offering_count = 0
    for m in matches:
        for p in m["info"]["participants"]:
            for u in p["units"]:
                for item in u.get("itemNames", []):
                    if item.startswith("TFT17_EkkoOffering_"):
                        offering_count += 1
    assert offering_count > 0, (
        "No EkkoOffering items found — Anomaly mechanic may be queue-scoped or removed."
    )


def test_queue_ids_are_tft_standard(matches: list[dict]) -> None:
    """Queue 1100 = Ranked TFT, 1090 = Normal TFT. Both valid data sources."""
    for m in matches:
        assert m["info"]["queue_id"] in {1090, 1100}, (
            f"Unexpected queue_id: {m['info'].get('queue_id')}"
        )


def test_extract_signature_works_on_real_set_17_data(matches: list[dict]) -> None:
    """Pipe real Set 17 units through signature extractor — it's set-agnostic so should work."""
    from tftmac_pipeline.comp_signature import extract_signature

    participant = matches[0]["info"]["participants"][0]
    units_spec_shape = [
        {"id": u["character_id"], "cost": u["rarity"] + 1}
        for u in participant["units"]
    ]
    signature = extract_signature(units_spec_shape)
    assert isinstance(signature, str)
