//
//  SidebarListView.swift
//  CircuitPro
//

import SwiftUI

struct SidebarListView<
    Data: RandomAccessCollection,
    ID: Hashable,
    RowContent: View,
    EmptyContent: View
>: View {
    let items: Data
    let id: KeyPath<Data.Element, ID>
    @Binding var selection: Set<ID>
    @ViewBuilder let rowContent: (Data.Element) -> RowContent
    @ViewBuilder let emptyContent: () -> EmptyContent

    var body: some View {
        if items.isEmpty {
            VStack {
                Spacer()
                emptyContent()
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(items, id: id, selection: $selection) { item in
                rowContent(item)
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 14)
        }
    }
}
