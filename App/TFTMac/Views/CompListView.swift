import SwiftUI

/// Shared container rendered inside BOTH popover (width=440) AND overlay (width=520).
///
/// Per D4 decision: a single `CompListView(width:)` keeps layout drift impossible —
/// if popover gets a new header row, overlay gets it for free (and vice versa).
/// The `width` parameter propagates down to `CompCardV2(width: cardWidth)` so card
/// size scales with container.
///
/// Phase 03: receives `DataManager` via `@EnvironmentObject` for live `@Published`
/// updates. When `bannerState == .updateRequired`, renders `UpdateRequiredOverlay`
/// instead of comp list (guards against rendering incompatible schema data).
///
/// Layout (top → bottom):
/// 1. HeaderBar (56px) — patch, last updated, match count
/// 2. Divider hairline
/// 3. Banners slot — driven by DataManager.bannerState
/// 4. FilterBar (3 tabs — Champions / Traits / Search)  [hidden when updateRequired]
/// 5. Comp list (scrollable) OR UpdateRequiredOverlay
struct CompListView: View {
    @EnvironmentObject private var dataManager: DataManager
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
                patch: dataManager.tierList.patchVersion,
                lastUpdated: dataManager.tierList.lastUpdated,
                totalMatches: dataManager.tierList.totalMatchesSampled
            )
            Divider().background(Theme.Colors.borderDefault)
            Banners(state: dataManager.bannerState)
            if dataManager.bannerState == .updateRequired {
                UpdateRequiredOverlay()
            } else {
                FilterBar(selection: $filterSelection)
                compList
            }
        }
        .frame(width: width)
        .background(Theme.Colors.bgPopover)
    }

    private var compList: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.gapCards) {
                ForEach(dataManager.tierList.comps, id: \.compId) { comp in
                    CompCardV2(comp: comp, width: cardWidth)
                }
            }
            .padding(.horizontal, Theme.Spacing.paddingPopover)
            .padding(.vertical, Theme.Spacing.gapCards)
        }
    }
}
