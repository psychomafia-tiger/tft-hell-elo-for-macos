# Research — TFT-League-v1 endpoint specs

## Why dedicated TFT-League-v1 (not League-v4)

TFT has its own League endpoints separate from the LoL `/lol/league/v4/...` family. Using LoL endpoints against TFT data returns wrong queue type. **Always use `/tft/league/v1/...`**.

## Endpoints

### Challenger (highest tier, what we use)

```
GET https://{platform}.api.riotgames.com/tft/league/v1/challenger
```

Response (verified KR Set 17, 2026-04-24):
```json
{
  "tier": "CHALLENGER",
  "leagueId": "...",
  "queue": "RANKED_TFT",
  "name": "...",
  "entries": [
    {
      "puuid": "78-char-string",
      "leaguePoints": 1250,
      "rank": "I",
      "wins": 145,
      "losses": 132,
      "veteran": true,
      "inactive": false,
      "freshBlood": false,
      "hotStreak": true
    },
    ...
  ]
}
```

For Phase 01: extract `entries[].puuid`. Ignore everything else.

### Grandmaster (next tier down — fallback if Challenger empty)

```
GET https://{platform}.api.riotgames.com/tft/league/v1/grandmaster
```

Same response shape. **Not used in Phase 01** (Challenger sample sufficient for v0.1; if VN2 Challenger empty, fallback is plan-unresolved-Q #3).

### League by ID (NOT used)

`/tft/league/v1/leagues/{leagueId}` — get full league context. Not needed for our pipeline.

### Top by queue (NOT used in v0.1)

`/tft/league/v1/rated-ladders/{queue}/top` — same as Challenger essentially for the standard queue. Skip for v0.1.

## Region availability

VN2 confirmed valid platform string. KR / NA1 / EUW1 / JP1 also confirmed. Smaller regions may have empty Challenger ladder briefly during set transitions.

## Rate limit consumption

1 request per pipeline run. Negligible.

## Open: VN2 Challenger size

Concrete unknown: how many active VN2 Challenger entries? KR returned ~300. VN2 likely 50-200.

If 50 PUUIDs × 20 ranked matches/PUUID = 1000 match IDs (with significant dedup, real unique ~500-700). Acceptable for tier list signal (sample size ≥30 per comp threshold met for top ~10 comps).

If <50 PUUIDs returned → may need to relax to Challenger + Grandmaster combined. Phase 01 logs WARNING + continues with whatever it has. Anh sees in workflow logs.
