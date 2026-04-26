"""Bug #004 — aggregator must populate top-level metadata fields."""
import json
from pathlib import Path

import pytest

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


# Local fixtures — replicate ranked_kr_matches pattern from test_run_aggregator.py
# (kept local to avoid moving fixtures to conftest.py as a side effect).

@pytest.fixture
def _kr_matches(fixtures_dir: Path) -> list[dict]:
    return json.loads((fixtures_dir / "fetched-matches-kr-2026-04-24.json").read_text())


@pytest.fixture
def ranked_kr_matches(_kr_matches: list[dict]) -> list[dict]:
    """Ranked-only subset (queue_id=1100). Falls back to all if none ranked."""
    ranked = [m for m in _kr_matches if m.get("info", {}).get("queue_id") == 1100]
    return ranked if ranked else _kr_matches


def test_payload_match_count_with_real_matches(ranked_kr_matches):
    """Bug #004 — match_count must match input when real comps are aggregated."""
    payload = build_tier_list_payload(matches=ranked_kr_matches, region="KR", patch="")
    assert payload["match_count"] == len(ranked_kr_matches)
    assert payload["match_count"] == payload["total_matches_sampled"]
    # Confirm comps actually built (not empty path)
    assert len(payload["comps"]) > 0
