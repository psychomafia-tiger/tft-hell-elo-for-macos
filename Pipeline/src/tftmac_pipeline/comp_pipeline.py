"""Comp pipeline helpers — signature extraction, naming, group → CompEntry.

Extracted from run_aggregator to keep modules under 200 LOC.
Used by both run_aggregator (production) and test_run_aggregator (tests).
"""
from __future__ import annotations

from tftmac_pipeline.anomaly_aggregator import aggregate_anomalies
from tftmac_pipeline.champion_aggregator import aggregate_champions
from tftmac_pipeline.comp_grouping import group_signatures
from tftmac_pipeline.comp_signature import extract_signature
from tftmac_pipeline.json_emitter import (
    AnomalyEntry,
    ChampionEntry,
    CompEntry,
    ItemBuild,
)
from tftmac_pipeline.tier_calculator import classify

_GROUPING_THRESHOLD = 0.70

# Prefixes stripped when building human-readable names and kebab IDs
_SET_PREFIXES = ("TFT17_", "TFT16_", "TFT15_", "TFT14_", "TFT_")


def signature_for_participant(participant: dict) -> str:
    """Convert raw Riot participant dict → comp signature string.

    Filters to units cost >= 3 (rarity + 1) before extracting signature,
    matching the existing extract_signature convention.
    """
    units_spec = [
        {"id": u["character_id"], "cost": u.get("rarity", 0) + 1}
        for u in participant.get("units", [])
        if u.get("character_id")
    ]
    return extract_signature(units_spec)


def build_comp_name(canonical: str) -> str:
    """Human-readable name from canonical signature.

    "TFT17_Viktor+TFT17_KaiSa" → "Viktor + KaiSa"
    """
    parts = canonical.split("+")
    names = []
    for p in parts:
        name = p
        for prefix in _SET_PREFIXES:
            name = name.replace(prefix, "")
        names.append(name)
    return " + ".join(names)


def build_comp_id(canonical: str) -> str:
    """Stable kebab-case ID from canonical signature.

    "TFT17_Viktor+TFT17_KaiSa" → "viktor-kaisa"
    """
    parts = canonical.split("+")
    ids = []
    for p in parts:
        name = p
        for prefix in _SET_PREFIXES:
            name = name.replace(prefix, "")
        ids.append(name.lower())
    return "-".join(ids)


def derive_patch_version(matches: list[dict]) -> str:
    """Extract patch string from game_version of first match.

    game_version example: "Linux Version 16.8.766.8562 ..."  → "16.8"
    Falls back to "unknown" if no parseable version found.
    """
    for m in matches:
        gv = m.get("info", {}).get("game_version", "")
        for part in gv.split():
            if part.count(".") >= 2 and part[0].isdigit():
                return ".".join(part.split(".")[:2])
    return "unknown"


def extract_signatures_from_matches(
    matches: list[dict],
) -> tuple[list[str], dict[str, list[dict]]]:
    """Extract per-participant signatures from match list.

    Returns:
        signatures: flat list of all signature strings (may contain duplicates)
        sig_to_participants: mapping from signature → list of raw participant dicts
    """
    signatures: list[str] = []
    sig_to_participants: dict[str, list[dict]] = {}
    for m in matches:
        for participant in m.get("info", {}).get("participants", []):
            sig = signature_for_participant(participant)
            if not sig:
                continue
            signatures.append(sig)
            sig_to_participants.setdefault(sig, []).append(participant)
    return signatures, sig_to_participants


def build_comps_from_groups(
    groups: list[dict],
    sig_to_participants: dict[str, list[dict]],
    total_participants: int,
) -> list[CompEntry]:
    """Convert grouped signatures + participant data into CompEntry list.

    Filters comps with tier=None (sample_size < 10).
    Sorts: S → A → B → C, then by play_rate desc for determinism.
    """
    tier_order = {"S": 0, "A": 1, "B": 2, "C": 3}
    comps: list[CompEntry] = []

    for group in groups:
        canonical = group["canonical"]
        sample_size = group["frequency"]

        group_participants: list[dict] = []
        for variant in group["variants"]:
            group_participants.extend(sig_to_participants.get(variant, []))

        if not group_participants:
            continue

        placements = [p["placement"] for p in group_participants if "placement" in p]
        if not placements:
            continue

        play_rate = round(sample_size / total_participants, 6) if total_participants else 0.0
        avg_placement = round(sum(placements) / len(placements), 4)
        top4_count = sum(1 for pl in placements if pl <= 4)
        top_4_rate = round(top4_count / len(placements), 4)

        tier = classify(play_rate, avg_placement, sample_size)
        if tier is None:
            continue

        raw_champions = aggregate_champions(group_participants)
        champion_entries = [
            ChampionEntry(
                id=c["id"],
                cost=c["cost"],
                is_carry=c["is_carry"],
                items=[ItemBuild(id=it["id"], agreement=it["agreement"]) for it in c["items"]],
            )
            for c in raw_champions
        ]

        raw_anomalies = aggregate_anomalies(group_participants, sample_size)
        anomaly_entries = [
            AnomalyEntry(id=a["id"], agreement=a["agreement"])
            for a in raw_anomalies
        ]

        comps.append(CompEntry(
            comp_id=build_comp_id(canonical),
            name=build_comp_name(canonical),
            tier=tier.value,
            play_rate=play_rate,
            avg_placement=avg_placement,
            top_4_rate=top_4_rate,
            sample_size=sample_size,
            champions=champion_entries,
            anomalies=anomaly_entries,
        ))

    comps.sort(key=lambda c: (tier_order.get(c.tier, 9), -c.play_rate))
    return comps


def run_pipeline(
    matches: list[dict],
    threshold: float = _GROUPING_THRESHOLD,
) -> tuple[list[CompEntry], int, str]:
    """Full pipeline: matches → comps.

    Returns:
        comps: list of CompEntry (filtered, sorted)
        total_participants: total participant count processed
        patch_version: derived from match data
    """
    signatures, sig_to_participants = extract_signatures_from_matches(matches)
    total_participants = len(signatures)

    if not signatures:
        return [], 0, "unknown"

    groups = group_signatures(signatures, threshold=threshold)
    comps = build_comps_from_groups(groups, sig_to_participants, total_participants)
    patch_version = derive_patch_version(matches)
    return comps, total_participants, patch_version
