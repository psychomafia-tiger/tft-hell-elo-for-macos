"""Tier classification for TFT comps: S / A / B / C.

Pure function — no side effects, easily unit-testable.

Concrete example:
  527 ranked matches × 8 participants = 4216 slots.
  Comp "Illaoi+Nami+Rhaast+Summon+Viktor" in 307 slots → play_rate = 0.073.
  avg_placement = 4.28, sample_size = 307 → tier S (≥5% play, ≤4.3 avg, ≥50 sample).

Tier thresholds (Bug #C1 — relaxed for VN2 sample size):
  Old 10% / 8% S threshold prevented any S-tier emission with ~50 viable comps
  in meta. Top comp in 527-match sample maxes ~5-6% play_rate. Relaxed so top
  1-3 comps get S badge, which matches user expectation from a tier list.
  Then avg_placement 4.0 still produced 0 S-tier promotions on live VN2 data
  (no qualifying comp hit ≤4.0 avg). Relaxed S avg to ≤4.3 to match A's avg
  cap — S now distinguished from A purely by ≥5% play_rate (popularity gate).

  S: play_rate >= 0.05  AND avg_placement <= 4.3 AND sample_size >= 50
  A: play_rate >= 0.03  AND avg_placement <= 4.3 AND sample_size >= 50
  B: play_rate >= 0.015 AND avg_placement <= 4.6 AND sample_size >= 50
  C: else (incl. sample_size < 50 — too small to trust for higher tier)
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
) -> Tier:
    """Classify a comp into S/A/B/C tier.

    S = top performers (≥5% play, avg ≤4.3) — VN2 meta tuned per Bug #C1
    A = solid (≥3% play, avg ≤4.3)
    B = playable (≥1.5% play, avg ≤4.6)
    C = niche / fringe / insufficient sample

    Args:
        play_rate: Fraction of participant slots this comp occupied (0.0 – 1.0).
        avg_placement: Mean placement across comp appearances (1.0 – 8.0).
        sample_size: Number of times this comp was observed.

    Returns:
        Tier enum value. Returns Tier.C when sample_size < 50 (too small to trust).
    """
    if sample_size < 50:
        return Tier.C  # too small to trust for higher tier

    if play_rate >= 0.05 and avg_placement <= 4.3:
        return Tier.S
    if play_rate >= 0.03 and avg_placement <= 4.3:
        return Tier.A
    if play_rate >= 0.015 and avg_placement <= 4.6:
        return Tier.B
    return Tier.C
