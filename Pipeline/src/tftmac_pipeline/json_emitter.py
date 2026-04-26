"""Schema 1.1.0 JSON emitter — dataclasses → tier-list.json.

Produces deterministic output: sort_keys=True + indent=2 so git diffs are
readable and byte-equality tests are reliable across runs.

PII safety: output fields are aggregated stats only. No puuid, riotIdGameName,
or RGAPI key fragments propagate to output. Security assertion in emit().

Schema 1.1.0 is additive over 1.0.0: adds `anomalies[]` per comp + `region`
at root. Existing App Codable decodes 1.1.0 (ignores unknown fields).
"""
from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path


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
    items: list[ItemBuild] = field(default_factory=list)


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
        "items": [_item_to_dict(i) for i in champ.items],
    }


def _anomaly_to_dict(anomaly: AnomalyEntry) -> dict:
    return {"id": anomaly.id, "agreement": anomaly.agreement}


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
