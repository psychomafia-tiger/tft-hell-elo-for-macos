import SwiftUI
import os

/// Root popover view — 440×600 card stack rendered inside MenuBarExtra(.window).
///
/// Layout (top → bottom):
/// 1. HeaderBar (56 px) — patch, match count, relative last-updated
/// 2. Divider hairline
/// 3. Banners slot — driven by DataManager.bannerState
/// 4. Comp list (scrollable) OR UpdateRequiredOverlay
///
/// Phase 03: `tierList` parameter removed — data flows via `@EnvironmentObject
/// DataManager` injected at TFTMacApp level. CompListView reads from it directly
/// so live @Published updates trigger SwiftUI re-render without view replacement.
///
/// **os_signpost**: `.end` emitted in `.onAppear` so Task 1.10 Track B can
/// measure hotkey-to-visible latency via Instruments Points of Interest.
/// The matching `.begin` lives in TFTMacApp's hotkey handler.
struct TierListPopover: View {
    @EnvironmentObject private var dataManager: DataManager

    var body: some View {
        CompListView(width: 440)
            .frame(height: 600)
            .onAppear {
                os_signpost(.end, log: PopoverSignpost.log, name: PopoverSignpost.name,
                            signpostID: PopoverSignpost.id,
                            "TierListPopover visible, %d comps rendered",
                            dataManager.tierList.comps.count)
            }
    }
}

