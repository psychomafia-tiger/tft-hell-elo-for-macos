import Foundation
import os.signpost

/// Shared OSLog + OSSignpostID for cross-file signpost correlation.
///
/// Why this file exists: `OSSignpostID(log:)` generates a unique ID per call.
/// If `TFTMacApp` and `TierListPopover` each declare their own `static let id`,
/// Instruments sees two unrelated IDs and cannot match BEGIN from one file
/// with END from another — the whole Track B latency measurement silently fails.
///
/// Solution: both files reference the SAME static members here. `PopoverSignpost`
/// is a namespace enum (no cases = uninstantiable) holding the shared log handle
/// and ID. BEGIN in TFTMacApp.register(onFire:) and END in TierListPopover.onAppear
/// now form a matched pair in Instruments.
///
/// **Phase 1 semantic**: single shared ID for the whole app session = measures
/// "one logical popover-open op" per launch. Repeated opens emit nested
/// BEGIN/END pairs with the same ID (Instruments renders overlapping
/// intervals). Acceptable for Phase 1 single-shot latency measurement.
/// Phase 2+ "median of N opens" analysis will require per-event `OSSignpostID`
/// generation — upgrade at that point, not now (YAGNI).
///
/// Task 1.10 Track B measurement flow:
/// 1. `log collect --start "5 min ago" --output popover.logarchive` captures
///    signposts emitted during dogfood session
/// 2. Xcode Instruments → Points of Interest track plots `popover.open`
///    intervals using subsystem+category as the filter
/// 3. Duration between BEGIN (hotkey fire) and END (popover.onAppear) is the
///    measured latency target ≤300ms
enum PopoverSignpost {
    static let log = OSLog(subsystem: "asia.lab3.tftmac", category: "popover")
    static let id = OSSignpostID(log: log)
    static let name: StaticString = "popover.open"
}
