"""Generate expected-tier-list-output.json golden fixture from KR fixture.

Run once after intentional logic changes to lock in expected output:
  cd Pipeline && .venv/bin/python tests/generate_golden_fixture.py

Commit the regenerated file when tier logic changes are intentional.
The fixed timestamp ensures byte-identical output across runs.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

_src = Path(__file__).parent.parent / "src"
if str(_src) not in sys.path:
    sys.path.insert(0, str(_src))

from tftmac_pipeline.comp_pipeline import run_pipeline
from tftmac_pipeline.json_emitter import TierListOutput, tier_list_to_dict

_FIXTURES = Path(__file__).parent / "fixtures"
_GOLDEN = _FIXTURES / "expected-tier-list-output.json"
_KR_FIXTURE = _FIXTURES / "fetched-matches-kr-2026-04-24.json"
_FIXED_TIMESTAMP = "2026-04-25T18:00:00Z"


def generate() -> None:
    matches = json.loads(_KR_FIXTURE.read_text())
    ranked = [m for m in matches if m.get("info", {}).get("queue_id") == 1100]
    if not ranked:
        ranked = matches
        print(f"WARNING: no ranked matches, using all {len(matches)}")

    comps, total_participants, patch_version = run_pipeline(ranked)

    output = TierListOutput(
        schema_version="1.1.0",
        patch_version=patch_version,
        last_updated=_FIXED_TIMESTAMP,
        data_window_hours=12,
        elo_bracket="CHALLENGER",
        region="KR",
        total_matches_sampled=len(ranked),
        comps=comps,
    )

    as_dict = tier_list_to_dict(output)
    json_text = json.dumps(as_dict, sort_keys=True, indent=2, ensure_ascii=False)
    _GOLDEN.write_text(json_text, encoding="utf-8")

    print(f"Golden fixture → {_GOLDEN}")
    print(f"  ranked matches : {len(ranked)}")
    print(f"  participant slots: {total_participants}")
    print(f"  comps (filtered): {len(comps)}")
    tier_counts = {t: sum(1 for c in comps if c.tier == t) for t in ("S", "A", "B", "C")}
    print(f"  tiers: S={tier_counts['S']} A={tier_counts['A']} B={tier_counts['B']} C={tier_counts['C']}")
    for c in comps[:10]:
        anomaly_count = len(c.anomalies)
        print(f"  [{c.tier}] {c.name[:40]:<40} rate={c.play_rate:.4f} place={c.avg_placement:.2f} n={c.sample_size} anomalies={anomaly_count}")


if __name__ == "__main__":
    generate()
