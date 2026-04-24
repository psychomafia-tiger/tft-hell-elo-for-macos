#!/usr/bin/env python3
"""Weekend 0 Action #4 — tune Jaccard threshold against hand-labeled comp groups.

Usage:
    python scripts/tune_jaccard_threshold.py tests/fixtures/hand_labeled_groups.json

Output:
    Agreement % per threshold (0.60, 0.70, 0.80). Founder picks best threshold.
    If all <80% → fallback to carry-signature algorithm (see eng review §1.4).
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

# Ensure src/ is importable khi chạy từ repo root
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "src"))

from tftmac_pipeline.comp_grouping import group_signatures
from tftmac_pipeline.tuning import agreement_rate


def main(path: str) -> int:
    data = json.loads(Path(path).read_text())
    expected_groups = [g["player_signatures"] for g in data.get("groups", [])]

    if not expected_groups:
        print("No hand-labeled groups. Fill fixtures first.", file=sys.stderr)
        print(f"Template: {path}", file=sys.stderr)
        return 1

    all_sigs = [sig for grp in expected_groups for sig in grp]
    print(f"Hand-labeled: {len(expected_groups)} groups, {len(all_sigs)} signatures")
    print()
    print(f"{'Threshold':>10} | {'Groups':>6} | {'Agreement':>10}")
    print(f"{'-'*10} | {'-'*6} | {'-'*10}")

    best_threshold = None
    best_rate = -1.0
    for threshold in (0.60, 0.70, 0.80):
        predicted = group_signatures(all_sigs, threshold=threshold)
        rate = agreement_rate(expected_groups, predicted)
        print(f"{threshold:>10.2f} | {len(predicted):>6d} | {rate:>9.1%}")
        if rate > best_rate:
            best_rate = rate
            best_threshold = threshold

    print()
    print(f"Best: threshold={best_threshold}, agreement={best_rate:.1%}")
    if best_rate < 0.80:
        print("⚠  All thresholds <80% agreement. Consider carry-signature fallback.")
        print("   See eng review §1.4. Update docs/pre-spike-algo-tuning.md decision.")
        return 2
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        sys.exit(1)
    sys.exit(main(sys.argv[1]))
