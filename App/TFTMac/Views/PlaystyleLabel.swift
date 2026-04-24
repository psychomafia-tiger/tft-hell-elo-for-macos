import SwiftUI

/// Small badge next to the comp name indicating playstyle.
///
/// TFTactics reference examples: "Fast 8", "Slow Roll (5)", "Standard".
/// For v0.1 placeholder we derive from `comp.name` keyword matching —
/// Phase 2 pipeline will emit playstyle as a first-class field on `Comp`.
///
/// Visual: muted background pill, caption font, textMuted color.
struct PlaystyleLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.Fonts.caption)
            .foregroundStyle(Theme.Colors.textMuted)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Theme.Colors.borderDefault)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    /// Wave 5c placeholder: keyword match on comp name.
    /// - "Reroll" → "Slow Roll"
    /// - "Hyper"  → "Fast 8"
    /// - "Frontline" → "Standard"
    /// - default → "Standard"
    static func derivedPlaystyle(for comp: Comp) -> String {
        let lower = comp.name.lowercased()
        if lower.contains("reroll") { return "Slow Roll" }
        if lower.contains("hyper")  { return "Fast 8" }
        return "Standard"
    }
}
