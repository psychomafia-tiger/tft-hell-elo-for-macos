import SwiftUI

/// Top bar of the popover — 56 px tall per wireframe-v0.1-standard-card.md.
///
/// Surfaces the two pieces of metadata users actually check: which patch is
/// the data from, and how fresh it is. Gear icon is a visual placeholder;
/// Task 1.11+ wires it to a Settings sheet.
///
/// Tokens: all colors/fonts/spacing from `Theme` (no hard-coded literals).
struct HeaderBar: View {
    let patch: String
    let lastUpdated: Date
    let totalMatches: Int

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("TFT Mac")
                    .font(Theme.Fonts.titleLarge)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("Patch \(patch) · \(totalMatches) Challenger matches · \(agoString)")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textMuted)
            }
            Spacer()
            Image(systemName: "gearshape")
                .font(.system(size: 16))
                .foregroundStyle(Theme.Colors.textMuted)
                .frame(width: 28, height: 28)
        }
        .padding(.horizontal, Theme.Spacing.paddingPopover)
        .frame(height: 56)
    }

    /// Returns e.g. "2h ago" — human-readable relative time.
    ///
    /// Why abbreviated: header is tight horizontally (cohabits with patch +
    /// match count), so "2h ago" beats "2 hours ago" for information density.
    /// Example: lastUpdated = 7200s ago → "2h ago". Fresh (<1 min) → "now".
    private var agoString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastUpdated, relativeTo: Date())
    }
}
