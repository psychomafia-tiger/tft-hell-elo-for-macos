"""Rule-based positioning aggregation (Phase 4 fallback).

Riot Match-v5 does not expose unit positions for Set 17. We assign hex positions
deterministically using cost + carry status + active comp traits.

Hex grid: 4 rows × 7 cols = 28 hexes (pos 0-27).
- Row 0 (pos 0-6): backline (carries)
- Row 1 (pos 7-13): mid-back
- Row 2 (pos 14-20): mid-front
- Row 3 (pos 21-27): frontline (tanks)
"""
from tftmac_pipeline.positioning_aggregator import (
    aggregate_positions,
    classify_archetype,
)


# ---------------------------------------------------------------------------
# Archetype classification
# ---------------------------------------------------------------------------


def test_archetype_frontline_heavy_when_tank_trait_active():
    traits = [{"name": "TFT17_HPTank", "count": 3}, {"name": "TFT17_Mecha", "count": 2}]
    assert classify_archetype(traits) == "frontline_heavy"


def test_archetype_backline_heavy_when_ranged_trait_active():
    traits = [{"name": "TFT17_RangedTrait", "count": 4}, {"name": "TFT17_Storm", "count": 2}]
    assert classify_archetype(traits) == "backline_heavy"


def test_archetype_flex_when_no_clear_signal():
    traits = [{"name": "TFT17_AnimaSquad", "count": 3}]
    assert classify_archetype(traits) == "flex"


def test_archetype_frontline_wins_when_both_present():
    """Tie-break: frontline traits dominate (tankier comps prioritise frontline layout)."""
    traits = [
        {"name": "TFT17_ShieldTank", "count": 3},
        {"name": "TFT17_RangedTrait", "count": 2},
    ]
    assert classify_archetype(traits) == "frontline_heavy"


# ---------------------------------------------------------------------------
# Position assignment
# ---------------------------------------------------------------------------


def test_first_carry_lands_center_backline():
    """Single carry should be at pos 3 (row 0, col 3 — dead center backline)."""
    champs = [{"id": "TFT17_Jhin", "cost": 4, "is_carry": True}]
    out = aggregate_positions(champs, traits=[])
    pos = next(p for p in out if p["championId"] == "TFT17_Jhin")
    assert pos["pos"] == 3
    assert pos["frequency"] == 1.0


def test_two_carries_split_backline():
    """Two carries: 1st at pos 3, 2nd at pos 1 (left wing of backline)."""
    champs = [
        {"id": "TFT17_Jhin", "cost": 4, "is_carry": True},
        {"id": "TFT17_Senna", "cost": 4, "is_carry": True},
    ]
    out = aggregate_positions(champs, traits=[])
    by_id = {p["championId"]: p["pos"] for p in out}
    assert by_id["TFT17_Jhin"] == 3
    assert by_id["TFT17_Senna"] == 1


def test_low_cost_units_go_frontline():
    """Cost 1-2 non-carries land in row 3 (pos 21-27)."""
    champs = [
        {"id": "TFT17_Jhin", "cost": 4, "is_carry": True},
        {"id": "TFT17_Maokai", "cost": 2, "is_carry": False},
        {"id": "TFT17_Ezreal", "cost": 1, "is_carry": False},
    ]
    out = aggregate_positions(champs, traits=[])
    by_id = {p["championId"]: p["pos"] for p in out}
    assert 21 <= by_id["TFT17_Maokai"] <= 27
    assert 21 <= by_id["TFT17_Ezreal"] <= 27


def test_no_position_collisions():
    """Distinct champions never share the same hex."""
    champs = [
        {"id": f"TFT17_X{i}", "cost": (i % 5) + 1, "is_carry": (i < 2)}
        for i in range(8)
    ]
    out = aggregate_positions(champs, traits=[])
    positions = [p["pos"] for p in out]
    assert len(positions) == len(set(positions)), f"collision in {positions}"


def test_all_positions_in_valid_range():
    """All assigned positions must satisfy 0 ≤ pos ≤ 27."""
    champs = [
        {"id": "TFT17_A", "cost": 5, "is_carry": True},
        {"id": "TFT17_B", "cost": 4, "is_carry": True},
        {"id": "TFT17_C", "cost": 3, "is_carry": False},
        {"id": "TFT17_D", "cost": 2, "is_carry": False},
        {"id": "TFT17_E", "cost": 1, "is_carry": False},
    ]
    out = aggregate_positions(champs, traits=[])
    for p in out:
        assert 0 <= p["pos"] <= 27, f"out of range: {p}"


def test_backline_heavy_pulls_cost3_to_back():
    """Backline-heavy comps place cost-3 non-carries in row 1 (mid-back)."""
    champs = [
        {"id": "TFT17_Carry", "cost": 5, "is_carry": True},
        {"id": "TFT17_Mid", "cost": 3, "is_carry": False},
    ]
    traits = [{"name": "TFT17_RangedTrait", "count": 4}]
    out = aggregate_positions(champs, traits=traits)
    mid_pos = next(p["pos"] for p in out if p["championId"] == "TFT17_Mid")
    assert 7 <= mid_pos <= 13, f"expected row 1 (7-13), got {mid_pos}"


def test_frontline_heavy_pulls_cost3_to_front():
    """Frontline-heavy comps place cost-3 non-carries in row 2 (mid-front)."""
    champs = [
        {"id": "TFT17_Carry", "cost": 5, "is_carry": True},
        {"id": "TFT17_Mid", "cost": 3, "is_carry": False},
    ]
    traits = [{"name": "TFT17_HPTank", "count": 3}]
    out = aggregate_positions(champs, traits=traits)
    mid_pos = next(p["pos"] for p in out if p["championId"] == "TFT17_Mid")
    assert 14 <= mid_pos <= 20, f"expected row 2 (14-20), got {mid_pos}"


def test_empty_inputs_returns_empty_list():
    assert aggregate_positions([], traits=[]) == []


def test_more_than_eight_champions_capped():
    """Board holds 9 champs at lvl 9; 28 hexes capacity — never exceed."""
    champs = [{"id": f"TFT17_X{i}", "cost": 1, "is_carry": False} for i in range(15)]
    out = aggregate_positions(champs, traits=[])
    # All 15 should fit in 28 hexes without collisions
    assert len(out) == 15
    positions = [p["pos"] for p in out]
    assert len(set(positions)) == 15


def test_skips_champions_missing_id_or_cost():
    champs = [
        {"id": "TFT17_Valid", "cost": 4, "is_carry": True},
        {"cost": 2, "is_carry": False},  # missing id
        {"id": "", "cost": 2, "is_carry": False},  # empty id
    ]
    out = aggregate_positions(champs, traits=[])
    assert len(out) == 1
    assert out[0]["championId"] == "TFT17_Valid"
