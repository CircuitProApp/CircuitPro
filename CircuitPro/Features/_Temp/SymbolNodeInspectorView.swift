// In SymbolNodeInspectorView.swift

import SwiftUI
import SwiftDataPacks

struct SymbolNodeInspectorView: View {
    
    @Environment(\.projectManager)
    private var projectManager
    
    @PackManager private var packManager
    
    let component: DesignComponent
    @Bindable var symbolNode: SymbolNode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading) {
                Text(component.referenceDesignator)
                    .font(.headline)
                Text(component.definition.name)
                    .foregroundColor(.secondary)
            }

            InspectorSection("Transform") {
                PointControlView(
                    title: "Position",
                    point: $symbolNode.instance.position
                )
              
                RotationControlView(object: $symbolNode.instance)
            }

            InspectorSection("Properties") {
                ForEach(component.displayedProperties, id: \.self) { property in
                    EditablePropertyView(property: property) { updatedProperty in
                        // This single call handles all updates.
                        projectManager.updateProperty(
                            for: component,
                            with: updatedProperty,
                            using: packManager
                        )
                    }
                }
            }
        }
    }
}
