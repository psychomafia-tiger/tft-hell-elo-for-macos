"""Schema 1.2.0 JSON emitter — dataclasses → tier-list.json.

Produces deterministic output: sort_keys=True + indent=2 so git diffs are
readable and byte-equality tests are reliable across runs.

PII safety: output fields are aggregated stats only. No puuid, riotIdGameName,
or RGAPI key fragments propagate to output. Security assertion in emit().

Schema changelog:
  1.0.0 — initial schema
  1.1.0 — adds `anomalies[]` per comp + `region` at root
  1.2.0 — adds `traits[]` per comp (trait-signature grouping, T4 integration)
           Existing App Codable decodes 1.2.0 (ignores unknown fields).
"""
from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Tuple

# Current schema version emitted by this module and run_aggregator.
SCHEMA_VERSION = "1.2.0"

# PII patterns that must never appear in output
_PII_PATTERNS = [
    re.compile(r'[A-Za-z0-9_\-]{50,}'),  # PUUID-length strings (78 chars)
    re.compile(r'RGAPI-'),                 # Raw API key fragments
]

# PUUID character profile: base64url, typically 78 chars — use length heuristic
_PUUID_MIN_LENGTH = 60


@dataclass
class AnomalyEntry:
    id: str
    agreement: float  # 0.40 – 1.0


@dataclass
class ItemBuild:
    id: str
    agreement: float  # 0.40 – 1.0


@dataclass
class ChampionEntry:
    id: str
    cost: int
    is_carry: bool
    star_level: int = 1
    items: list[ItemBuild] = field(default_factory=list)


@dataclass
class TraitEntry:
    name: str
    count: int   # num_units activating the trait
    style: str   # "bronze" | "silver" | "gold" | "chromatic"


@dataclass
class CompEntry:
    comp_id: str
    name: str
    tier: str            # "S" | "A" | "B" | "C"
    play_rate: float
    avg_placement: float
    top_4_rate: float
    sample_size: int
    champions: list[ChampionEntry] = field(default_factory=list)
    anomalies: list[AnomalyEntry] = field(default_factory=list)
    traits: list[TraitEntry] = field(default_factory=list)


@dataclass
class TierListOutput:
    schema_version: str
    patch_version: str
    last_updated: str    # ISO8601 UTC
    data_window_hours: int
    elo_bracket: str
    region: str
    total_matches_sampled: int
    comps: list[CompEntry] = field(default_factory=list)


def _item_to_dict(item: ItemBuild) -> dict:
    return {"id": item.id, "agreement": item.agreement}


def _champion_to_dict(champ: ChampionEntry) -> dict:
    return {
        "id": champ.id,
        "cost": champ.cost,
        "is_carry": champ.is_carry,
        "star_level": champ.star_level,
        "items": [_item_to_dict(i) for i in champ.items],
    }


def _anomaly_to_dict(anomaly: AnomalyEntry) -> dict:
    return {"id": anomaly.id, "agreement": anomaly.agreement}


def _trait_to_dict(trait: TraitEntry) -> dict:
    return {"count": trait.count, "name": trait.name, "style": trait.style}


def _comp_to_dict(comp: CompEntry) -> dict:
    return {
        "comp_id": comp.comp_id,
        "name": comp.name,
        "tier": comp.tier,
        "play_rate": comp.play_rate,
        "avg_placement": comp.avg_placement,
        "top_4_rate": comp.top_4_rate,
        "sample_size": comp.sample_size,
        "champions": [_champion_to_dict(c) for c in comp.champions],
        "anomalies": [_anomaly_to_dict(a) for a in comp.anomalies],
        "traits": [_trait_to_dict(t) for t in comp.traits],
    }


def tier_list_to_dict(output: TierListOutput) -> dict:
    """Convert TierListOutput dataclass to plain dict for JSON serialisation."""
    return {
        "schema_version": output.schema_version,
        "patch_version": output.patch_version,
        "last_updated": output.last_updated,
        "data_window_hours": output.data_window_hours,
        "elo_bracket": output.elo_bracket,
        "region": output.region,
        "total_matches_sampled": output.total_matches_sampled,
        "comps": [_comp_to_dict(c) for c in output.comps],
    }


def _check_pii(json_text: str) -> None:
    """Assert no PII patterns in output. Raises ValueError on violation."""
    lines = json_text.splitlines()
    for line in lines:
        # Check for RGAPI key fragments
        if "RGAPI-" in line:
            raise ValueError("PII leak detected: RGAPI key fragment in output")
        # Check for PUUID-length strings (value strings >= 60 chars in JSON)
        # JSON string values appear as: "key": "value"
        for match in re.finditer(r'"([^"]{60,})"', line):
            val = match.group(1)
            # Allow long strings that are clearly not PUUIDs (URLs, descriptions)
            if not any(c in val for c in [' ', '/', '.', ':']):
                raise ValueError(
                    f"Potential PUUID in output (len={len(val)}): {val[:20]}..."
                )


def emit(output: TierListOutput, path: Path) -> None:
    """Write TierListOutput to path as deterministic JSON.

    Atomicity: writes to a temp file first, then renames — prevents partial
    writes if process is killed mid-write (Phase 02 depends on atomic output).

    PII check: scans output text before writing. Raises ValueError if any
    PUUID-length string or RGAPI fragment detected.

    Args:
        output: Fully populated TierListOutput dataclass.
        path: Destination path (parent directory must exist).
    """
    emit_dict(tier_list_to_dict(output), path)


