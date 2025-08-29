//
//  CircuitProject+Hydration.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/30/25.
//

import SwiftUI
import SwiftDataPacks

extension CircuitProject {
    /// Populates all `ComponentInstance` objects with a direct reference to their
    /// corresponding `ComponentDefinition` from the SwiftData store.
    func hydrate(using container: ModelContainer) throws {
        let context = ModelContext(container)

        // 1. Collect all unique definition IDs from the project.
        var allDefinitionIDs: Set<UUID> = []
        for design in self.designs {
            for instance in design.componentInstances {
                allDefinitionIDs.insert(instance.componentUUID)
            }
        }
        
        guard !allDefinitionIDs.isEmpty else { return } // Nothing to do.

        // 2. Fetch all required definitions in a single, efficient query.
        let predicate = #Predicate<ComponentDefinition> { allDefinitionIDs.contains($0.uuid) }
        let fetchDescriptor = FetchDescriptor<ComponentDefinition>(predicate: predicate)
        let allDefinitions = try context.fetch(fetchDescriptor)
        
        // 3. Create a fast lookup dictionary.
        let definitionsByID = Dictionary(uniqueKeysWithValues: allDefinitions.map { ($0.uuid, $0) })
        
        // 4. Loop through the project and populate the transient `definition` property.
        for designIndex in self.designs.indices {
            for instanceIndex in self.designs[designIndex].componentInstances.indices {
                let instance = self.designs[designIndex].componentInstances[instanceIndex]
                if let definition = definitionsByID[instance.componentUUID] {
                    self.designs[designIndex].componentInstances[instanceIndex].definition = definition
                } else {
                    // This is an important error case to handle.
                    // It means the document references a component that is not in the user's library.
                    print("Warning: ComponentDefinition with ID \(instance.componentUUID) not found in library for an instance in design '\(self.designs[designIndex].name)'.")
                }
            }
        }
    }
}
