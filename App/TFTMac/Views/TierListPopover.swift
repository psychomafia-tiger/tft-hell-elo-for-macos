import SwiftUI
import os

/// Root popover view — 440×600 card stack rendered inside MenuBarExtra(.window).
///
/// Layout (top → bottom):
/// 1. HeaderBar (56 px) — patch, match count, relative last-updated
/// 2. Divider hairline
/// 3. Banners slot (Phase 2 fills)
/// 4. Comp list (scrollable) — full `CompCard` per wireframe.
///
/// `iconsPreloaded` gate: reserved for when champion/item icon assets are
/// downloaded from Community Data Dragon (Phase 2). For v0.1 the catalogs
/// render placeholder cost-colored circles with initials, so we default
/// `true` to bypass the gate. Keeping the state + conditional here now so
/// Phase 2 is a single-line swap, not a view restructure.
///
/// **os_signpost**: `.end` emitted in `.onAppear` so Task 1.10 Track B can
/// measure hotkey-to-visible latency via Instruments Points of Interest.
/// The matching `.begin` lives in TFTMacApp's hotkey handler.
struct TierListPopover: View {
    let tierList: TierList

    var body: some View {
        CompListView(tierList: tierList, width: 440)
            .frame(height: 600)
            .onAppear {
                os_signpost(.end, log: PopoverSignpost.log, name: PopoverSignpost.name,
                            signpostID: PopoverSignpost.id,
                            "TierListPopover visible, %d comps rendered", tierList.comps.count)
            }
    }
}

