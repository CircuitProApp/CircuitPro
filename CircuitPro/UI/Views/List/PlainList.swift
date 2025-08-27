//
//  PlainList.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/20/25.
//

import SwiftUI

public struct PlainList<Content: View, ID: Hashable>: View {
    public let content: Content

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
            LazyVStack(spacing: configuration.listRowSpacing) {
                ForEach(subviews: content) { subview in
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
            .modifier(OrderedIDsCollector(isEnabled: selectionEnabled, orderedIDs: $orderedIDs))
            .padding(configuration.listPadding)
        }
    }

    private var selectionEnabled: Bool {
        switch mode {
        case .none: false
        case .single, .multi: true
        }
    }
}
