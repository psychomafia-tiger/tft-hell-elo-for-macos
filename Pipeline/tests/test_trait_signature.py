"""Trait combo signature: stable hash from active traits + tier breakpoints."""
from tftmac_pipeline.trait_signature import trait_combo_signature

def test_returns_sorted_active_traits_only():
    participant = {
        "traits": [
            {"name": "Set17_Psionic", "num_units": 4, "tier_current": 2, "style": 3},
            {"name": "Set17_Dominator", "num_units": 2, "tier_current": 1, "style": 1},
            {"name": "Set17_Storm", "num_units": 1, "tier_current": 0, "style": 0},  # inactive — filtered
        ]
    }
    sig = trait_combo_signature(participant)
    # Sorted alphabetically by name, only active (tier_current > 0)
    assert sig == (("Set17_Dominator", 1), ("Set17_Psionic", 2))

def test_empty_when_no_active_traits():
    assert trait_combo_signature({"traits": []}) == ()

def test_handles_missing_traits_key():
    assert trait_combo_signature({}) == ()
