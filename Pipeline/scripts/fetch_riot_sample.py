"""Fetch Riot TFT Challenger sample data for Phase 0 Action #3 schema verification.

Reads RIOT_API_KEY_DEV from ~/.tftmac/env (format: KEY=VALUE, one per line).
Respects Dev key rate limit (100 req / 2 min) with conservative 1.3s sleep.

Usage:
  cd Pipeline && .venv/bin/python scripts/fetch_riot_sample.py --region kr
  cd Pipeline && .venv/bin/python scripts/fetch_riot_sample.py --region vn2 --count 100

Outputs:
  /tmp/sample-participant.json     — 1 participant for F3 schema inspection
  /tmp/fetched-matches.json        — full match list (for F4 hand-labeling)
  /tmp/fetch-summary.txt           — run summary (req count, timing, errors)
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

# Riot regional routing: platform (challenger/summoner) vs regional (match)
PLATFORM_TO_REGIONAL = {
    "na1": "americas", "br1": "americas", "la1": "americas", "la2": "americas",
    "euw1": "europe", "eun1": "europe", "tr1": "europe", "ru": "europe",
    "kr": "asia", "jp1": "asia",
    "vn2": "sea", "ph2": "sea", "sg2": "sea", "th2": "sea", "tw2": "sea",
    "oc1": "sea",
}

ENV_PATH = Path.home() / ".tftmac" / "env"


def load_api_key() -> str:
    if not ENV_PATH.exists():
        sys.exit(f"ERROR: {ENV_PATH} not found. Run F2 first (echo RIOT_API_KEY_DEV=... > ~/.tftmac/env).")
    for line in ENV_PATH.read_text().splitlines():
        if line.startswith("RIOT_API_KEY_DEV="):
            return line.split("=", 1)[1].strip()
    sys.exit("ERROR: RIOT_API_KEY_DEV not found in env file.")


def http_get(url: str, api_key: str) -> dict | list:
    req = urllib.request.Request(url, headers={
        "X-Riot-Token": api_key,
        "User-Agent": "tftmac-pipeline/0.1 (+https://github.com/psychomafia-tiger/tft-hell-elo-for-macos)",
        "Accept": "application/json",
        "Accept-Language": "en-US,en;q=0.9",
    })
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace")[:300]
        raise RuntimeError(f"HTTP {e.code} on {url}: {body}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--region", default="kr",
                        choices=list(PLATFORM_TO_REGIONAL.keys()),
                        help="Platform region (default: kr — highest TFT quality data)")
    parser.add_argument("--puuid-count", type=int, default=20,
                        help="Challenger PUUIDs to sample (default: 20)")
    parser.add_argument("--match-count", type=int, default=100,
                        help="Target total match detail fetches (default: 100)")
    parser.add_argument("--sleep", type=float, default=1.3,
                        help="Seconds between requests (default: 1.3, Dev key safe)")
    args = parser.parse_args()

    api_key = load_api_key()
    platform = args.region
    regional = PLATFORM_TO_REGIONAL[platform]
    print(f"Region: {platform} (platform) → {regional} (regional)")

    req_count = 0
    errors: list[str] = []
    t_start = time.time()

    # Step 1: Challenger list
    print("[1/3] Fetching Challenger list...")
    chal_url = f"https://{platform}.api.riotgames.com/tft/league/v1/challenger"
    chal_data = http_get(chal_url, api_key)
    req_count += 1
    entries = chal_data.get("entries", [])
    print(f"  → {len(entries)} Challenger entries")

    # Extract PUUIDs (Riot 2024+ returns puuid directly in entries)
    puuids: list[str] = []
    for entry in entries[:args.puuid_count]:
        puuid = entry.get("puuid")
        if puuid:
            puuids.append(puuid)
    if not puuids:
        sys.exit("ERROR: No PUUIDs in challenger entries. Schema changed, investigate.")
    print(f"  → {len(puuids)} PUUIDs collected")

    # Step 2: Match IDs per PUUID
    print(f"[2/3] Fetching match IDs ({len(puuids)} PUUIDs × 5 matches = ~{len(puuids)*5} IDs)...")
    match_ids: set[str] = set()
    per_puuid = max(5, args.match_count // len(puuids) + 1)
    for i, puuid in enumerate(puuids, 1):
        time.sleep(args.sleep)
        url = f"https://{regional}.api.riotgames.com/tft/match/v1/matches/by-puuid/{puuid}/ids?count={per_puuid}"
        try:
            ids = http_get(url, api_key)
            req_count += 1
            if isinstance(ids, list):
                match_ids.update(ids)
            print(f"  [{i}/{len(puuids)}] +{len(ids) if isinstance(ids, list) else 0} ids | total unique: {len(match_ids)}")
        except RuntimeError as e:
            errors.append(f"match-ids {puuid[:8]}: {e}")
        if len(match_ids) >= args.match_count:
            break

    match_ids_list = list(match_ids)[:args.match_count]
    print(f"  → {len(match_ids_list)} unique match IDs (capped at {args.match_count})")

    # Step 3: Match details
    print(f"[3/3] Fetching {len(match_ids_list)} match details...")
    matches: list[dict] = []
    for i, mid in enumerate(match_ids_list, 1):
        time.sleep(args.sleep)
        url = f"https://{regional}.api.riotgames.com/tft/match/v1/matches/{mid}"
        try:
            match = http_get(url, api_key)
            req_count += 1
            matches.append(match)
            if i % 10 == 0 or i == len(match_ids_list):
                print(f"  [{i}/{len(match_ids_list)}] fetched | req#{req_count} | elapsed {time.time()-t_start:.0f}s")
        except RuntimeError as e:
            errors.append(f"match {mid}: {e}")

    # Outputs
    out_matches = Path("/tmp/fetched-matches.json")
    out_sample = Path("/tmp/sample-participant.json")
    out_summary = Path("/tmp/fetch-summary.txt")

    out_matches.write_text(json.dumps(matches, indent=2))
    print(f"\n✓ Saved {len(matches)} matches → {out_matches}")

    if matches:
        sample_participant = matches[0]["info"]["participants"][0]
        out_sample.write_text(json.dumps(sample_participant, indent=2))
        print(f"✓ Saved 1 participant sample → {out_sample}")

    elapsed = time.time() - t_start
    summary = f"""Riot TFT Fetch Summary
======================
Region: {platform} (regional: {regional})
Total requests: {req_count}
Successful matches: {len(matches)}
Errors: {len(errors)}
Elapsed: {elapsed:.1f}s ({elapsed/60:.1f} min)
Throughput: {req_count/elapsed:.2f} req/s

Error details:
{chr(10).join(errors) if errors else '(none)'}
"""
    out_summary.write_text(summary)
    print(f"✓ Saved summary → {out_summary}")
    print("\n--- Summary ---")
    print(summary)


if __name__ == "__main__":
    main()
