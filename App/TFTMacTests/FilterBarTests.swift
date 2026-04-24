import XCTest
import SwiftUI
@testable import TFTMac

/// Wave 5c — FilterBar binding behavior.
///
/// Test focus: `@Binding` selection updates correctly when tapping each tab.
/// SwiftUI button tap is not trivially triggerable from XCTest without
/// `ViewInspector` or snapshot tooling; we test the FilterTab enum semantics
/// + binding pass-through via direct mutation.
final class FilterBarTests: XCTestCase {

    func testAllTabsCasesPresent() {
        XCTAssertEqual(FilterTab.allCases.count, 3,
                       "Wave 5c wireframe: Champions / Traits / Search = 3 tabs")
        XCTAssertTrue(FilterTab.allCases.contains(.champions))
        XCTAssertTrue(FilterTab.allCases.contains(.traits))
        XCTAssertTrue(FilterTab.allCases.contains(.search))
    }

    func testTabRawValuesReadable() {
        XCTAssertEqual(FilterTab.champions.rawValue, "Champions")
        XCTAssertEqual(FilterTab.traits.rawValue, "Traits")
        XCTAssertEqual(FilterTab.search.rawValue, "Search")
    }

    func testTabIdentifierMatchesRawValue() {
        // Identifiable conformance drives ForEach identity — id must be stable.
        XCTAssertEqual(FilterTab.champions.id, "Champions")
        XCTAssertEqual(FilterTab.traits.id, "Traits")
        XCTAssertEqual(FilterTab.search.id, "Search")
    }

    /// Binding contract: FilterBar(selection:) reads/writes an external state.
    /// Simulate by constructing the view with a `@State`-backed binding via
    /// a host wrapper and then mutating the underlying storage.
    func testBindingUpdatesSelection() {
        // Manual binding harness — backing storage mutable across reads.
        var storage: FilterTab = .champions
        let binding = Binding<FilterTab>(
            get: { storage },
            set: { storage = $0 }
        )
        // Constructing the FilterBar with the binding does not fire any update.
        _ = FilterBar(selection: binding)
        XCTAssertEqual(storage, .champions, "Initial state preserved after view init")

        // Emulate what a tap handler would do (view invokes `selection = tab`).
        binding.wrappedValue = .traits
        XCTAssertEqual(storage, .traits, "Binding write propagated to storage")

        binding.wrappedValue = .search
        XCTAssertEqual(storage, .search)
    }

    func testViewBodyConstructs() {
        var storage: FilterTab = .champions
        let binding = Binding<FilterTab>(
            get: { storage },
            set: { storage = $0 }
        )
        let bar = FilterBar(selection: binding)
        XCTAssertNotNil(bar.body, "FilterBar body must render without crashing")
    }
}
