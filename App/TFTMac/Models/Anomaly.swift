import Foundation

/// A single anomaly recommendation attached to a comp.
///
/// Populated by the Phase 01 pipeline (Set 17 Anomaly mechanic —
/// `TFT17_EkkoOffering_*` items). `agreement` is the fraction of
/// sampled matches where this anomaly was taken on the comp.
/// Pipeline filters agreement < 0.40 before publishing; top-3 per comp.
///
/// `id` example: "TFT17_EkkoOffering_AnomalyItem"
/// `agreement` range: 0.40 – 1.0
struct Anomaly: Codable {
    let id: String          // e.g. "TFT17_EkkoOffering_AnomalyItem"
    let agreement: Double   // 0.40 – 1.0
}
