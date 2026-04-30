import SwiftUI

/// Horizontal chip row showing the top anomaly recommendations for a comp.
///
/// Rendered between the champion row and the expand divider in `CompCardV2.body`.
/// Only visible when `anomalies` is non-empty — `EmptyView()` otherwise,
/// so card layout is unchanged for comps with no anomaly data (e.g. bundled v1.0.0).
///
/// Pipeline guarantees at most 3 anomalies per comp (top-3 by agreement).
/// Each chip shows: sparkles icon + truncated display name + agreement %.
///
/// DRY note: mirrors horizontal layout pattern used in champion / trait rows.
struct CompCardAnomaliesRow: View {
    let anomalies: [Anomaly]

    var body: some View {
        if anomalies.isEmpty {
            EmptyView()
        } else {
            HStack(spacing: 6) {
                ForEach(anomalies, id: \.id) { anomaly in
                    AnomalyChip(anomaly: anomaly)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - AnomalyChip

/// Single pill chip: sparkles icon + anomaly display name + agreement %.
///
/// Display name derivation example:
///   "TFT17_EkkoOffering_AnomalyItem" → "Anomaly Item"
///   strips "TFT17_EkkoOffering_" prefix, then splits CamelCase → spaced words.
///   Falls back to raw `id` if format is unexpected.
struct AnomalyChip: View {
    let anomaly: Anomaly

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: 10))
                .foregroundStyle(Theme.Colors.accentGold)
            Text(displayName)
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
            Text("\(Int(anomaly.agreement * 100))%")
                .font(Theme.Fonts.caption.weight(.semibold))
                .foregroundStyle(Theme.Colors.textMuted)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.Colors.bgChip)
        .clipShape(Capsule())
    }

    /// Strips the Set-specific prefix and splits CamelCase into spaced words.
    ///
    /// Concrete example:
    ///   Input:  "TFT17_EkkoOffering_AnomalyItem"
    ///   Step 1: drop prefix up to last "_" → "AnomalyItem"
    ///   Step 2: insert space before each uppercase-following-lowercase → "Anomaly Item"
    ///   Output: "Anomaly Item"
    ///
    /// Fallback: if the id has no underscore, returns the raw id as-is.
    private var displayName: String {
        // Take the segment after the last underscore (e.g. "AnomalyItem")
        let suffix = anomaly.id.components(separatedBy: "_").last ?? anomaly.id
        guard !suffix.isEmpty else { return anomaly.id }
        // Split CamelCase: insert space before uppercase letter preceded by lowercase.
        // Example: "AnomalyItem" → "Anomaly Item"
        var result = ""
        var prevChar: Character = suffix.first!
        result.append(prevChar)
        for char in suffix.dropFirst() {
            if char.isUppercase && prevChar.isLowercase {
                result.append(" ")
            }
            result.append(char)
            prevChar = char
        }
        return result
    }
}

// MARK: - Preview

#if DEBUG
struct CompCardAnomaliesRow_Previews: PreviewProvider {
    static var previews: some View {
        // Inline fixture for dev — NOT shipped data; bundled JSON stays at 1.0.0
        let sampleAnomalies = [
            Anomaly(id: "TFT17_EkkoOffering_AnomalyItem", agreement: 0.72),
            Anomaly(id: "TFT17_EkkoOffering_SynergyBoost", agreement: 0.55),
            Anomaly(id: "TFT17_EkkoOffering_DamageAmp", agreement: 0.41)
        ]
        CompCardAnomaliesRow(anomalies: sampleAnomalies)
            .padding()
            .background(Theme.Colors.bgCard)
            .previewLayout(.sizeThatFits)
    }
}
#endif
