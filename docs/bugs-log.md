# Bugs Log — TFT Hell Elo

Append-only log of bugs encountered, fixed, and deferred. New entries go at the bottom; never edit historic entries (only update Status field if bug closes).

**Status icons**:
- ✅ Fixed
- ⏳ Deferred (workaround documented)
- ❌ Unfixed (no workaround yet)

**Format**: each entry uses sections: Status, Phase, Symptom, Root cause, Fix/Workaround, Lesson.

---

## Bug #001 — TCC cdhash invalidation on adhoc rebuild

- **Status**: ✅ Fixed (2026-04-25)
- **Phase**: Wave 5d hotkey
- **Symptom**: `Cmd+Shift+T` silent fail (no log output, no event triggered) sau xcodebuild rebuild. App appears in System Settings → Privacy → Accessibility but permission silently invalidated.
- **Root cause**: macOS Tahoe TCC (Transparency, Consent, and Control) re-validates app identity by cdhash. Adhoc-signed rebuild produces new cdhash → previously granted Accessibility permission auto-revoked. NSLog output is dead in adhoc builds (sandboxed/unsigned context).
- **Fix**: After every xcodebuild rebuild during dev, manually re-grant Accessibility permission (toggle off/on in System Settings). For diagnostics, use `os.Logger` (visible in Console.app) instead of NSLog.
- **Lesson**: Document in `system-architecture.md` § "macOS Permissions" + dev runbook step "after xcodebuild → check TCC". Permanent fix requires Developer ID certificate signing.

---

## Bug #002 — TFT fullscreen exclusive keyboard capture

- **Status**: ⏳ Deferred to Phase 2 (workaround documented)
- **Phase**: Wave 5d
- **Symptom**: `Cmd+Shift+T` hotkey không trigger khi TFT đang ở native fullscreen mode. Hotkey hoạt động normal khi TFT windowed hoặc borderless fullscreen.
- **Root cause**: macOS native fullscreen mode bypasses Carbon HotKey API (`RegisterEventHotKey`). Only the foreground app (TFT in fullscreen) receives keyboard events; background apps (our menu bar) cannot intercept.
- **Workaround (current)**: TFT borderless fullscreen mode supports global hotkey. 9 testers (when shipped) instructed to use borderless option in TFT settings.
- **Permanent fix needed**: Switch from Carbon HotKey API to `NSEvent.addGlobalMonitor(forEventsMatching: .keyDown)` + Accessibility permission approach. Estimated 4-6h implementation. Borderless restriction acceptable for v0.1 founder dogfood.
- **Lesson**: Re-evaluate when shipping testers if borderless adoption < 80% via PostHog event tracking.

---

## Bug #003 — Git history bloat from cron commits (anticipated, deferred year-2)

- **Status**: ⏳ Deferred to v0.2 (no impact in v0.1)
- **Phase**: data-pipeline-real-riot (anticipated, not yet observed)
- **Symptom**: 12h cron × 365 days × 2 commits/day = 730 commits/year of `data: refresh tier-list.json`. After 2 years, ~1460 commits dominate `git log`, repo clone time slows linearly with history depth.
- **Root cause**: Architectural — committing live data JSON to main branch couples data refresh cadence to git history. Each refresh = 1 commit even if data unchanged within margin.
- **Mitigation options (future)**:
  - Orphan branch (force-push data-only branch, separate from feature commits)
  - Git LFS for `data/tier-list.json` (binary file treatment, history doesn't bloat clone)
  - Separate data repo (`tft-hell-elo-data`) referenced by submodule or HTTPS URL
- **Decision**: defer until 6-month mark or repo size > 500MB threshold. v0.1 ships unaffected. Single-data-file-in-main is KISS for v0.1.
- **Lesson**: Document tradeoff in `data-pipeline-architecture.md` for future re-evaluation when shipping testers.

---

## Phase audit log

- 2026-04-25 — Phases 01–03 (data pipeline) completed: zero new bugs. 80/80 unit tests + 1/1 UI test pass. Build clean.

## Bug #001b — Over-defensive AXIsProcessTrusted gate blocking Carbon hotkey

- **Status**: ✅ Fixed (2026-04-26)
- **Phase**: data-pipeline-real-riot Test 3
- **Symptom**: Cmd+Shift+T silent fail. Diagnostic log shows `register() initial result = failure(.accessibilityDenied)` despite anh granting Accessibility multiple times. Even with valid TCC entry, register would bail on `trustedCheck()` returning false (TCC cdhash drift per rebuild — see Bug #001).
- **Root cause**: `HotkeyRegistrar.register()` had a guard `guard trustedCheck() else { return .failure(.accessibilityDenied) }` based on incorrect assumption that Carbon hotkey needs Accessibility. **Carbon `RegisterEventHotKey` API does NOT require Accessibility permission** — it registers a (key+modifier) tuple with the Window Server at the syscall layer; only `CGEventTap` (HID-level interception) requires AX. Guard was over-defensive copy-paste from CGEventTap pattern.
- **Fix**: Removed guard from `register()`. Carbon registration now proceeds unconditionally. `trustedCheck` parameter retained as dead code for Phase 2 CGEventTap features (e.g., Tab-key comp-suggestion overlay).
- **Lesson**: Verify API requirements against authoritative docs BEFORE adding "defensive" checks. Apple's permission gates are API-specific; defending one with another's gate creates phantom failures invisible from outside. Cost = ~1 hour anh + agent time on TCC permission dance which solved nothing.

---

## Bug #001c — NSLog string interpolations redacted as `<private>` in unified log

- **Status**: ✅ Fixed (2026-04-26)
- **Phase**: data-pipeline-real-riot Test 3 diagnose
- **Symptom**: NSLog calls like `NSLog("TFT Hell Elo: hotkey register result = \(result)")` appear in `log show` as `(Foundation) <private>` — message body fully redacted. No way to read diagnostic state without `sudo log config --mode "private_data:on"` (system-wide reboot-persistent change, not safe).
- **Root cause**: macOS unified logging redacts string interpolations from NSLog (and all `os_log` without explicit privacy markers) by default. This is privacy-by-default — protects against credentials/PII leaking via app logs visible to other users on shared systems. Fine for production but blocks diagnose during dev.
- **Fix**: Created `AppLog.diagnostics` (`os.Logger`) in `SignpostChannels.swift`. All diagnostic call sites use `\(value, privacy: .public)` interpolation, e.g., `AppLog.diagnostics.notice("hotkey register() initial result = \(String(describing: result), privacy: .public)")`.
- **Lesson**: Default to `os.Logger` with explicit `.public` privacy for diagnostic logging in dev contexts. Reserve raw NSLog for messages that must always be private (auth tokens, user-entered data). Document the pattern in code-standards for future contributors.

