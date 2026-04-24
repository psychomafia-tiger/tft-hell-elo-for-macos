"""Test suite cho comp signature extraction (spec §Comp Detection Step 1)."""
from tftmac_pipeline.comp_signature import extract_signature


def test_signature_filters_cost_below_3():
    """1-2 cost units là filler, không define comp identity.

    Board 5 units: 3 fillers + 2 core (cost>=3).
    Expected signature = "Kai'Sa+Sivir" (sorted alphabetical).
    """
    units = [
        {"id": "Kog'Maw", "cost": 1},
        {"id": "Ezreal", "cost": 1},
        {"id": "Jinx", "cost": 2},
        {"id": "Kai'Sa", "cost": 3},
        {"id": "Sivir", "cost": 4},
    ]
    assert extract_signature(units) == "Kai'Sa+Sivir"


def test_signature_alphabetical_order_stable():
    """Signature must be order-independent of input order.

    Jaccard comparison later relies on this invariant — nếu không sorted,
    `"Sivir+Aatrox"` != `"Aatrox+Sivir"` → same comp spawns 2 groups.
    """
    a = [{"id": "Sivir", "cost": 4}, {"id": "Aatrox", "cost": 3}]
    b = [{"id": "Aatrox", "cost": 3}, {"id": "Sivir", "cost": 4}]
    assert extract_signature(a) == extract_signature(b) == "Aatrox+Sivir"


def test_signature_empty_board_returns_empty_string():
    """Player eliminated round 1, 0 units on board. Should not crash."""
    assert extract_signature([]) == ""


def test_signature_all_filler_returns_empty_string():
    """All units cost<3. Return empty (no identity to assign)."""
    units = [
        {"id": "Kog'Maw", "cost": 1},
        {"id": "Jinx", "cost": 2},
    ]
    assert extract_signature(units) == ""


def test_signature_spec_example_8_unit_board():
    """Spec §Ví dụ concrete: 8-unit board → 5 core units signature."""
    units = [
        {"id": "Kog'Maw", "cost": 1},
        {"id": "Ezreal", "cost": 1},
        {"id": "Jinx", "cost": 2},
        {"id": "Kai'Sa", "cost": 3},
        {"id": "Aatrox", "cost": 3},
        {"id": "Sivir", "cost": 4},
        {"id": "Yasuo", "cost": 4},
        {"id": "Xerath", "cost": 5},
    ]
    assert extract_signature(units) == "Aatrox+Kai'Sa+Sivir+Xerath+Yasuo"
