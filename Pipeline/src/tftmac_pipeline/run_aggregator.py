"""Production CLI entrypoint — fetch VN2 Challenger data → emit tier-list.json.

Importable module: `python -m tftmac_pipeline.run_aggregator`
Console script:    `tft-aggregate` (registered via pyproject.toml)
Script shim:       `python scripts/run_aggregator.py` (forwards here)

Exit codes:
  0  success — tier-list.json written
  1  unhandled exception
  2  auth failure (bad/expired RIOT_API_KEY)
  3  insufficient data (0 valid matches or 0 comps after filtering)
"""
from __future__ import annotations

import argparse
import asyncio
import logging
import os
import sys
from pathlib import Path

from tftmac_pipeline.comp_pipeline import run_pipeline
from tftmac_pipeline.json_emitter import TierListOutput, emit, make_last_updated
from tftmac_pipeline.riot_client import RiotAuthError, RiotClient

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s — %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
logger = logging.getLogger("tft-aggregate")

_SCHEMA_VERSION = "1.1.0"
_DATA_WINDOW_HOURS = 12


def build_parser() -> argparse.ArgumentParser:
    """Build CLI argument parser."""
    p = argparse.ArgumentParser(
        prog="tft-aggregate",
        description="Fetch VN2 Challenger TFT matches → emit tier-list.json (schema 1.1.0)",
    )
    p.add_argument(
        "--region", default=os.environ.get("RIOT_REGION", "vn2"),
        help="Platform region (default: vn2 or $RIOT_REGION)",
    )
    p.add_argument(
        "--routing", default=os.environ.get("RIOT_ROUTING", None),
        help="Regional routing override (default: auto-derived from region)",
    )
    p.add_argument(
        "--output", default="data/tier-list.json",
        help="Output JSON path (default: data/tier-list.json)",
    )
    p.add_argument(
        "--max-matches", type=int, default=1500,
        help="Max match detail fetches (default: 1500)",
    )
    p.add_argument(
        "--workers", type=int, default=2,
        help="Parallel async workers (default: 2)",
    )
    p.add_argument(
        "--match-ids-per-puuid", type=int, default=20,
        help="Match IDs fetched per PUUID (default: 20)",
    )
    return p


async def run(args: argparse.Namespace) -> int:
    """Async main pipeline. Returns exit code 0–3."""
    api_key = os.environ.get("RIOT_API_KEY", "").strip()
    if not api_key:
        logger.error("RIOT_API_KEY environment variable not set or empty")
        return 2

    # Log first 8 chars only — never log the full key
    logger.info(
        "API key: %s***  region=%s  routing=%s",
        api_key[:8], args.region, args.routing or "auto",
    )

    try:
        async with RiotClient(
            api_key=api_key,
            region=args.region,
            routing=args.routing,
            workers=args.workers,
        ) as client:
            puuids = await client.fetch_challenger_puuids()
            if not puuids:
                logger.error("No Challenger PUUIDs found for region %s", args.region)
                return 3

            logger.info("Fetched %d Challenger PUUIDs", len(puuids))

            matches = await client.fetch_all_matches(
                puuids=puuids,
                max_matches=args.max_matches,
                match_ids_per_puuid=args.match_ids_per_puuid,
            )

    except RiotAuthError as exc:
        logger.error("Auth failure: %s", exc)
        return 2
    except Exception as exc:
        logger.exception("Unhandled error during Riot fetch: %s", exc)
        return 1

    if not matches:
        logger.error(
            "0 valid ranked matches fetched — refusing to overwrite tier-list.json"
        )
        return 3

    logger.info("Processing %d ranked matches...", len(matches))

    comps, total_participants, patch_version = run_pipeline(matches)

    if not comps:
        logger.error(
            "0 comps qualify after tier filtering — refusing to emit empty output. "
            "Possible cause: too few matches or all comps below sample_size=10.",
        )
        return 3

    logger.info(
        "Grouped %d participant slots → %d comps (%dS %dA %dB %dC)",
        total_participants,
        len(comps),
        sum(1 for c in comps if c.tier == "S"),
        sum(1 for c in comps if c.tier == "A"),
        sum(1 for c in comps if c.tier == "B"),
        sum(1 for c in comps if c.tier == "C"),
    )

    output = TierListOutput(
        schema_version=_SCHEMA_VERSION,
        patch_version=patch_version,
        last_updated=make_last_updated(),
        data_window_hours=_DATA_WINDOW_HOURS,
        elo_bracket="CHALLENGER",
        region=args.region.upper(),
        total_matches_sampled=len(matches),
        comps=comps,
    )

    output_path = Path(args.output)
    try:
        emit(output, output_path)
    except ValueError as exc:
        logger.error("PII safety check failed — refusing to write output: %s", exc)
        return 1
    except OSError as exc:
        logger.error("Failed to write %s: %s", output_path, exc)
        return 1

    logger.info("Done → %s  (%d comps)", output_path, len(comps))
    return 0


def main_sync() -> None:
    """Synchronous entry point for console_scripts and `python -m`."""
    parser = build_parser()
    args = parser.parse_args()
    sys.exit(asyncio.run(run(args)))


if __name__ == "__main__":
    main_sync()
