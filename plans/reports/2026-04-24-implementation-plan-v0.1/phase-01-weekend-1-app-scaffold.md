# Phase 1 — Weekend 1: App Scaffold + Dogfood

**Status**: UNBLOCKED (Phase 0 gate 12/12 passed 2026-04-24)
**Duration**: 2 days
**Gate**: Founder dogfood ≥5 TFT sessions với hardcoded tier-list JSON, menu bar popover opens ≤300ms từ Cmd+Shift+T

## Eng Review Decisions (2026-04-24, locked)

Plan đã qua `/plan-eng-review`. Decisions ghi nhận:

1. **Scope REDUCED** — Tasks 1.4 (CacheStore), 1.5 (DataManager fallback chain), 1.6 (IconState 5-state) cắt xuống minimal stub. Full fallback + cache + error states built in Phase 2 khi wire R2 thật. Saves ~5h.
2. **MenuBarExtra locked** — dùng SwiftUI `MenuBarExtra` scene (macOS 13+), KHÔNG dùng NSStatusItem manual. Plan.md references cần xoá.
3. **Sandbox OFF + in-app permission prompt** — App Sandbox disabled trong entitlements. Task 1.7 HotkeyRegistrar thêm logic detect Accessibility permission denied → SwiftUI alert + deep-link `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`.
4. **Task 1.10 rewrite per pre-spike** — XCUITest popover code cũ fails (macOS 14+ TCC chặn NSStatusItem access). Split Track A (XCTApplicationLaunchMetric, viable 194ms baseline) + Track B (os_signpost trong-app + manual stopwatch).
5. **UI test deferred** — CompCard snapshot test skip Phase 1, dogfood Task 1.11 thêm visual verify checklist. Snapshot test defer Phase 3 khi build CI.
6. **Task 1.1 additions**: `CODE_SIGN_IDENTITY='-'` + `CODE_SIGN_STYLE=Manual` cho test targets (pre-spike finding). Tạo `TFTMac/Resources/Theme.swift` từ wireframe tokens (colors/typography/spacing).
7. **Gap fix**: thêm `TFTMac/Generated/ItemCatalog.swift` static lookup cho BIS items (pivot 2026-04-24 cần item icon + display name resolve).

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
│   │   ├── DataManager.swift              # loadBundledJSON() only (Phase 1 reduced; Phase 2 add R2 fetch + fallback)
│   │   ├── IconCache.swift                # Preload icons on popover open
│   │   └── HotkeyRegistrar.swift          # HotKey package wrapper + AXIsProcessTrusted() permission prompt
│   ├── Generated/
│   │   ├── ChampionCatalog.swift          # Static TFT Set 17 lookup (id → name + icon asset)
│   │   └── ItemCatalog.swift              # Static TFT_Item_* lookup (pivot 2026-04-24, BIS items need icon + name resolve)
│   ├── Assets.xcassets/                   # Champion + core item icons (no augment icons per 2026-04-24 pivot)
│   └── Resources/
│       ├── Info.plist                     # LSUIElement=true
│       ├── TFTMac.entitlements            # App Sandbox DISABLED (eng review decision #3)
│       ├── Theme.swift                    # Color/Font/Spacing tokens from wireframe-v0.1-standard-card.md
│       └── sample-tier-list.json          # Hardcoded v0.0.1 dogfood data (BIS items per-champion schema)
└── TFTMacTests/
    ├── SchemaVersionTests.swift           # 5 cases (Task 1.2)
    ├── TierListDecodingTests.swift        # 5 cases (Task 1.3)
    ├── DataManagerTests.swift             # 2 cases (reduced from 5)
    ├── HotkeyRegistrationTests.swift      # 4 cases (added permission detection)
    └── regression/
        └── SampleTierListFixtureTests.swift # NEW (eng review T4): decode sample-tier-list.json → snapshot expected TierList, lock data contract Phase 1↔Phase 2
└── TFTMacUITests/
    ├── AppLaunchMetricTests.swift         # Task 1.10 Track A (XCTApplicationLaunchMetric)
    └── README.md                          # Notes: popover open latency measured via os_signpost trong-app + manual stopwatch (Track B)
