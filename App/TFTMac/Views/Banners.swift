import SwiftUI

/// Phase 1 Task 1.8 stub: no banners active yet.
///
/// Phase 2 Task 2.13 populates when DataManager fallback chain lands:
/// - `.stale` banner when cache >24h old
/// - `.offline` banner when fetch fails AND cache fallback kicks in
/// - `.error` banner when schema version mismatch blocks data display
///
/// Keeping the component slot reserved now so Phase 2 work is a single
/// view swap, not a layout restructure of TierListPopover.
struct Banners: View {
    let tierList: TierList

    var body: some View {
        EmptyView()  // Phase 2 swaps to conditional banner stack
    }
}
