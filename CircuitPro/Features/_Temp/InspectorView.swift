//
//  InspectorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/13/25.
//

import SwiftUI

struct InspectorView: View {
    
    @Environment(\.projectManager)
    private var projectManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Test Controls").font(.headline)
            
            // This list provides the buttons to trigger the override action.
            ForEach(projectManager.designComponents, id: \.self) { component in
                Button("Override '\(component.definition.name)' Resistance to 100Ω") {
                    // 1. Find the first property that is based on a definition.
                    //    We only want to test overriding definitions, not ad-hoc instance properties.
                    guard var propertyToEdit = component.displayedProperties.first(where: {
                        if case .definition = $0.source { return true }
                        return false
                    }) else {
                        print("No definition-based property found to override.")
                        return
                    }
                    
                    // 2. Modify the value on our local copy.
                    //    `propertyToEdit` is a struct, so it's a mutable copy.
                    propertyToEdit.value = .single(100.0)
                    
                    // 3. Call the save method on the DesignComponent.
                    //    This is the core of the test. This method will find or create
                    //    the Property.Override on the ComponentInstance.
                    component.save(editedProperty: propertyToEdit)
                    
                    // Since ComponentInstance is @Observable, this change will
                    // automatically trigger an update in the view below.
                }
            }
            
            Divider().padding(.vertical)
            
            Text("Live Property Values").font(.headline)

            // This list displays the live, resolved values so we can see the result.
            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(projectManager.designComponents, id: \.self) { component in
                        Text(component.definition.name)
                            .font(.subheadline.bold())
                            .padding(.top)
                        
                        // We iterate through the *same* `displayedProperties` computed property.
                        // When the button is pressed, this list will automatically update.
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
