//
//  InspectorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/13/25.
//

import SwiftUI
import SwiftDataPacks // Import this to use @PackManager

struct InspectorView: View {
    
    @Environment(\.projectManager)
    private var projectManager
    
    // 1. Get the PackManager from the environment.
    @PackManager private var packManager
    
    var body: some View {
        // 2. Fetch the design components here, inside the body.
        let designComponents = projectManager.designComponents(using: packManager)

        VStack(alignment: .leading, spacing: 10) {
            Text("Test Controls").font(.headline)
            
            // 3. Use the locally fetched `designComponents`.
            ForEach(designComponents, id: \.self) { component in
                Button("Override '\(component.definition.name)' Resistance to 100Ω") {
                    // 1. Find the first property that is based on a definition.
                    guard var propertyToEdit = component.displayedProperties.first(where: {
                        if case .definition = $0.source { return true }
                        return false
                    }) else {
                        print("No definition-based property found to override.")
                        return
                    }
                    
                    // 2. Modify the value on our local copy.
                    propertyToEdit.value = .single(100.0)
                    
                    // 3. Call the save method on the DesignComponent.
                    component.save(editedProperty: propertyToEdit)
                }
            }
            
            Divider().padding(.vertical)
            
            Text("Live Property Values").font(.headline)

            ScrollView {
                VStack(alignment: .leading) {
                    // 4. Use the locally fetched `designComponents` here as well.
                    ForEach(designComponents, id: \.self) { component in
                        Text(component.definition.name)
                            .font(.subheadline.bold())
                            .padding(.top)
                        
                        ForEach(component.displayedProperties, id: \.self) { property in
                            HStack {
                                Text(property.key.label)
                                Spacer()
                                Text(property.value.description)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading)
                        }
                    }
                }
            }
        }
        .padding()
    }
}
