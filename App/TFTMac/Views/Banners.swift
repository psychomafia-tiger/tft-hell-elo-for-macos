import SwiftUI

/// Banner slot rendered between the HeaderBar divider and FilterBar.
///
/// Driven by `BannerState` from `DataManager`. Each case maps to a distinct
/// visual treatment:
///   .fresh           → EmptyView (no banner, zero height)
///   .lastUpdated(h)  → subtle grey bar: "Last updated Xh ago"
///   .staleData(d)    → amber bar: "Stale data — last updated Xd ago"
///   .offlineBundled  → orange bar: "Offline mode — using bundled data"
///   .updateRequired  → handled by UpdateRequiredOverlay at CompListView level;
///                      this view shows nothing (overlay takes the full window)
struct Banners: View {
    let state: BannerState

    var body: some View {
        switch state {
        case .fresh, .updateRequired:
            EmptyView()
        case .lastUpdated(let hoursAgo):
            BannerBar(
                icon: "clock",
                message: "Last updated \(hoursAgo)h ago",
                color: Theme.Colors.textMuted
            )
        case .staleData(let daysAgo):
            BannerBar(
                icon: "exclamationmark.circle",
                message: "Stale data — last updated \(daysAgo)d ago",
                color: .orange
            )
        case .offlineBundled:
            BannerBar(
                icon: "wifi.slash",
                message: "Offline mode — using bundled data",
                color: .orange
            )
        }
    }
}

// MARK: - BannerBar

/// Single-line coloured banner bar with icon and message text.
private struct BannerBar: View {
    let icon: String
    let message: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
            Text(message)
                .font(Theme.Fonts.caption)
                .foregroundStyle(color)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.paddingPopover)
        .padding(.vertical, 6)
        .background(color.opacity(0.08))
    }
}
