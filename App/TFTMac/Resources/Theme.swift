import SwiftUI

/// Design tokens — single source of truth for Views.
///
/// Values locked per `docs/wireframe-v0.1-standard-card.md` (Phase 0 gate 12/12).
/// Phase 1 Views (Tasks 1.4, 1.6, 1.9) must reference these tokens instead of
/// hard-coding colors, fonts, or spacing. Any change here ripples to every
/// screen — intentional, so the wireframe stays authoritative.
///
/// Color is applied at call-site via `.foregroundStyle()`, not baked into Font
/// tokens. For example: `Text(value).font(Theme.Fonts.monoCaption).foregroundStyle(Theme.Colors.accentGold)`.
enum Theme {

    // MARK: - Colors

    /// Hex-to-SwiftUI Color helper. Format: 0xRRGGBB.
    private static func color(_ hex: UInt32) -> Color {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }

    enum Colors {
        /// Popover background — `#1E1E1E` (Raycast/Linear dark base).
        static let bgPopover = Theme.color(0x1E1E1E)
        /// Card background — `#2C2C2E`.
        static let bgCard = Theme.color(0x2C2C2E)
        /// Default border hairline — `#38383A`.
        static let borderDefault = Theme.color(0x38383A)
        /// Primary text — `#FFFFFF`.
        static let textPrimary = Color.white
        /// Muted text (subtitles, metadata) — `#8E8E93`.
        static let textMuted = Theme.color(0x8E8E93)
        /// S-tier accent + percentage emphasis — `#FFD700` (gold).
        static let accentGold = Theme.color(0xFFD700)
        /// A-tier accent — `#C0C0C0` (silver).
        static let accentSilver = Theme.color(0xC0C0C0)
        /// B-tier accent — `#CD7F32` (bronze).
        static let accentBronze = Theme.color(0xCD7F32)
        /// Anomaly chip background — `#3A3A3C` (system gray 5 equivalent in dark mode).
        static let bgChip = Theme.color(0x3A3A3C)
    }

    // MARK: - Fonts

    enum Fonts {
        /// Header title — SF Pro Semibold 15.
        static let titleLarge = Font.system(size: 15, weight: .semibold, design: .default)
        /// Comp name — SF Pro Semibold 14.
        static let title = Font.system(size: 14, weight: .semibold, design: .default)
        /// Metadata row / subtitle — SF Pro Regular 11.
        static let caption = Font.system(size: 11, weight: .regular, design: .default)
        /// Item rows and percentages — SF Mono Regular 10.
        /// Apply emphasis color at call-site: `.foregroundStyle(Theme.Colors.accentGold)`.
        static let monoCaption = Font.system(size: 10, weight: .regular, design: .monospaced)
        /// Tier badge label — SF Pro Bold 14 (black fg on tier bg).
        static let badge = Font.system(size: 14, weight: .bold, design: .default)
    }

    // MARK: - Spacing

    enum Spacing {
        /// Horizontal padding from popover edge to card edge — 20 px.
        static let paddingPopover: CGFloat = 20
        /// Inner padding on card — 12 px all sides.
        static let paddingCard: CGFloat = 12
        /// Vertical gap between tier cards — 8 px.
        static let gapCards: CGFloat = 8
        /// Horizontal gap between champion portrait icons — 6 px.
        static let gapChampionIcons: CGFloat = 6
        /// Tier badge diameter — 28 px (full circle, radius 14).
        static let tierBadge: CGFloat = 28
        /// Standard card height — 120 px.
        static let cardHeight: CGFloat = 120
        /// Champion portrait diameter — 32 px.
        static let championPortrait: CGFloat = 32
    }

    // MARK: - Radii

    enum Radii {
        /// Popover corner radius — 12 px.
        static let popover: CGFloat = 12
        /// Card corner radius — 8 px.
        static let card: CGFloat = 8
        /// Tier badge radius — 14 px (half of 28 px diameter = full circle).
        static let badge: CGFloat = 14
    }
}
