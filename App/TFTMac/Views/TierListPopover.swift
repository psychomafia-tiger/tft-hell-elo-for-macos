import SwiftUI
import os

/// Root popover view — 440×600 card stack rendered inside MenuBarExtra(.window).
///
/// Layout (top → bottom):
/// 1. HeaderBar (56 px) — patch, match count, relative last-updated
/// 2. Divider hairline
/// 3. Banners slot (Phase 2 fills)
/// 4. Comp list (scrollable) — placeholder cards for now; Task 1.9 replaces
///    `CompCardPlaceholder` with the full 120px wireframe-match card.
///
/// `iconsPreloaded` gate: Task 1.9 flips default to `false` and flips true
/// when champion/item icon assets finish warming. For Task 1.8 the assets
/// don't exist yet, so we default `true` to bypass the gate. Keeping the
/// state + conditional here now so Task 1.9 is a single-line swap, not a
/// view restructure.
///
/// **os_signpost**: `.end` emitted in `.onAppear` so Task 1.10 Track B can
/// measure hotkey-to-visible latency via Instruments Points of Interest.
/// The matching `.begin` lives in TFTMacApp's hotkey handler.
struct TierListPopover: View {
    let tierList: TierList
    @State private var iconsPreloaded: Bool = true  // Task 1.9 will default false until assets warm

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar(
                patch: tierList.patchVersion,
                lastUpdated: tierList.lastUpdated,
                totalMatches: tierList.totalMatchesSampled
            )
            Divider().background(Theme.Colors.borderDefault)
            Banners(tierList: tierList)  // Phase 2 fills; empty in Phase 1
            if iconsPreloaded {
                compList
            } else {
                ProgressView().frame(maxHeight: .infinity)
            }
        }
        .frame(width: 440, height: 600)
        .background(Theme.Colors.bgPopover)
        .onAppear {
            os_signpost(.end, log: PopoverSignpost.log, name: PopoverSignpost.name,
                        signpostID: PopoverSignpost.id,
                        "TierListPopover visible, %d comps rendered", tierList.comps.count)
        }
    }

    private var compList: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.gapCards) {
                ForEach(tierList.comps, id: \.compId) { comp in
                    // Task 1.9 replaces with full CompCard view per wireframe.
                    CompCardPlaceholder(comp: comp)
                }
            }
            .padding(Theme.Spacing.paddingPopover)
        }
    }
}

/// Minimal card used only for Task 1.8 integration wiring.
///
/// Task 1.9 replaces this entire struct with the full wireframe match:
/// 4-champion portraits row, 3-item BIS build row, trait chips, etc.
/// We ship this placeholder now so the end-to-end pipeline
/// (bundle → decode → SwiftUI render) is testable before the visual work.
///
/// Low-sample comps (<100 matches) render at 50% opacity per spec — the
/// signal is "data exists but treat with low confidence."
private struct CompCardPlaceholder: View {
    let comp: Comp

    var body: some View {
        HStack {
            Text(comp.tier.rawValue)
                .font(Theme.Fonts.badge)
                .foregroundStyle(tierBadgeColor)
                .frame(width: 28, height: 28)
                .background(tierBadgeBg)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(comp.name)
                    .font(Theme.Fonts.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("Play \(Int(comp.playRate * 100))% · Avg \(String(format: "%.1f", comp.avgPlacement)) · \(comp.sampleSize) matches")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textMuted)
            }
            Spacer()
        }
        .padding(Theme.Spacing.paddingCard)
        .frame(height: 120)
        .background(Theme.Colors.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radii.card))
        .opacity(comp.sampleSize < 100 ? 0.5 : 1.0)
    }

    private var tierBadgeBg: Color {
        switch comp.tier {
        case .S: return Theme.Colors.accentGold
        case .A: return Theme.Colors.accentSilver
        case .B: return Theme.Colors.accentBronze
        case .C: return Color.gray
        }
    }

    private var tierBadgeColor: Color { .black }
}
