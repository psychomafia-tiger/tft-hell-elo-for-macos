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


def test_items_per_champion_uses_itemNames_not_items():
    """Bug #008 — Riot Set 17 emits unit.itemNames (strings); unit.items (ints) always empty."""
    participants = [{
        "placement": 1,
        "traits": [{"name": "TFT17_DarkStar", "tier_current": 2, "num_units": 4}],
        "units": [{
            "character_id": "TFT17_Karma",
            "rarity": 4,
            "tier": 2,
            "items": [],
            "itemNames": ["TFT_Item_JeweledGauntlet", "TFT_Item_SpearOfShojin"],
        }],
    }]
    from tftmac_pipeline.comp_grouping import group_comps_by_trait_signature
    buckets = group_comps_by_trait_signature(participants)
    assert len(buckets) == 1
    bucket = next(iter(buckets.values()))
    items = bucket["items_per_champion"]["TFT17_Karma"]
    assert items["TFT_Item_JeweledGauntlet"] == 1
    assert items["TFT_Item_SpearOfShojin"] == 1
