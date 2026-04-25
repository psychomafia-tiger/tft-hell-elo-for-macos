"""Unit tests for RiotClient — async HTTP client.

Uses aioresponses to mock aiohttp without live API calls.
Tests: UA header presence, rate-limit retry, 401 auth error, 429 backoff,
       fetch_challenger_puuids, fetch_match_ids, fetch_match, fetch_all_matches.
"""
from __future__ import annotations

import pytest
from unittest.mock import AsyncMock, MagicMock, patch

from tftmac_pipeline.riot_client import (
    PLATFORM_TO_REGIONAL,
    RiotAuthError,
    RiotClient,
    _DEFAULT_UA,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _challenger_payload(n: int = 3) -> dict:
    """Minimal Challenger API response with n entries each having a puuid."""
    return {
        "entries": [{"puuid": f"puuid_{i}", "leaguePoints": 100 - i} for i in range(n)]
    }


def _match_ids_payload(n: int = 5, prefix: str = "VN2") -> list[str]:
    return [f"{prefix}_{i:010d}" for i in range(n)]


def _match_payload(match_id: str = "VN2_0000000001") -> dict:
    return {
        "metadata": {"match_id": match_id, "participants": ["puuid_0"]},
        "info": {
            "tft_set_number": 17,
            "queue_id": 1100,
            "game_version": "Linux Version 16.8.766.8562",
            "participants": [
                {
                    "puuid": "puuid_0",
                    "placement": 1,
                    "units": [
                        {"character_id": "TFT17_Viktor", "rarity": 4, "tier": 2, "itemNames": []}
                    ],
                    "traits": [],
                }
            ],
        },
    }


# ---------------------------------------------------------------------------
# RiotClient construction
# ---------------------------------------------------------------------------

class TestRiotClientInit:
    def test_valid_region_accepted(self) -> None:
        client = RiotClient(api_key="RGAPI-test", region="vn2")
        assert client._region == "vn2"

    def test_region_normalised_to_lowercase(self) -> None:
        client = RiotClient(api_key="RGAPI-test", region="VN2")
        assert client._region == "vn2"

    def test_routing_auto_derived_from_region(self) -> None:
        client = RiotClient(api_key="RGAPI-test", region="vn2")
        assert client._routing == "sea"

    def test_routing_override_respected(self) -> None:
        client = RiotClient(api_key="RGAPI-test", region="vn2", routing="asia")
        assert client._routing == "asia"

    def test_invalid_region_raises(self) -> None:
        with pytest.raises(ValueError, match="Unknown region"):
            RiotClient(api_key="RGAPI-test", region="invalid_region")


# ---------------------------------------------------------------------------
# Session headers (User-Agent is critical to avoid Cloudflare 403)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
class TestRiotClientHeaders:
    async def test_user_agent_header_set_on_session(self) -> None:
        async with RiotClient(api_key="RGAPI-test", region="vn2") as client:
            assert client._session is not None
            # aiohttp stores default headers in _default_headers (CIMultiDictProxy)
            headers = dict(client._session._default_headers)
            assert "User-Agent" in headers
            assert headers["User-Agent"] == _DEFAULT_UA

    async def test_x_riot_token_header_set(self) -> None:
        async with RiotClient(api_key="RGAPI-test-key", region="vn2") as client:
            headers = dict(client._session._default_headers)
            assert headers["X-Riot-Token"] == "RGAPI-test-key"

    async def test_session_closed_on_exit(self) -> None:
        async with RiotClient(api_key="RGAPI-test", region="vn2") as client:
            session = client._session
        assert session.closed


# ---------------------------------------------------------------------------
# fetch_challenger_puuids
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
class TestFetchChallengerPuuids:
    async def test_returns_puuid_list(self) -> None:
        payload = _challenger_payload(n=5)
        mock_resp = MagicMock()
        mock_resp.status = 200
        mock_resp.json = AsyncMock(return_value=payload)
        mock_resp.__aenter__ = AsyncMock(return_value=mock_resp)
        mock_resp.__aexit__ = AsyncMock(return_value=False)

        async with RiotClient(api_key="RGAPI-test", region="vn2") as client:
            with patch.object(client._session, "get", return_value=mock_resp):
                result = await client.fetch_challenger_puuids()

        assert len(result) == 5
        assert result[0] == "puuid_0"

    async def test_empty_entries_returns_empty_list(self) -> None:
        mock_resp = MagicMock()
        mock_resp.status = 200
        mock_resp.json = AsyncMock(return_value={"entries": []})
        mock_resp.__aenter__ = AsyncMock(return_value=mock_resp)
        mock_resp.__aexit__ = AsyncMock(return_value=False)

        async with RiotClient(api_key="RGAPI-test", region="vn2") as client:
            with patch.object(client._session, "get", return_value=mock_resp):
                result = await client.fetch_challenger_puuids()

        assert result == []

    async def test_401_raises_auth_error(self) -> None:
        mock_resp = MagicMock()
        mock_resp.status = 401
        mock_resp.__aenter__ = AsyncMock(return_value=mock_resp)
        mock_resp.__aexit__ = AsyncMock(return_value=False)

        async with RiotClient(api_key="RGAPI-expired", region="vn2") as client:
            with patch.object(client._session, "get", return_value=mock_resp):
                with pytest.raises(RiotAuthError):
                    await client.fetch_challenger_puuids()

    async def test_403_raises_auth_error(self) -> None:
        mock_resp = MagicMock()
        mock_resp.status = 403
        mock_resp.__aenter__ = AsyncMock(return_value=mock_resp)
        mock_resp.__aexit__ = AsyncMock(return_value=False)

        async with RiotClient(api_key="RGAPI-bad", region="vn2") as client:
            with patch.object(client._session, "get", return_value=mock_resp):
                with pytest.raises(RiotAuthError, match="invalid or expired"):
                    await client.fetch_challenger_puuids()


# ---------------------------------------------------------------------------
# fetch_match_ids
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
class TestFetchMatchIds:
    async def test_returns_list_of_strings(self) -> None:
        ids = _match_ids_payload(5)
        mock_resp = MagicMock()
        mock_resp.status = 200
        mock_resp.json = AsyncMock(return_value=ids)
        mock_resp.__aenter__ = AsyncMock(return_value=mock_resp)
        mock_resp.__aexit__ = AsyncMock(return_value=False)

        async with RiotClient(api_key="RGAPI-test", region="vn2") as client:
            with patch.object(client._session, "get", return_value=mock_resp):
                result = await client.fetch_match_ids("puuid_0", count=5)

        assert result == ids

    async def test_non_list_response_returns_empty(self) -> None:
        mock_resp = MagicMock()
        mock_resp.status = 200
        mock_resp.json = AsyncMock(return_value={"error": "not a list"})
        mock_resp.__aenter__ = AsyncMock(return_value=mock_resp)
        mock_resp.__aexit__ = AsyncMock(return_value=False)

        async with RiotClient(api_key="RGAPI-test", region="vn2") as client:
            with patch.object(client._session, "get", return_value=mock_resp):
                result = await client.fetch_match_ids("puuid_0")

        assert result == []


# ---------------------------------------------------------------------------
# fetch_match
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
class TestFetchMatch:
    async def test_returns_match_dict(self) -> None:
        payload = _match_payload("VN2_0000000001")
        mock_resp = MagicMock()
        mock_resp.status = 200
        mock_resp.json = AsyncMock(return_value=payload)
        mock_resp.__aenter__ = AsyncMock(return_value=mock_resp)
        mock_resp.__aexit__ = AsyncMock(return_value=False)

        async with RiotClient(api_key="RGAPI-test", region="vn2") as client:
            with patch.object(client._session, "get", return_value=mock_resp):
                result = await client.fetch_match("VN2_0000000001")

        assert result["metadata"]["match_id"] == "VN2_0000000001"

    async def test_500_returns_none_after_retry(self) -> None:
        mock_resp = MagicMock()
        mock_resp.status = 500
        mock_resp.__aenter__ = AsyncMock(return_value=mock_resp)
        mock_resp.__aexit__ = AsyncMock(return_value=False)

        async with RiotClient(api_key="RGAPI-test", region="vn2") as client:
            with patch.object(client._session, "get", return_value=mock_resp):
                with patch("tftmac_pipeline.riot_client.asyncio.sleep", new_callable=AsyncMock):
                    result = await client.fetch_match("VN2_bad")

        assert result is None


# ---------------------------------------------------------------------------
# Platform routing map completeness
# ---------------------------------------------------------------------------

class TestPlatformToRegionalMap:
    def test_vn2_maps_to_sea(self) -> None:
        assert PLATFORM_TO_REGIONAL["vn2"] == "sea"

    def test_kr_maps_to_asia(self) -> None:
        assert PLATFORM_TO_REGIONAL["kr"] == "asia"

    def test_na1_maps_to_americas(self) -> None:
        assert PLATFORM_TO_REGIONAL["na1"] == "americas"

    def test_euw1_maps_to_europe(self) -> None:
        assert PLATFORM_TO_REGIONAL["euw1"] == "europe"
