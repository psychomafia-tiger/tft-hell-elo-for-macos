import SwiftUI

/// 12×12pt async-loading badge for a single item slot on a carry champion.
///
/// Loading flow:
///   1. On `.task`, look up `iconToken` via `ItemCatalog`.
///   2. If token exists, build URL via `ItemAssetURL` and fetch via `AssetCache`.
///   3. If fetch succeeds → render NSImage clipped to a small rounded square.
///   4. If fetch fails OR token missing → render class-tinted square fallback.
///   5. For unknown itemIds (not in catalog) → fallback always wins, with a
///      "?" glyph 6pt to signal "data missing" rather than "art missing".
///
/// Fallback tint chosen by `ItemCatalog.itemClass(forId:)` so a tank item slot
/// reads "blue square" even before art arrives — preserves visual semantics
/// even on a fresh cache or CDN miss.
struct ItemBadge: View {

    let itemId: String

    /// Loaded NSImage, nil while loading or on miss.
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                fallback
            }
        }
        .frame(width: 12, height: 12)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .task {
            guard image == nil,
                  let token = ItemCatalog.iconToken(forId: itemId),
                  let url = ItemAssetURL.icon(forIconToken: token),
                  let data = try? await AssetCache.shared.data(for: url),
                  let nsImage = NSImage(data: data) else { return }
            self.image = nsImage
        }
    }

    /// Class-tinted square. Renders "?" glyph for items not in the catalog
    /// (signals "we don't know what this is" vs "art is loading / failed").
    private var fallback: some View {
        let cls = ItemCatalog.itemClass(forId: itemId)
        return ZStack {
            Self.tintColor(for: cls).opacity(0.85)
            if cls == .unknown {
                Text("?")
                    .font(.system(size: 6, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    /// Pure function — exposed `static` for tests.
    static func tintColor(for itemClass: ItemCatalog.ItemClass) -> Color {
        switch itemClass {
        case .tank:    return .blue
        case .ad:      return .red
        case .ap:      return .purple
        case .utility: return .green
        case .unknown: return .gray
        }
    }
}
