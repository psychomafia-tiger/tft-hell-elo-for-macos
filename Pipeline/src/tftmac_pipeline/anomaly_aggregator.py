"""Anomaly aggregation per comp group — TFT17_EkkoOffering_* mechanic.

Set 17 context: Augments removed. Players equip Anomaly items via Ekko Offering
mechanic. These items carry the prefix TFT17_EkkoOffering_. Each comp may have
0-1 anomaly per participant (rare: ~9.4% of participants in KR spike data).

Algorithm per group:
  1. Collect all TFT17_EkkoOffering_* items across all participants' units.
  2. Count occurrences per anomaly_id.
  3. agreement = count / group sample_size (not unit count — comp-level signal).
  4. Filter agreement >= 0.40, keep top-3 by agreement desc.
  5. Emit empty list [] if none qualify (Swift non-optional array decode requires []).
"""
from __future__ import annotations

from collections import Counter

_ANOMALY_PREFIX = "TFT17_EkkoOffering_"
_MIN_AGREEMENT = 0.40
_MAX_ANOMALIES = 3


def aggregate_anomalies(
    participants: list[dict],
    sample_size: int,
) -> list[dict]:
    """Aggregate anomaly items for a comp group.

    Args:
        participants: List of raw Riot participant dicts belonging to this group.
        sample_size: Total appearances of this comp (= len(participants)).
                     Used as denominator for agreement calculation.

    Returns:
        List of dicts {"id": str, "agreement": float}, sorted by agreement desc,
        max 3 items, min agreement 0.40. Empty list if none qualify.
    """
    if sample_size == 0:
        return []

    counts: Counter[str] = Counter()
    for participant in participants:
        for unit in participant.get("units", []):
            for item_name in unit.get("itemNames", []):
                if item_name.startswith(_ANOMALY_PREFIX):
                    counts[item_name] += 1

    results = [
        {"id": anomaly_id, "agreement": round(count / sample_size, 4)}
        for anomaly_id, count in counts.most_common()
        if count / sample_size >= _MIN_AGREEMENT
    ]
    return results[:_MAX_ANOMALIES]
