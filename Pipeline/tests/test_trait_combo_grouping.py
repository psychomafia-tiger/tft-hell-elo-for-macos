"""Comp grouping by trait signature (replaces champion-set hash)."""
from tftmac_pipeline.comp_grouping import group_comps_by_trait_signature


def test_same_trait_combo_groups_together():
    participants = [
        {
            "placement": 1,
            "traits": [{"name": "Set17_Psionic", "tier_current": 2, "num_units": 4}],
            "units": [{"character_id": "TFT17_Viktor", "tier": 2, "items": []}],
        },
        {
            "placement": 3,
            "traits": [{"name": "Set17_Psionic", "tier_current": 2, "num_units": 4}],
            "units": [{"character_id": "TFT17_Syndra", "tier": 2, "items": []}],
        },
    ]
    grouped = group_comps_by_trait_signature(participants)
    assert len(grouped) == 1
    comp = list(grouped.values())[0]
    assert comp["sample_size"] == 2


def test_different_trait_combos_separate():
    participants = [
        {"placement": 1, "traits": [{"name": "Set17_Psionic", "tier_current": 2, "num_units": 4}], "units": []},
        {"placement": 2, "traits": [{"name": "Set17_Dominator", "tier_current": 1, "num_units": 2}], "units": []},
    ]
    grouped = group_comps_by_trait_signature(participants)
    assert len(grouped) == 2