```

## Tasks Summary (TDD-ordered)

### Task 1.1: Xcode project bootstrap
- Create macOS app target, bundle ID `asia.lab3.tftmac`, deployment target 13.0
- Add `HotKey` Swift package dependency (soffes/HotKey)
- Set `LSUIElement=true` trong Info.plist (menu bar only, no Dock icon)
- Universal Binary architectures (x86_64 + arm64)
- **App Sandbox DISABLED** trong `.entitlements` (eng review decision #3)
- **Test target signing**: `CODE_SIGN_IDENTITY='-'` + `CODE_SIGN_STYLE=Manual` (ad-hoc, pre-spike finding — tránh Gatekeeper "damaged and can't be opened" on XCUITest runner)
- **Create `TFTMac/Resources/Theme.swift`** — tokens từ `docs/wireframe-v0.1-standard-card.md` (Color.bgPopover, Color.bgCard, Color.accentGold/Silver/Bronze, Font.cardTitle, Spacing.cardPadding, etc.). DRY source of truth cho Views.
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

### Task 1.4: ~~TDD CacheStore~~ — **CUT (eng review scope reduction)**
Deferred to Phase 2 Task 2.13 (app fetch từ R2 integration). Không cache logic trong Phase 1 vì không có fetch, data bundled vào app binary.

### Task 1.5: DataManager minimal — `loadBundledJSON()` only
**Test cases** (2 cases, reduced from 5):
- Happy path: `sample-tier-list.json` in bundle → decode thành TierList struct (dùng TierList từ Task 1.3)
- Missing bundle resource → `fatalError` (critical resource absent = broken build, not runtime concern)

Full fallback chain (R2 fresh / cache fresh / stale / 7-day reject / schema mismatch) **deferred to Phase 2 Task 2.13**.

### Task 1.6: IconState minimal — `.default` only
Single-case enum với TODO comment cho Phase 2 expansion:
```swift
enum IconState {
    case `default`
    // Phase 2: .loading, .error, .stale, .cacheOnly (eng review decision #1)
}
```
5-state machine full logic defer Phase 2 khi có fetch thật.

### Task 1.7: TDD HotkeyRegistrar — register + conflict + permission detection
**Test cases** (expanded post eng review):
- Register Cmd+Shift+T succeeds (fresh system)
- Register twice returns conflict error
- Conflict → warning dialog callback invoked (via mock)
- **Accessibility permission denied** → detect via `AXIsProcessTrusted()` → invoke `permissionPromptCallback` (new)

**Permission UX flow (new per eng review decision #3)**:
```swift
// On first app launch (or any launch where AXIsProcessTrusted() == false):
if !AXIsProcessTrusted() {
    showAlert(
        title: "TFT Mac cần quyền Accessibility",
        message: "Để bắt hotkey Cmd+Shift+T khi anh đang chơi TFT, cần tick TFT Mac trong System Settings → Privacy & Security → Accessibility.",
        primaryButton: "Mở System Settings" → open deep-link,
        secondaryButton: "Bỏ qua (click icon menu bar thay cho hotkey)"
    )
}
// Deep-link URL:
// x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility
```

### Task 1.8: Integration — MenuBarExtra scene + popover wire-up
- `TFTMacApp.swift` with `MenuBarExtra("TFT Mac", systemImage: "chart.bar.xaxis") { TierListPopover() }`
- **Sync bundle load** (NO `Task.detached` — over-engineering cho static bundle, eng review C1): `let data = Bundle.main.url(forResource: "sample-tier-list", ...)` → decode → render
- `iconsPreloaded` state gate với ProgressView placeholder (§4.1) — icon preload defer đến first popover open, KHÔNG app init (preserve 500ms launch budget)
- Render hardcoded `sample-tier-list.json` bundled resource
- **No NSStatusItem references** — MenuBarExtra internally handles status item (eng review decision #2)

### Task 1.9: UI — CompCard render Standard depth
**HARD GATE (CEO review F11.1)**: BLOCKED until `docs/wireframe-v0.1-standard-card.md` exists với locked layout decisions. Nếu file missing, STOP Phase 1 và return Phase 0 Action #6.
```bash
# Guard check (Phase 1 Task 1.9 first step):
test -f docs/wireframe-v0.1-standard-card.md || { echo "BLOCKED: wireframe missing. Run /design-consultation first."; exit 1; }
```

- Per wireframe (Phase 0 Action #6)
- 8 champion icons với carry highlight
- **BIS items per core champion (up to 3 items, with agreement % badge)** — replaces previous "items per carry + suggested augment icons"
- Agreement display: `"77%"` small badge next to each item icon (e.g. Jeweled Gauntlet 77%)
- "Flex" label shown when a core champion has empty items array (no item ≥ 40% agreement in aggregated top-4 boards)
- Tier badge color (S=gold, A=silver, B=bronze, C=gray)
- Gray-out styling khi sample_size < 100 (opacity 0.5 + "Low confidence" badge)

### Task 1.10: Perf measurement — Track A (XCUITest launch metric) + Track B (signpost)

**Original plan BROKEN** per `docs/pre-spike-xcuitest-menubar.md`: macOS 14+ TCC ngăn XCUITest reach NSStatusItem, `typeKey` approach fails. Rewrite theo pre-spike split strategy:

**Track A — XCUITest cold launch latency** (CI-enforceable):
```swift
func testAppLaunchUnder500ms() {
    measure(metrics: [XCTApplicationLaunchMetric()]) {
        XCUIApplication().launch()
    }
    // Baseline: 194ms (pre-spike throwaway app). TFTMac budget: ≤500ms.
}
```

**Track B — In-app popover open latency** (signpost + manual):
```swift
// In TFTMacApp.swift or TierListPopover ViewModel:
import os.signpost
let signpostID = OSSignpostID(log: .default)

