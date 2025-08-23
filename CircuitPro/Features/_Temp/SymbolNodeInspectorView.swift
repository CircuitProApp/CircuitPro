//
//  SymbolNodeInspectorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/23/25.
//

import SwiftUI

struct SymbolNodeInspectorView: View {
    
    /// The comprehensive data model for the component, including its
    /// definition and instance data. Passed as a constant `let`.
    let component: DesignComponent
    
    /// The canvas representation of the symbol. Marked as `@Bindable`
    /// to allow direct UI bindings to its properties (e.g., position).
    @Bindable var symbolNode: SymbolNode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // MARK: Component Identity
            VStack(alignment: .leading) {
                // Displaying the reference designator (e.g., "R1") from the component.
                Text(component.referenceDesignator)
                    .font(.headline)
                
                // Displaying the component's type name (e.g., "Resistor") from its definition.
                Text(component.definition.name)
                    .foregroundColor(.secondary)
            }
            
            // MARK: Transform controls
            // This section remains the same, modifying the SymbolNode directly.
            InspectorSection("Transform") {
                PointControlView(
                    title: "Position",
                    point: $symbolNode.instance.position
                )
              
                RotationControlView(object: $symbolNode.instance)
            }
            
            // MARK: Component Properties
            // Here you can add controls to edit the properties from the DesignComponent.
            InspectorSection("Properties") {
                // The `displayedProperties` array gives you the resolved values to display.
                // To make these editable, you would create controls that, on change,
                // call the `component.save(editedProperty:)` method.
                ForEach(component.displayedProperties, id: \.self) { property in
                    HStack {
                        Text(property.key.label)
                        Spacer()
                        Text(property.value.description)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}
