import SwiftUI
import AppKit

/// Full-window overlay shown when `bannerState == .updateRequired`.
///
/// Displayed instead of the comp list when the remote/cached data has a
/// schema major version incompatible with this app build. Prevents rendering
/// comps from structurally incompatible JSON (e.g. schema 2.0.0 when app
/// expects 1.x.x).
///
/// User action: download the latest .dmg from GitHub Releases.
/// The overlay replaces the entire CompListView content area — no comps shown.
///
/// Layout: centred VStack with warning icon, title, body text, and link button.
struct UpdateRequiredOverlay: View {

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Theme.Colors.accentGold)

            Text("Update Required")
                .font(Theme.Fonts.titleLarge)
                .foregroundStyle(Theme.Colors.textPrimary)

            Text("TFT Hell Elo data is newer than this app version.\nPlease download the latest release to see current meta.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.paddingPopover)

            Button(action: openReleasesPage) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle")
                    Text("Download Latest Release")
                }
                .font(Theme.Fonts.caption.weight(.semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Theme.Colors.accentGold.opacity(0.15))
                .overlay(
                    Capsule().stroke(Theme.Colors.accentGold.opacity(0.5), lineWidth: 1)
                )
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.bgPopover)
    }

    private func openReleasesPage() {
        let releasesURL = URL(string: "https://github.com/psychomafia-tiger/tft-hell-elo-for-macos/releases")!
        NSWorkspace.shared.open(releasesURL)
    }
}

#if DEBUG
struct UpdateRequiredOverlay_Previews: PreviewProvider {
    static var previews: some View {
        UpdateRequiredOverlay()
            .frame(width: 440, height: 600)
    }
}
#endif
