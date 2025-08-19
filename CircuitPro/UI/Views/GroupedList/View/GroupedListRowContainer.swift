//
//  GroupedListRowContainer.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/19/25.
//

import SwiftUI

struct GroupedListRowContainer<Row: View>: View {
    let row: Row
    let fallbackID: AnyHashable       // internal SwiftUI id, used only if no tag provided
    let configuration: GroupedListConfiguration
    let isSelected: ((AnyHashable) -> Bool)?
    let toggleSelection: ((AnyHashable) -> Void)?

    @State private var tagValue: AnyHashable?

    private var effectiveID: AnyHashable { tagValue ?? fallbackID }
    private var selected: Bool { isSelected?(effectiveID) ?? false }

    var body: some View {
        row
            .onPreferenceChange(GroupedListTagPreferenceKey.self) { tagValue = $0 }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(configuration.listRowPadding)
            .background(selected ? Color.blue : Color.clear)
            .foregroundStyle(selected ? Color.white : Color.primary)
            .contentShape(Rectangle())
            .clipShape(.rect(cornerRadius: configuration.listSelectionCornerRadius))
            .onTapGesture { toggleSelection?(effectiveID) }
    }
}
