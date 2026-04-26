"""Bug #004 — aggregator must populate top-level metadata fields."""
from tftmac_pipeline.run_aggregator import build_tier_list_payload


def test_payload_has_updated_at_iso8601():
    payload = build_tier_list_payload(matches=[], region="VN2", patch="16.8")
    assert "updated_at" in payload
    # ISO 8601 with timezone, e.g. "2026-04-26T17:42:00+00:00"
    assert "T" in payload["updated_at"]
    assert payload["updated_at"].endswith("+00:00") or payload["updated_at"].endswith("Z")


def test_payload_has_match_count_matching_input():
    fake_matches = [{"info": {"participants": []}} for _ in range(42)]
    payload = build_tier_list_payload(matches=fake_matches, region="VN2", patch="16.8")
    assert payload["match_count"] == 42
    # Backwards-compat alias also populated
    assert payload["total_matches_sampled"] == 42
