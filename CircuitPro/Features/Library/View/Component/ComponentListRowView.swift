//
//  ComponentListRowView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/18/25.
//

import SwiftUI

struct ComponentListRowView: View {
    
    var component: ComponentDefinition
    var isSelected: Bool
    
    var body: some View {
        HStack {
            Text(component.referenceDesignatorPrefix)
                .frame(width: 32, height: 32)
                .background(component.category.color)
                .clipShape(.rect(cornerRadius: 4))
                .font(.subheadline)
                .fontDesign(.rounded)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text(component.name)
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .draggable(TransferableComponent(component: component), onDragInitiated: LibraryPanelManager.hide)
    }
}