def emit_dict(payload: dict, path: Path) -> None:
    """Write a pre-built payload dict to path as deterministic JSON.

    Same atomicity + PII guarantees as `emit()`. Used by callers that need
    to attach extra top-level keys (e.g. bug #004 `updated_at` / `match_count`
    aliases) before serialisation.
    """
    json_text = json.dumps(payload, sort_keys=True, indent=2, ensure_ascii=False)

    # PII safety gate — never write output containing raw identifiers
    _check_pii(json_text)

    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)

    # Atomic write via temp file + rename
    tmp_path = path.with_suffix(".tmp")
    tmp_path.write_text(json_text, encoding="utf-8")
    tmp_path.rename(path)


def make_last_updated() -> str:
    """Return current UTC time as ISO8601 string (no microseconds)."""
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


# ---------------------------------------------------------------------------
# Schema 1.2.0 helpers — trait-signature grouped comp emission
# ---------------------------------------------------------------------------

def _style_for(count: int) -> str:
    """Map trait activation count to Riot bronze/silver/gold/chromatic style tier.

    Concrete example: Psionic at 4 units → "gold"; at 2 units → "silver".
    Thresholds match Riot's in-game trait breakpoint display UX.
    """
    if count >= 6:
        return "chromatic"
    if count >= 4:
        return "gold"
    if count >= 2:
        return "silver"
    return "bronze"


def _slugify(name: str) -> str:
    """Convert human-readable comp name to kebab-case ID.

    "Psionic Carry" → "psionic-carry"; "Viktor's Edge" → "viktors-edge"
    """
    return name.lower().replace(" ", "-").replace("'", "")


def _emit_champions_from_bucket(bucket: dict) -> list[dict]:
    """Build champions list from a trait-signature bucket (T3 shape).

    Bucket keys used: champion_freq (dict[cid → int]),
    items_per_champion (dict[cid → dict[item_id → int]]),
    champion_rarity (dict[cid → int], optional — rarity 0-6 → cost = rarity+1),
    champion_star_counts (dict[cid → dict[int → int]], optional — modal star level).

    A champion is considered carry if it appears in the top-3 by frequency.
    Items are filtered to those appearing in ≥40% of the bucket's appearances.

    Cost: derived from rarity if bucket provides champion_rarity (rarity+1).
    Fallback to 1 when rarity data absent (avoids the previous cost=0 placeholder).
    Star level: modal observed tier from champion_star_counts; default 1.
    """
    sample_size = max(bucket["sample_size"], 1)
    champion_freq: dict = bucket.get("champion_freq", {})
    items_per_champ: dict = bucket.get("items_per_champion", {})
    champion_rarity: dict = bucket.get("champion_rarity", {})
    champion_star_counts: dict = bucket.get("champion_star_counts", {})

    # Sort by frequency descending; top-3 are considered potential carries
    sorted_champs = sorted(champion_freq.items(), key=lambda x: -x[1])
    carry_ids = {cid for cid, _ in sorted_champs[:3]}

    result = []
    for cid, freq in sorted_champs:
        agreement = round(freq / sample_size, 4)
        if agreement < 0.25:
            # Skip champions that appear in fewer than 25% of instances
            continue

        # Derive cost from rarity if available; else default 1 (not 0)
        rarity = champion_rarity.get(cid)
        cost = (rarity + 1) if rarity is not None else 1

        # Modal star level from observed tier distribution; default 1
        star_tier_counts: dict = champion_star_counts.get(cid, {})
        if star_tier_counts:
            star_level = max(star_tier_counts, key=lambda k: star_tier_counts[k])
        else:
            star_level = 1

        # Build item list filtered by ≥40% agreement
        raw_items = items_per_champ.get(cid, {})
        item_list = [
            {"id": str(item_id), "agreement": round(item_freq / sample_size, 4)}
            for item_id, item_freq in sorted(raw_items.items(), key=lambda x: -x[1])
            if item_freq / sample_size >= 0.40
        ]
        result.append({
            "id": cid,
            "cost": cost,
            "is_carry": cid in carry_ids,
            "star_level": star_level,
            "items": item_list,
        })
    return result


def emit_comp(grouped_comp: dict, derived_name: str) -> dict:
    """Emit a single comp dict from a trait-signature bucket (schema 1.2.0).

    Args:
        grouped_comp: Bucket from group_comps_by_trait_signature() — keys:
            trait_signature (tuple), sample_size (int), placements (list[int]),
            champion_freq (dict), items_per_champion (dict).
        derived_name: Human-readable name from resolve_comp_name().

    Returns:
        Plain dict matching schema 1.2.0 comp shape. tier and play_rate are
        placeholder values ("C" / 0.0) — callers must fill them downstream
        after computing total_participants and calling tier_calculator.

    Concrete example: sig=(("Set17_Psionic",4),("Set17_Dominator",2)),
    placements=[1,2,3,5] → avg_placement=2.75, top_4_rate=0.75, sample_size=4.
    """
    sig: Tuple = grouped_comp["trait_signature"]
    placements: list = grouped_comp["placements"]
    n = len(placements) if placements else 1
    return {
        "comp_id": _slugify(derived_name),
        "name": derived_name,
        "tier": "C",       # placeholder — filled by tier_calculator downstream
        "play_rate": 0.0,  # placeholder — filled downstream after total_participants
        "avg_placement": round(sum(placements) / n, 4) if placements else 8.0,
        "top_4_rate": round(sum(1 for p in placements if p <= 4) / n, 4),
        "sample_size": grouped_comp["sample_size"],
        "champions": _emit_champions_from_bucket(grouped_comp),
        "anomalies": [],   # populated by anomaly_aggregator in future phases
        "traits": [
            {"name": name, "count": count, "style": _style_for(count)}
            for name, count in sig
        ],
    }
