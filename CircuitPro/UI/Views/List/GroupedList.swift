//
//  GroupedList.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/20/25.
//

import SwiftUI

public struct GroupedList<Content: View, ID: Hashable>: View {

    public let content: Content

    @State private var activeSectionID: SectionConfiguration.ID?
    @State private var firstHeaderFrame: CGRect = .zero

    private let mode: SelectionMode<ID>
    @State private var orderedIDs: [ID] = []
    @State private var anchor: ID?

    @Environment(\.listConfiguration) private var configuration

    public init(@ViewBuilder content: () -> Content) where ID == Never {
        self.content = content()
        self.mode = .none
    }
    public init(selection: Binding<ID?>, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.mode = .single(selection)
    }
    public init(selection: Binding<Set<ID>>, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.mode = .multi(selection)
    }

    public var body: some View {
        ScrollView {
            LazyVStack(
                spacing: 0,
                pinnedViews: [.sectionHeaders]
            ) {
                ForEach(sections: content) { section in
                    Section {
                        VStack(spacing: configuration.listRowSpacing) {
                            ForEach(subviews: section.content) { subview in
                                // Only wrap rows that explicitly opted into selection AND provided an ID.
                                if subview.containerValues[keyPath: \.listRowSelectable],
                                   let erased = subview.containerValues[keyPath: \.listIDErased],
                                   let id = erased as? ID {
                                    SelectableRow(
                                        row: subview,
                                        id: id,
                                        mode: mode,
                                        orderedIDs: $orderedIDs,
                                        anchor: $anchor
                                    )
                                } else {
                                    subview
                                        .padding(configuration.listRowPadding)
                                }
                            }
                        }
                        .padding(configuration.listPadding)

                    } header: {
                        VStack(alignment: .leading, spacing: 0) {
                            if activeSectionID != section.id {
                                Divider()
                            }
                            section.header
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(configuration.headerPadding)
                            Divider()
                        }
                        .background {
                            if activeSectionID == section.id && configuration.headerStyle != .hud {
                                Rectangle().fill(configuration.activeHeaderBackgroundStyle)
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
            .modifier(OrderedIDsCollector(isEnabled: selectionEnabled, orderedIDs: $orderedIDs))
            .frame(maxWidth: .infinity)
        }
        .contentMargins(.top, max(0, firstHeaderFrame.height - 1), for: .scrollIndicators)
    }

    private var selectionEnabled: Bool {
        switch mode {
        case .none: false
        case .single, .multi: true
        }
    }
}
