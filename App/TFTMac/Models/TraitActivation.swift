import Foundation

/// A single active trait on a comp (from pipeline schema 1.2.0).
///
/// `style` reflects Riot's UX tier (bronze/silver/gold/chromatic) rendered
/// as the trait chip background color.
struct TraitActivation: Codable, Equatable {
    let name: String     // e.g. "TFT17_Psionic"
    let count: Int       // active unit count, e.g. 4
    let style: Style

    enum Style: String, Codable {
        case bronze, silver, gold, chromatic
    }
}
