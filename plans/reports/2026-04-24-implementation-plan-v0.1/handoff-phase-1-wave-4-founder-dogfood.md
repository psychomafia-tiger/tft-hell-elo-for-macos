# Handoff — Phase 1 Wave 4: Task 1.11 Founder Dogfood

**From session**: 2026-04-25 execute session (ID `3613b7ba`)
**To**: anh — Task 1.11 manual dogfood (5+ TFT sessions + visual verify)
**Last commit**: `ad87632` (Task 1.10 polish)

---

## What shipped in Wave 3 (4 commits, 9/10 code tasks done)

| # | Commit | What landed |
|---|---|---|
| 1 | `fd4d5ba` | `feat(app): Task 1.9 CompCard UI wireframe match` |
| 2 | `1e41b60` | `docs(app): address Task 1.9 review I3 (stale inline comment)` |
| 3 | `7767280` | `test(app): Task 1.10 Track A XCUITest cold launch metric` |
| 4 | `ad87632` | `docs(app): address Task 1.10 review polish (typo + CI baseline note)` |

**New files (6)**:
- `App/TFTMac/Views/CompCard.swift` (149 lines)
- `App/TFTMac/Views/CompCardItemsRow.swift` (71 lines)
- `App/TFTMac/Generated/ChampionCatalog.swift` (57 lines, 15 entries + fallback)
- `App/TFTMac/Generated/ItemCatalog.swift` (48 lines, 17 entries + fallback)
- `App/TFTMacUITests/AppLaunchMetricTests.swift` (47 lines, 1 measure block)
- `App/TFTMacUITests/README.md` (Track A + B workflow docs)

**Modified**: `App/TFTMac/Resources/Theme.swift` (+3 Spacing tokens), `App/TFTMac/Views/TierListPopover.swift` (CompCardPlaceholder → CompCard + doc cleanup), `App/TFTMac.xcodeproj/project.pbxproj` (xcodegen regen).

**Test state**: 21/21 unit tests pass. UI test `testColdLaunchUnder500ms` measured **242ms avg** (σ=4.8%, range 227.6–260.8ms) — 258ms headroom vs NFR-3 ceiling 500ms.

**Build state**: Debug (active-arch) + Release (universal arm64+x86_64) both green.

## Phase 1 gate (5/6 items closed by implementation; 1 remaining = Task 1.11)

- [x] Task 1.2, 1.3, 1.5, 1.7 tests green (XCTest 21/21)
- [x] Task 1.10 Track A XCUITest launch metric verifies ≤500ms (242ms measured)
- [x] Track B os_signpost emit trong togglePopover() (wired Task 1.8, verified via `SignpostChannels.swift`)
- [x] Hardcoded `sample-tier-list.json` render đúng 10 comps S/A/B tier — **CODE DONE, visual verify pending Task 1.11**
- [x] No Dock icon (LSUIElement=true confirmed Task 1.1)
- [ ] **Founder dogfood ≥5 TFT sessions + visual verify** — anh tự làm

## Task 1.11: what anh cần làm

Per `phase-01-weekend-1-app-scaffold.md` lines 195-206:

1. **Install local dev build**:
   ```bash
   cd "/Users/mac/Desktop/TFTTACTICS FOR MACS/App" && xcodebuild -project TFTMac.xcodeproj -scheme TFTMac -configuration Debug build
   open /Users/mac/Library/Developer/Xcode/DerivedData/TFTMac-*/Build/Products/Debug/TFTMac.app
   ```
   First launch sẽ prompt Accessibility permission (TCC) — enable trong System Settings → Privacy → Accessibility cho Cmd+Shift+T hotkey work.

2. **Chơi ≥5 TFT sessions** (trong Set 17 — TFT live hiện tại). Mỗi session note UX friction (ma sát trải nghiệm) lên `docs/weekend-1-dogfood-notes.md`.

