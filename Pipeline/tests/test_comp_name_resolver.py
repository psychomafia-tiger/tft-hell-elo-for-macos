from tftmac_pipeline.comp_name_resolver import resolve_comp_name


def test_returns_curated_name_when_mapped():
    # Key sorts as TFT17_Dominator+TFT17_Marksman — matches map entry
    sig = (("TFT17_Dominator", 2), ("TFT17_Marksman", 3))
    assert resolve_comp_name(sig) == "Dominator Marksmen"


def test_fallback_top_2_traits_when_unmapped():
    sig = (("Set17_Bruiser", 4), ("Set17_FakeTrait", 1))
    # Top 2 by tier (Bruiser 4 > FakeTrait 1) → "Bruiser FakeTrait"
    name = resolve_comp_name(sig)
    assert "Bruiser" in name
    assert name == "Bruiser FakeTrait"  # strips "Set17_" prefix


def test_empty_signature_returns_unknown():
    assert resolve_comp_name(()) == "Unknown Comp"


def test_strip_prefix_handles_TFT17():
    sig = (("TFT17_Bruiser", 4), ("TFT17_Striker", 1))
    name = resolve_comp_name(sig)
    assert "TFT17_" not in name
    assert "Bruiser" in name


def test_strip_prefix_handles_legacy_Set17():
    # Backward-compat — Set17_ prefix may appear in old fixtures
    sig = (("Set17_Bruiser", 4), ("Set17_Striker", 1))
    name = resolve_comp_name(sig)
    assert "Set17_" not in name
    assert "Bruiser" in name
