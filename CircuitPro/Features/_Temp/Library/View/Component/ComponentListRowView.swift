//
//  ComponentListRowView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/18/25.
//

import SwiftUI

struct ComponentListRowView: View {
    
    var component: Component
    @Binding var selectedComponentID: UUID?
    
    private var isSelected: Bool {
        selectedComponentID == component.uuid
    }
    
    var body: some View {
        HStack {
            Text(component.referenceDesignatorPrefix)
                .frame(width: 32, height: 32)
                .background(component.category.color ?? .accentColor)
                .clipShape(.rect(cornerRadius: 5))
                .font(.subheadline)
                .fontDesign(.rounded)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text(component.name)
                .foregroundStyle(isSelected ? .white : .primary)
        }
        
        .padding(4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .draggable(TransferableComponent(component: component), onDragInitiated: LibraryPanelManager.hide)
        .background(isSelected ? Color.blue : Color.clear)
        .clipShape(.rect(cornerRadius: 8))
        .onTapGesture {
            selectedComponentID = component.uuid
        }
        .preventWindowMove()
    }
}
