"""Async Riot TFT API client — TFT-League-v1 + TFT-Match-v1.

Rate limit: Dev key 100 req/2 min. AsyncLimiter(50, 60) = 50% safety margin.
2 workers share one limiter → combined throughput ≤50 req/min.
"""
from __future__ import annotations

import asyncio
import logging
from typing import Any

import aiohttp
from aiolimiter import AsyncLimiter

logger = logging.getLogger(__name__)

# Cloudflare-UA workaround: default Python UA triggers 403 on Riot endpoints.
# Exact string confirmed working in fetch_riot_sample.py spike.
_DEFAULT_UA = "tftmac-pipeline/0.2 (+https://github.com/psychomafia-tiger/tft-hell-elo-for-macos)"

PLATFORM_TO_REGIONAL: dict[str, str] = {
    "na1": "americas", "br1": "americas", "la1": "americas", "la2": "americas",
    "euw1": "europe", "eun1": "europe", "tr1": "europe", "ru": "europe",
    "kr": "asia", "jp1": "asia",
    "vn2": "sea", "ph2": "sea", "sg2": "sea", "th2": "sea", "tw2": "sea",
    "oc1": "sea",
}

_RETRY_STATUSES = {500, 502, 503, 504}


class RiotAuthError(Exception):
    """Raised on 401/403 — invalid or expired API key."""


class RiotInsufficientDataError(Exception):
    """Raised when 0 valid matches fetched — refuse empty output."""


class RiotClient:
    """Async context manager wrapping aiohttp + aiolimiter for Riot API.

    Usage:
        async with RiotClient(api_key="RGAPI-...", region="vn2") as client:
            puuids = await client.fetch_challenger_puuids()
    """

    def __init__(
        self,
        api_key: str,
        region: str = "vn2",
        routing: str | None = None,
        workers: int = 2,
    ) -> None:
        region = region.lower()
        if region not in PLATFORM_TO_REGIONAL:
            raise ValueError(f"Unknown region '{region}'. Valid: {list(PLATFORM_TO_REGIONAL)}")
        self._api_key = api_key
        self._region = region
        self._routing = routing or PLATFORM_TO_REGIONAL[region]
        # Shared rate limiter: 50 req per 60s (20% under 100/120s Dev budget)
        self._limiter: AsyncLimiter = AsyncLimiter(50, 60)
        self._session: aiohttp.ClientSession | None = None
        self._workers = workers

    async def __aenter__(self) -> "RiotClient":
        self._session = aiohttp.ClientSession(
            headers={
                "X-Riot-Token": self._api_key,
                "User-Agent": _DEFAULT_UA,
                "Accept": "application/json",
                "Accept-Language": "en-US,en;q=0.9",
            },
            timeout=aiohttp.ClientTimeout(total=30),
        )
        return self

    async def __aexit__(self, *_: Any) -> None:
        if self._session:
            await self._session.close()
            self._session = None

    async def _get(self, url: str) -> Any:
        """Rate-limited GET. 401/403→RiotAuthError; 429→backoff; 5xx→1 retry; timeout→1 retry."""
        assert self._session is not None, "Use RiotClient as async context manager"
        delays = [5, 10, 20]

        for attempt in range(4):
            async with self._limiter:
                try:
                    async with self._session.get(url) as resp:
                        if resp.status in (401, 403):
                            raise RiotAuthError(
                                f"RIOT_API_KEY invalid or expired (HTTP {resp.status}). "
                                "Regenerate key at https://developer.riotgames.com/"
                            )
                        if resp.status == 429:
                            wait = delays[min(attempt, len(delays) - 1)]
                            logger.warning("429 rate limit on %s — backoff %ds (attempt %d)", url, wait, attempt + 1)
                            await asyncio.sleep(wait)
                            continue
                        if resp.status in _RETRY_STATUSES:
                            if attempt < 1:
                                logger.warning("HTTP %d on %s — retrying after 3s", resp.status, url)
                                await asyncio.sleep(3)
                                continue
                            logger.warning("HTTP %d on %s — skipping after retry", resp.status, url)
                            return None
                        resp.raise_for_status()
                        return await resp.json()
                except (aiohttp.ClientConnectionError, asyncio.TimeoutError) as exc:
                    if attempt < 1:
                        logger.warning("Connection error on %s (%s) — retrying", url, exc)
                        await asyncio.sleep(2)
                        continue
                    logger.warning("Connection error on %s (%s) — skipping", url, exc)
                    return None
        return None

    async def fetch_challenger_puuids(self) -> list[str]:
        """Fetch Challenger PUUIDs. Riot 2024+: PUUID in entries directly."""
        url = f"https://{self._region}.api.riotgames.com/tft/league/v1/challenger"
        data = await self._get(url)
        if not data:
            logger.warning("Empty response from Challenger endpoint")
            return []
        entries = data.get("entries", [])
        puuids = [e["puuid"] for e in entries if "puuid" in e]
        logger.info("Challenger ladder: %d entries, %d with PUUID", len(entries), len(puuids))
        return puuids

    async def fetch_match_ids(self, puuid: str, count: int = 20) -> list[str]:
        """Fetch last `count` ranked (queue=1100) match IDs for a PUUID."""
        url = (
            f"https://{self._routing}.api.riotgames.com"
            f"/tft/match/v1/matches/by-puuid/{puuid}/ids"
            f"?count={count}&queue=1100&start=0"
        )
        data = await self._get(url)
        if not isinstance(data, list):
            return []
        return data

    async def fetch_match(self, match_id: str) -> dict | None:
        """Fetch full match detail. Returns None if fetch fails (caller skips)."""
        url = f"https://{self._routing}.api.riotgames.com/tft/match/v1/matches/{match_id}"
        return await self._get(url)

    async def fetch_all_matches(
        self,
        puuids: list[str],
        max_matches: int = 1500,
        match_ids_per_puuid: int = 20,
    ) -> list[dict]:
        """PUUIDs → match IDs (dedupe) → ranked match details. Skips individual failures."""
        # Step 1: Collect match IDs across all PUUIDs
        logger.info("Fetching match IDs for %d PUUIDs...", len(puuids))
        sem = asyncio.Semaphore(self._workers)

        async def _fetch_ids(puuid: str) -> list[str]:
            async with sem:
                return await self.fetch_match_ids(puuid, match_ids_per_puuid)

        id_results = await asyncio.gather(*[_fetch_ids(p) for p in puuids])
        all_ids: set[str] = set()
        for ids in id_results:
            all_ids.update(ids)

        capped = list(all_ids)[:max_matches]
        logger.info("Deduped match IDs: %d total, capped at %d", len(all_ids), len(capped))

        # Step 2: Fetch match details in parallel
        logger.info("Fetching %d match details (workers=%d)...", len(capped), self._workers)
        fetch_count = 0
        skip_count = 0

        async def _fetch_match(mid: str) -> dict | None:
            nonlocal fetch_count, skip_count
            async with sem:
                result = await self.fetch_match(mid)
                if result is None:
                    skip_count += 1
                else:
                    fetch_count += 1
                    if fetch_count % 100 == 0:
                        logger.info("  ... fetched %d/%d matches", fetch_count, len(capped))
                return result

        raw_results = await asyncio.gather(*[_fetch_match(mid) for mid in capped])
        matches = [m for m in raw_results if m is not None]

        # Belt-and-suspenders: filter to ranked only
        ranked = [m for m in matches if m.get("info", {}).get("queue_id") == 1100]
        logger.info(
            "Fetch complete: %d fetched, %d skipped, %d ranked (queue=1100)",
            len(matches), skip_count, len(ranked),
        )
        return ranked
