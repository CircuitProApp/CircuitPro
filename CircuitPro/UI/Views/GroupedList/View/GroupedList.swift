//
//  GroupedList.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/19/25.
//

import SwiftUI

public struct GroupedList<Content: View>: View {

    let content: Content

    // Pinned headers state
    @State private var activeSectionID: SectionConfiguration.ID?
    @State private var firstHeaderFrame: CGRect = .zero

    // Type-erased selection handlers
    private let _isSelected: ((AnyHashable) -> Bool)?
    private let _toggleSelection: ((AnyHashable) -> Void)?

    // Per-instance configuration (scoped only to this GroupedList)
    private var configuration: GroupedListConfiguration = .init()

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading,
                       spacing: 0,
                       pinnedViews: [.sectionHeaders]) {
                ForEach(sections: content) { section in
                    Section {
                        VStack(spacing: configuration.listRowSpacing) {
                            ForEach(subviews: section.content) { subview in
                                // Opaque SwiftUI identity – only used as fallback if no tag is provided
                                let fallbackID: AnyHashable = subview.id

                                GroupedListRowContainer(
                                    row: subview,
                                    fallbackID: fallbackID,
                                    configuration: configuration,
                                    isSelected: _isSelected,
                                    toggleSelection: _toggleSelection
                                )
                            }
                        }
                        .padding(configuration.listPadding)

                    } header: {
                        VStack(alignment: .leading, spacing: 0) {
                            if activeSectionID != section.id {
                                Divider()
                            }
                            section.header
                                .padding(configuration.listHeaderPadding)
                            Divider()
                        }
                        .background(activeSectionID == section.id ? configuration.activeHeaderBackgroundColor : AnyShapeStyle(Color.clear))
                        .background {
                            if configuration.isHudListStyle {
                                HUDWindowBackgroundMaterial()
                            }
                        }
                        .onGeometryChange(for: CGRect.self) { proxy in
                            proxy.frame(in: .scrollView(axis: .vertical))
                        } action: { frame in
                            let isPinned = frame.minY <= 0 && frame.maxY > 0
                            if isPinned {
                                activeSectionID = section.id
                            }
                            if firstHeaderFrame == .zero {
                                firstHeaderFrame = frame
                            }
                        }
                    } footer: {
                        section.footer
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .contentMargins(.top, firstHeaderFrame.height - 1, for: .scrollIndicators)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Configuration API (scoped to GroupedList only)

    public func groupedListConfiguration(_ configure: (inout GroupedListConfiguration) -> Void) -> GroupedList {
        var copy = self
        configure(&copy.configuration)
        return copy
    }

    // MARK: - Selection (type-erased helpers)

    private func isSelected(_ anyID: AnyHashable) -> Bool {
        _isSelected?(anyID) ?? false
    }

    private func toggleSelection(_ anyID: AnyHashable) {
        _toggleSelection?(anyID)
    }
}

// MARK: - Initializers

public extension GroupedList {
    // No-selection init
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
        self._isSelected = nil
        self._toggleSelection = nil
    }

    // Single-selection init (typed)
    init<Selection: Hashable>(
        selection: Binding<Selection?>,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self._isSelected = { any in
            guard let value = any as? Selection else { return false }
            return selection.wrappedValue == value
        }
        self._toggleSelection = { any in
            guard let value = any as? Selection else { return }
            selection.wrappedValue = (selection.wrappedValue == value) ? nil : value
        }
    }

    // Multi-selection init (typed)
    init<Selection: Hashable>(
        selection: Binding<Set<Selection>>,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self._isSelected = { any in
            guard let value = any as? Selection else { return false }
            return selection.wrappedValue.contains(value)
        }
        self._toggleSelection = { any in
            guard let value = any as? Selection else { return }
            if selection.wrappedValue.contains(value) {
                selection.wrappedValue.remove(value)
            } else {
                selection.wrappedValue.insert(value)
            }
        }
    }
}
