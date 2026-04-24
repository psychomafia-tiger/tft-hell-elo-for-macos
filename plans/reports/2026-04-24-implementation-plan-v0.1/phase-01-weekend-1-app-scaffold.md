# Phase 1 — Weekend 1: App Scaffold + Dogfood

**Status**: blocked by Phase 0
**Duration**: 2 days
**Gate**: Founder dogfood ≥5 TFT sessions với hardcoded tier-list JSON, menu bar popover opens ≤300ms từ Cmd+Shift+T

## Context Links

- Spec: `docs/product-spec-v0.1.md` §Feature 1 (Tier List Popover) + §NFR
- Eng review §1.2 (install.sh), §4.1 (icon preload), §4.3 (non-blocking launch)
- Wireframe (Phase 0 Action #6 output): `docs/wireframe-v0.1-standard-card.md`
- Comp-names schema (spec): `~/TFTMac/config/comp-names.json`

## File Structure (create)

```
App/                                       # Xcode project root
├── TFTMac.xcodeproj/
├── TFTMac/
│   ├── TFTMacApp.swift                    # @main, MenuBarExtra scene
│   ├── Views/
│   │   ├── MenuBarIcon.swift              # Icon state machine
│   │   ├── TierListPopover.swift          # Root popover view
│   │   ├── CompCard.swift                 # Standard depth card (15-20 fields)
│   │   ├── HeaderBar.swift                # Patch + Xh ago + total samples
│   │   └── Banners.swift                  # Offline/Stale/Error banners
│   ├── Models/
│   │   ├── TierList.swift                 # Decodable schema v1.0
│   │   ├── Comp.swift
│   │   ├── Champion.swift
│   │   └── SchemaVersion.swift            # Semver minor-compatible
│   ├── Services/
│   │   ├── DataManager.swift              # R2 fetch + cache fallback chain
│   │   ├── CacheStore.swift               # ~/Library/Application Support/TFTMac/
│   │   ├── IconCache.swift                # Preload icons on popover open
│   │   └── HotkeyRegistrar.swift          # HotKey package wrapper
│   ├── Generated/
│   │   └── ChampionCatalog.swift          # Static TFT Set 14 lookup
│   ├── Assets.xcassets/                   # Champion/item/augment icons
│   └── Resources/
│       ├── Info.plist                     # LSUIElement=true
│       └── sample-tier-list.json          # Hardcoded v0.0.1 dogfood data
└── TFTMacTests/
    ├── SchemaVersionTests.swift
    ├── CacheStoreTests.swift
    ├── DataManagerTests.swift
    ├── IconStateTests.swift
    └── HotkeyRegistrationTests.swift
```

## Tasks Summary (TDD-ordered)

### Task 1.1: Xcode project bootstrap
- Create macOS app target, bundle ID `asia.lab3.tftmac`, deployment target 13.0
- Add `HotKey` Swift package dependency (soffes/HotKey)
- Set `LSUIElement=true` trong Info.plist (menu bar only, no Dock icon)
- Universal Binary architectures (x86_64 + arm64)
- Verify `xcodebuild -scheme TFTMac` succeeds
- Commit bootstrap

### Task 1.2: TDD SchemaVersion (semver minor-compatible)
**Test cases** (5 cycles):
- `1.0.0` accepts `1.0.0` ✓
- `1.0.0` accepts `1.1.0` ✓ (minor forward-compat window)
- `1.0.0` accepts `1.10.0` ✓ (within 10-minor window)
- `1.0.0` rejects `2.0.0` ✗ (major bump)
- `1.0.0` rejects `1.11.0` ✗ (beyond window)

### Task 1.3: TDD TierList + Comp Codable decoding
**Test cases**:
- Valid JSON decodes với all 15-20 fields populated
- Unknown fields ignored gracefully (forward-compat)
- Missing required field → DecodingError
- `comps` sorted by tier (S first) respected
- Fixture: `sample-tier-list.json` (spec example extended to 10 comps)

### Task 1.4: TDD CacheStore (7-day TTL)
**Test cases**:
- Write → read roundtrip returns same TierList
- Read non-existent returns nil
- Cache >7 days old rejected (TTL boundary)
- Corrupt JSON file → returns nil (no crash)
- Disk full write → returns false (no crash)

### Task 1.5: TDD DataManager (fallback chain)
**Test cases** (from eng review §1.7):
1. R2 fresh → use R2
2. R2 fail + cache fresh → use cache
3. R2 fail + cache stale (<24h) → cache + stale banner
4. R2 fail + cache >7 days → empty state
5. Schema mismatch major bump → reject + fallback cache
Mock HTTPClient via protocol injection.

### Task 1.6: TDD IconState machine
**Test cases**:
- initial state = `.default`
- `.startedFetch` → `.loading`
- `.fetchSucceeded` → `.default`
- `.fetchFailed` → `.error`
- `.cacheStale24h` → `.stale`
- Transitions idempotent

### Task 1.7: TDD HotkeyRegistrar conflict detection
**Test cases**:
- Register Cmd+Shift+T succeeds (fresh system)
- Register twice returns conflict error
- Conflict → warning dialog invoked (callback verified via mock)

### Task 1.8: Integration — MenuBarExtra scene + popover wire-up
- `TFTMacApp.swift` with `MenuBarExtra { TierListPopover() }`
- `Task.detached` non-blocking fetch on init (eng review §4.3)
- `iconsPreloaded` state gate với ProgressView placeholder (§4.1)
- Render hardcoded `sample-tier-list.json` bundled resource

### Task 1.9: UI — CompCard render Standard depth
**HARD GATE (CEO review F11.1)**: BLOCKED until `docs/wireframe-v0.1-standard-card.md` exists với locked layout decisions. Nếu file missing, STOP Phase 1 và return Phase 0 Action #6.
```bash
# Guard check (Phase 1 Task 1.9 first step):
test -f docs/wireframe-v0.1-standard-card.md || { echo "BLOCKED: wireframe missing. Run /design-consultation first."; exit 1; }
```

- Per wireframe (Phase 0 Action #6)
- 8 champion icons với carry highlight
- Items per carry (up to 3)
- 2-3 suggested augment icons
- Tier badge color (S=gold, A=silver, B=bronze, C=gray)
- Gray-out styling khi sample_size < 100 (opacity 0.5 + "Low confidence" badge)

### Task 1.10: XCUITest — popover open ≤300ms
```swift
func testPopoverOpensWithin300ms() {
    app.launch()
    let start = Date()
    app.typeKey("t", modifierFlags: [.command, .shift])
    _ = app.otherElements["TierListPopover"].waitForExistence(timeout: 0.5)
    XCTAssertLessThan(Date().timeIntervalSince(start), 0.3)
}
```

### Task 1.11: Founder dogfood ≥5 sessions
- Install local dev build (`xcodebuild -configuration Debug`)
- Play 5 TFT sessions, note UX friction
- Log findings to `docs/weekend-1-dogfood-notes.md`
- If friction ≥ 3 blockers → iterate Weekend 1 extended; else proceed Phase 2

## Success Criteria (Phase 1 gate)

- [ ] All Task 1.2-1.7 tests green (XCTest)
- [ ] Cmd+Shift+T opens popover trong ≤300ms measurable (XCUITest)
- [ ] Hardcoded tier list renders 10 comps, 4 tiers visible
- [ ] No Dock icon (LSUIElement verified via `defaults read`)
- [ ] Memory idle ≤80MB, popover open ≤120MB (Xcode Instruments baseline)
- [ ] Founder ships ≥5 dogfood sessions

## Next Phase

→ `phase-02-weekend-2-pipeline-distribution.md` — real data pipeline + R2 + distribution.