func togglePopover() {
    os_signpost(.begin, log: .default, name: "popover.open", signpostID: signpostID)
    // ... popover.show() logic ...
    os_signpost(.end, log: .default, name: "popover.open", signpostID: signpostID)
}
```

Measure via: `log collect --start "5 min ago" --output popover.logarchive` → Xcode Instruments → Points of Interest track → đọc duration giữa begin/end.

**Manual stopwatch fallback** (dogfood):
- Task 1.11 dogfood: founder press Cmd+Shift+T, stopwatch trên điện thoại, log 10 trials. Acceptable cho v0.1 (10 tester scale).
- Target: ≤300ms perceived. Chấp nhận nếu founder thấy "snappy" dù không đo được chính xác sub-300.

### Task 1.11: Founder dogfood ≥5 sessions + visual verify
- Install local dev build (`xcodebuild -configuration Debug`)
- Play 5 TFT sessions, note UX friction
- **Visual verify checklist mỗi session** (replaces snapshot test, eng review decision #5):
  - Mở popover, screenshot, compare với `docs/wireframes/popover-styleA-v2.png`
  - Check S/A/B tier colors đúng gold/silver/bronze
  - Check BIS carry có 2px border đúng tier color
  - Check % numbers render bằng SF Mono
  - Check "Flex" label cho Rhaast (empty items)
  - Check low-confidence grayed nếu có comp sample <100 trong fixture
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

---

## NOT in Scope Phase 1 (defer to Phase 2/3)

| Item | Defer to | Rationale (ngắn gọn) |
|---|---|---|
| CacheStore 7-day TTL + corrupt JSON handling | Phase 2 Task 2.13 | No fetch trong Phase 1 → không cache logic |
| DataManager fallback chain (R2 fresh / cache / stale banner / 7-day reject / schema mismatch) | Phase 2 Task 2.13 | Depends on R2 setup (Phase 2) |
| IconState 4 trạng thái (.loading, .error, .stale, .cacheOnly) | Phase 2 | Chỉ reachable khi có real fetch |
| XCUITest popover open latency (Cmd+Shift+T simulate) | DEFERRED v0.2 | Pre-spike proved không viable trên macOS 14+ (TCC boundary) |
| CompCard snapshot tests (pointfreeco/swift-snapshot-testing) | Phase 3 testing | Weekend 1 setup cost không worth cho 10-tester scope; dogfood visual verify đủ |
| Dark/Light mode dual support | v0.2 | Wireframe chỉ spec dark mode cho v0.1 |
| Settings UI (hotkey rebind, icon toggle) | v0.1.1 | v0.1 hardcode Cmd+Shift+T |
| Riot Production key integration | Phase 2 | Pending review ~1-4 weeks, Dev key fallback đủ cho Phase 1 |

## What Already Exists (không build lại)

| Capability | Source | Phase 1 usage |
|---|---|---|
| Menu bar icon + status item lifecycle | SwiftUI `MenuBarExtra` (macOS 13+) | Task 1.8 — 3 dòng khai báo scene, Apple manage |
| Global hotkey (Carbon event tap) | `soffes/HotKey` Swift package | Task 1.7 — wrap trong HotkeyRegistrar |
| App launch cold-start metric | `XCTApplicationLaunchMetric()` built-in XCTest | Task 1.10 Track A |
| JSON decoding | Swift `Codable` protocol | Task 1.3 TierList decode |
| Accessibility permission check | `AXIsProcessTrusted()` AppKit API | Task 1.7 permission detection |
| Deep-link to System Settings | `x-apple.systempreferences:com.apple.preference.security?...` URL scheme | Task 1.7 permission prompt |
| Signpost instrumentation | `os.signpost` built-in | Task 1.10 Track B |

## Failure Modes (per new codepath)

| Codepath | Realistic failure | Test coverage? | Error handling? | User-visible? |
|---|---|---|---|---|
| `DataManager.loadBundledJSON()` | Bundle resource missing | ✅ test fatalError | `fatalError` (broken build) | N/A — ship-time bug, won't reach users |
| `TierList.init(from: decoder)` | Unknown `tier` enum value | ✅ missing field test | `DecodingError` propagated | Blank popover (no data) |
| `HotkeyRegistrar.register()` | System-level conflict (e.g. Rectangle cũng dùng Cmd+Shift+T) | ❌ manual only | Callback warning invoked | Alert dialog on launch |
| `HotkeyRegistrar` permission check | User từ chối Accessibility grant | ❌ manual only | SwiftUI alert với deep-link | Alert + Settings button |
| `MenuBarExtra` scene render | SwiftUI render crash (unlikely) | ❌ XCUITest launch captures | Crash → dock reports | App won't show icon |
| `TierListPopover` first render | 10 comps × 4 champions × 3 items = ~120 icon loads | ❌ manual dogfood | IconCache lazy load with ProgressView placeholder | Brief loading spinner (~200ms) |

**Critical gaps flagged**: 1 — HotkeyRegistrar **system-level conflict** (Cmd+Shift+T đã bound bởi Alfred/Rectangle/Raycast) không test tự động được. Mitigation: dogfood checklist manual verify + document "nếu hotkey không work, check app khác có dùng Cmd+Shift+T không".

## Worktree Parallelization Strategy

Phase 1 solo founder, **sequential implementation recommended** để giảm coordination cost. Nhưng nếu anh muốn parallel (ví dụ khi delegate subagents), dependency table:

| Task | Modules touched | Depends on |
|---|---|---|
| 1.1 Bootstrap + Theme.swift | Xcode config, Resources/ | — |
| 1.2 SchemaVersion | Models/ | 1.1 |
| 1.3 TierList Codable | Models/ | 1.1 |
| 1.5 DataManager (reduced) | Services/ | 1.3 (TierList model) |
| 1.7 HotkeyRegistrar | Services/ | 1.1 |
| 1.8 MenuBarExtra integration | TFTMacApp.swift | 1.5, 1.7 |
| 1.9 CompCard UI | Views/, Generated/ItemCatalog.swift | 1.3, 1.1 (Theme) |
| 1.10 Launch metric + signpost | UITests/, TFTMacApp signpost instrumentation | 1.8 |
| 1.11 Dogfood | — (manual) | 1.9, 1.10 |

**Lanes** nếu parallel:
- **Lane A** (sequential): 1.1 → 1.2 → 1.3 → 1.5 → 1.8 (Models + Services + integration)
- **Lane B** (parallel với A after 1.1): 1.7 (HotkeyRegistrar) + 1.9 (CompCard UI depends on 1.3 only)
- **Lane C** (after 1.8): 1.10 (perf) + 1.11 (dogfood)

**Conflict flag**: Lane A và Lane B cả 2 đều edit `Services/` (1.5 + 1.7) — careful coordination hoặc sequential để tránh merge conflict.

## Completion Summary (eng review)

- Step 0 Scope Challenge: **scope reduced per recommendation** (Tasks 1.4 CUT, 1.5 minimal, 1.6 minimal, 1.10 rewritten per pre-spike)
- Architecture Review: **2 issues resolved** (MenuBarExtra locked, Sandbox OFF + permission prompt)
- Code Quality Review: **3 issues noted** (Task.detached over-eng, ItemCatalog gap, Theme.swift extraction) — all absorbed into plan
- Test Review: **4 gaps identified** (UI test strategy → B manual dogfood, DataManager happy path test added, HotkeyRegistrar permission detection test added, regression fixture test added Task T4)
- Performance Review: **0 issues** (launch budget 194→254ms projected, 246ms headroom; no N+1)
- NOT in scope: 8 items documented
- What already exists: 7 capabilities leveraged (not rebuilt)
- TODOS.md: N/A (file không tồn tại trong project, inline vào plan)
- Failure modes: 1 critical gap flagged (hotkey system-level conflict — manual mitigation)
- Outside voice: SKIPPED (Codex không có; Claude subagent overhead không worth cho scope đã discussed)
- Parallelization: 3 lanes identified, recommend sequential cho solo founder
- Lake Score: 3/4 recommendations chose complete option (scope reduced but permission prompt + signpost + Theme tokens = complete; snapshot test deferred là pragmatic defer, không skip)

## Unresolved Decisions (none — all resolved 2026-04-24)

Empty — anh đã decide rõ 4 câu trong review session.

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | Skipped — scope đã locked qua product-spec approval 2026-04-23 |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | — | Codex CLI chưa install, defer |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | CLEAR (PLAN) | 4 issues → all resolved: scope reduced + MenuBarExtra + Sandbox OFF + UI manual verify |
| Design Review | `/plan-design-review` | UI/UX gaps | 0 | — | Wireframe v2 locked 2026-04-24, defer full design review v0.2 |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | Solo founder = self-reviewed, defer |

- **UNRESOLVED:** 0
- **VERDICT:** ENG CLEARED — ready to implement Phase 1 Wave 2