3. **Visual verify checklist mỗi session** (thay cho snapshot test, per eng review decision #5):
   - Mở popover bằng Cmd+Shift+T, screenshot, compare với `docs/wireframes/popover-styleA-v2.png`
   - S/A/B tier colors = gold/silver/bronze đúng
   - BIS carry có 2px border đúng tier color (S tier carry = gold border, A = silver, B = bronze)
   - % numbers render bằng SF Mono
   - "Flex" label hiện cho champions có items array empty (ví dụ TFT17_Rhaast trong `storm-quickdraw` comp)
   - Low-confidence (opacity 0.5 + inline badge) hiện cho comps <100 matches (fixture có 3: `kaisa-hyper` 95, `aatrox-frontline` 68, `nami-support` 42)

4. **Track B popover latency** (optional, nếu muốn đo chính xác):
   ```bash
   log collect --start "5 min ago" --output /tmp/popover.logarchive
   open /tmp/popover.logarchive
   ```
   Xem `App/TFTMacUITests/README.md` cho full Instruments workflow. Hoặc bấm stopwatch subjectively — target "snappy" (<300ms perceptual).

5. **Decision gate**: nếu ≥3 blockers thì iterate Weekend 1 extended; else proceed Phase 2 Wave 1 (Riot API pipeline + R2).

## Known deferred polish items (anh có thể batch sau Task 1.11)

Từ Task 1.9 + 1.10 code reviews:

### Accessibility (CompCard)
- **I1**: CompCard thiếu `.accessibilityElement(children: .combine)` + label → VoiceOver user nghe 30 Text fragments rời rạc cho 3 cards. Fix ~10 phút trong a11y polish pass sau dogfood.
- **I2**: TierBadge riêng lẻ chỉ đọc "S"/"A"/"B" không context. Resolves tự động nếu fix I1.

### Minor polish
- **M1** (CompCard.swift:127): hardcoded `.font(.system(size: 10, weight: .bold))` cho portrait initials — nên thành `Theme.Fonts.portraitInitials` token mới. Defer tới Phase 2 khi swap sang real icon assets (sẽ rewrite ChampionPortrait anyway).
- **M2** (CompCardItemsRow.swift:38): `.lineLimit(1)` chưa explicit `.truncationMode(.tail)` — dogfood sẽ expose nếu truncate xấu.
- **Task 1.10 nits**: test method name `testColdLaunchUnder500ms` implies absolute assertion nhưng thực tế là baseline diff (đã note trong doc comment). Có thể rename `testColdLaunchMetric()` ở polish pass. Low priority — file doc + README đã giải thích.

## Next session (Phase 2 Wave 1) will need

- Riot API key (Dev key, 100 req / 2 min)
- GitHub Actions secrets setup cho cron job
- Cloudflare R2 bucket credentials
- TFT17 Community Data Dragon icon URLs cho catalog swap (ChampionCatalog + ItemCatalog swap `iconAsset: nil` → real URLs)

## Quick commands

```bash
# Run full unit suite
cd "/Users/mac/Desktop/TFTTACTICS FOR MACS/App" && xcodebuild -project TFTMac.xcodeproj -scheme TFTMac -configuration Debug test -only-testing:TFTMacTests

# Run UI test (cold launch metric)
cd "/Users/mac/Desktop/TFTTACTICS FOR MACS/App" && xcodebuild -project TFTMac.xcodeproj -scheme TFTMac -configuration Debug test -only-testing:TFTMacUITests

# Build for dogfood (Debug, launches via open command above)
cd "/Users/mac/Desktop/TFTTACTICS FOR MACS/App" && xcodebuild -project TFTMac.xcodeproj -scheme TFTMac -configuration Debug build

# Regen project.pbxproj after adding/removing .swift files
cd "/Users/mac/Desktop/TFTTACTICS FOR MACS/App" && xcodegen generate
```

## Report template for end of Task 1.11

```
Status: DONE | ITERATE
Sessions logged: N/5 minimum
Friction blockers: [list, 0-N]
Visual verify: [pass|fail per wireframe checklist]
Next: Phase 2 Wave 1 (pipeline + R2) | Weekend 1 extended
```
