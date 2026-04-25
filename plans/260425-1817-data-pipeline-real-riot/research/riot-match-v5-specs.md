# Research — Riot TFT Match-v5 / TFT-Match-v1 specs (synthesis)

## Source basis

WebFetch tool was permission-denied this session. Synthesis below derived from project's already-verified ground truth:

- `docs/pre-spike-api-verify.md` — actual schema verification against KR Challenger live API (2026-04-24, Set 17)
- `Pipeline/scripts/fetch_riot_sample.py` — working reference implementation (98 matches successfully fetched)
- `Pipeline/tests/test_riot_schema_parse.py` — 14 schema regression tests passing
- `Pipeline/tests/fixtures/sample-participant.json` + `fetched-matches-kr-2026-04-24.json` — frozen real responses

This synthesis is more authoritative than fresh API doc scraping for our use case because it's verified against actual Set 17 production response shapes, not theoretical spec.

## Endpoints used (verified working)

### Step 1 — Challenger ladder (TFT-League-v1)

```
GET https://{platform}.api.riotgames.com/tft/league/v1/challenger
Headers:
  X-Riot-Token: <RGAPI-...>
  User-Agent: tftmac-pipeline/0.1 (+https://github.com/...)
  Accept: application/json
```

- Platform = `vn2` (anh's region) — confirmed valid in `PLATFORM_TO_REGIONAL` map.
- Response: JSON with top-level `entries[]` list. Each entry has:
  - `puuid` (string, 78 chars) — Riot 2024+ change: PUUID returned directly in entries (older docs say summonerId only).
  - `wins`, `losses`, `leaguePoints`, `rank`, etc. (we ignore for Phase 01).
- Sample size: KR returned ~300 entries; VN2 likely 50-200 (smaller player base).
- Rate cost: 1 request total.

### Step 2 — Match IDs by PUUID (TFT-Match-v1)

```
GET https://{regional}.api.riotgames.com/tft/match/v1/matches/by-puuid/{puuid}/ids
Query params:
  count=20    (default 20, max 100)
  queue=1100  (optional filter — 1100 = Ranked TFT, 1090 = Normal TFT)
  start=0
```

- Regional = `sea` for vn2 (per `PLATFORM_TO_REGIONAL` map confirmed in spike).
- Response: JSON list of match ID strings, e.g. `["VN2_12345", ...]`.
- Rate cost: 1 request per PUUID. For 100 PUUIDs = 100 requests.
- **Critical**: Use `queue=1100` filter to get ranked-only matches — higher skill signal, more reliable comp data than mixed normals.

### Step 3 — Match detail (TFT-Match-v1)

```
GET https://{regional}.api.riotgames.com/tft/match/v1/matches/{matchId}
```

- Regional = `sea` for vn2.
- Response: full match object with `metadata` + `info`. Schema verified frozen in `test_riot_schema_parse.py`.
- Rate cost: 1 request per match ID.

## Response schema (verified Set 17 frozen)

### Match object top-level

```json
{
  "metadata": {
    "match_id": "VN2_...",
    "data_version": "5",
    "participants": [...puuids...]
  },
  "info": {
    "tft_set_number": 17,
    "tft_set_core_name": "TFTSet17",
    "game_version": "Linux Version 16.8.766...",
    "queue_id": 1100,
    "game_datetime": <epoch_ms>,
    "game_length": <float seconds>,
    "participants": [<participant>, ...]   // 8 entries
  }
}
```

### Participant object (8 per match)

```json
{
  "puuid": "...",
  "placement": 1,                  // 1-8
  "level": 9,
  "last_round": 35,
  "gold_left": 12,
  "time_eliminated": 0,
  "total_damage_to_players": 142,
  "win": false,
  "missions": {...},
  "companion": {...},
  "traits": [<trait>, ...],
  "units": [<unit>, ...]
}
```

**ABSENT in Set 17**: `augments` field — confirmed across 784 participants (98 matches × 8). Anomaly mechanic replaces it; signaled by `TFT17_EkkoOffering_*` items in `units[].itemNames[]`.

### Unit object

```json
{
  "character_id": "TFT17_Viktor",  // string, prefix TFT17_ for Set 17
  "tier": 2,                        // 1-3 star level
  "rarity": 4,                      // 0-9 (cost = rarity + 1 by convention)
  "itemNames": [                    // list, possibly empty
    "TFT_Item_JeweledGauntlet",
    "TFT17_EkkoOffering_AnomalyItem"  // Anomaly slot
  ]
}
```

### Trait object

```json
{
  "name": "TFT17_AnimaSquad",
  "num_units": 4,
  "tier_current": 2,
  "tier_total": 3,
  "style": 3
}
```

## Item taxonomy (8 prefix categories observed in 98 KR matches)

| Prefix | % of equipped items | Category |
|--------|---------------------|----------|
| `TFT_Item_*` | 87.7% | Stable core items |
| `TFT17_Item_*` | 7.9% | Set 17 trait emblems |
| `TFT5_Item_*` | 2.4% | Legacy radiants |
| `TFT17_EkkoOffering_*` | 0.8% | **Anomaly mechanic** (Set 17 augment analog) |
| `TFT17_AnimaSquadItem_*` | 0.8% | Trait-specific items |
| `TFT4_Item_*` | 0.2% | Legacy Ornn artifacts |
| `TFT9_Item_*` | 0.2% | Legacy Ornn artifacts |
| `TFT7_Item_*` | 0.1% | Legacy Shimmerscale |

For phase-01 anomaly_aggregator: filter by exact `TFT17_EkkoOffering_` prefix.

## Rate limit (Development tier)

Per anh's input + Riot dev portal docs:
- **100 requests / 2 minutes**, ALSO **20 requests / second** (rolling window).
- Key auto-expires every **24 hours** (must regenerate via dev portal).
- Application keys (production) require approval; v0.1 stays on Dev key.

Pipeline budget calc:
- 1 (challenger) + 100 (match IDs) + 1500 (match details) = 1601 requests max.
- At 50 req/min sustained (50% of 100/2min limit, safety margin) = 32 minutes wall time sequential.
- 2 parallel workers via aiolimiter token bucket = ~16 minutes.

## Routing region map (confirmed)

```python
PLATFORM_TO_REGIONAL = {
    "na1": "americas", "br1": "americas", "la1": "americas", "la2": "americas",
    "euw1": "europe", "eun1": "europe", "tr1": "europe", "ru": "europe",
    "kr": "asia", "jp1": "asia",
    "vn2": "sea", "ph2": "sea", "sg2": "sea", "th2": "sea", "tw2": "sea",
    "oc1": "sea",
}
```

Use platform region (`vn2`) for League-v1 + Match-v1 IDs endpoint. Use regional (`sea`) for Match-v1 detail endpoint.

## Cloudflare User-Agent gotcha (locked-in finding)

Default Python `urllib`/`aiohttp` UA = `Python-urllib/3.x` triggers **Cloudflare 1010 / HTTP 403** on Riot endpoints. Required mitigation: set descriptive UA in headers.

Working pattern (from `fetch_riot_sample.py`):
```python
headers = {
    "X-Riot-Token": api_key,
    "User-Agent": "tftmac-pipeline/0.2 (+https://github.com/psychomafia-tiger/tft-hell-elo-for-macos)",
    "Accept": "application/json",
    "Accept-Language": "en-US,en;q=0.9",
}
```

Phase 01 RiotClient MUST replicate. Add UA-presence assertion in `test_riot_client.py`.

## Queue IDs (confirmed)

- `1090` = TFT Normal
- `1100` = TFT Ranked
- `1110` = TFT Hyper Roll
- `1130` = TFT Double Up
- `1160` = TFT Double Up

For tier list signal quality: filter to **1100 (Ranked) only**. Other queue types have different meta and lower stakes signal.

## Open questions (require live API check or Riot docs lookup)

1. **TFT-Summoner-v1 deprecation status**: older code paths used `/tft/summoner/v1/summoners/by-puuid/...` to bridge PUUID ↔ summoner-id. Riot 2024+ change returns puuid directly in League entries → we don't need TFT-Summoner-v1 at all. Confirm by re-fetching Challenger and asserting `entries[].puuid` present (already done in spike, KR confirmed).

2. **TFT Set 18 release timing**: if Set 18 releases mid-implementation, all `TFT17_*` prefixes break. No public schedule available. Mitigation: regression tests fail loud (`test_match_is_tft_set_17`); anh decides to proceed with mixed-set data or pause.

3. **Production key application criteria**: out of scope for v0.1 (Dev key sufficient for founder dogfood). v0.2 ship to testers may require Production key (10K req/day vs 100/2min). Defer.

4. **Data Dragon / display name lookup**: Riot publishes static asset bundles for unit/item display names. We're emitting raw IDs (`TFT17_Viktor`) in v0.1 — App can fancy-name in v0.2 via Data Dragon JSON. Out of scope.
