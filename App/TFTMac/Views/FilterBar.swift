import SwiftUI

/// 3-tab segmented control at the top of `CompListView`.
///
/// Wave 5c scope: render the control + emit selection via `@Binding`. Actual
/// filtering logic (restricting comp list by selection) is wired downstream
/// by `CompListView` consumers — tests assert selected state updates on tap.
///
/// Tabs:
/// - `.champions` — filter by champion (placeholder, lists all comps in Wave 5c)
/// - `.traits` — filter by trait (placeholder, lists all comps in Wave 5c)
/// - `.search` — free-text search (placeholder, lists all comps in Wave 5c)
///
/// Phase 2 wires each tab to a real filter; Wave 5c is pure UI scaffold.
enum FilterTab: String, CaseIterable, Identifiable {
    case champions = "Champions"
    case traits    = "Traits"
    case search    = "Search"

    var id: String { rawValue }
}

struct FilterBar: View {
    @Binding var selection: FilterTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(FilterTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, Theme.Spacing.paddingPopover)
        .padding(.vertical, 8)
    }

    private func tabButton(_ tab: FilterTab) -> some View {
        let isSelected = selection == tab
        return Button {
            selection = tab
        } label: {
            Text(tab.rawValue)
                .font(Theme.Fonts.caption)
                .foregroundStyle(isSelected ? Theme.Colors.textPrimary : Theme.Colors.textMuted)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? Theme.Colors.borderDefault : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("filter-tab-\(tab.rawValue.lowercased())")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
