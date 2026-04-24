import SwiftUI

/// Shared container rendered inside BOTH popover (width=440) AND overlay (width=520).
///
/// Per D4 decision: a single `CompListView(width:)` keeps layout drift impossible —
/// if popover gets a new header row, overlay gets it for free (and vice versa).
/// The `width` parameter propagates down to `CompCardV2(width: cardWidth)` so card
/// size scales with container.
///
/// Layout (top → bottom):
/// 1. HeaderBar (56px) — patch, last updated, match count
/// 2. Divider hairline
/// 3. Banners slot (Phase 2)
/// 4. FilterBar (3 tabs — Champions / Traits / Search)
/// 5. Comp list (scrollable) — full `CompCardV2` per comp
struct CompListView: View {
    let tierList: TierList
    let width: CGFloat

    /// Inner card width = container width minus popover/overlay horizontal padding
    /// (20px each side per `Theme.Spacing.paddingPopover`).
    private var cardWidth: CGFloat {
        width - (Theme.Spacing.paddingPopover * 2)
    }

    @State private var filterSelection: FilterTab = .champions

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar(
                patch: tierList.patchVersion,
                lastUpdated: tierList.lastUpdated,
                totalMatches: tierList.totalMatchesSampled
            )
            Divider().background(Theme.Colors.borderDefault)
            Banners(tierList: tierList)
            FilterBar(selection: $filterSelection)
            compList
        }
        .frame(width: width)
        .background(Theme.Colors.bgPopover)
    }

    private var compList: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.gapCards) {
                ForEach(tierList.comps, id: \.compId) { comp in
                    CompCardV2(comp: comp, width: cardWidth)
                }
            }
            .padding(.horizontal, Theme.Spacing.paddingPopover)
            .padding(.vertical, Theme.Spacing.gapCards)
        }
    }
}
