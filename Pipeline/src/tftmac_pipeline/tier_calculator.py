"""Tier classification for TFT comps: S / A / B / C.

Pure function — no side effects, easily unit-testable.

Concrete example:
  1000 ranked matches × 8 participants = 8000 slots.
  Comp "Storm Quickdraw" in 800 slots → play_rate = 0.10.
  avg_placement = 3.7, sample_size = 800 → tier S (all 3 thresholds pass).

Tier thresholds (locked by phase-01 spec):
  S: play_rate >= 0.08 AND avg_placement <= 4.0 AND sample_size >= 30
  A: play_rate >= 0.05 AND avg_placement <= 4.3 AND sample_size >= 20
  B: play_rate >= 0.03 AND avg_placement <= 4.5 AND sample_size >= 15
  C: else (if sample_size >= 10)
  None (filtered): sample_size < 10
"""
from __future__ import annotations

from enum import Enum


class Tier(str, Enum):
    S = "S"
    A = "A"
    B = "B"
    C = "C"


def classify(
    play_rate: float,
    avg_placement: float,
    sample_size: int,
) -> Tier | None:
    """Classify a comp into S/A/B/C tier, or None if insufficient data.

    Args:
        play_rate: Fraction of participant slots this comp occupied (0.0 – 1.0).
        avg_placement: Mean placement across comp appearances (1.0 – 8.0).
        sample_size: Number of times this comp was observed.

    Returns:
        Tier enum value, or None if sample_size < 10 (insufficient data).
    """
    if sample_size < 10:
        return None

    if play_rate >= 0.08 and avg_placement <= 4.0 and sample_size >= 30:
        return Tier.S
    if play_rate >= 0.05 and avg_placement <= 4.3 and sample_size >= 20:
        return Tier.A
    if play_rate >= 0.03 and avg_placement <= 4.5 and sample_size >= 15:
        return Tier.B
    return Tier.C
