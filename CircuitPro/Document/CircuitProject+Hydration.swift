//
//  CircuitProject+Hydration.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/30/25.
//

import SwiftUI
import SwiftDataPacks

extension CircuitProject {
    /// Populates all data model instances (Component, Symbol, Footprint) with direct references to their
    /// corresponding definitions from the SwiftData store. This process is "hydrating" the project.
    func hydrate(using container: ModelContainer) throws {
        let context = ModelContext(container)
        
        // Collect all unique component definition IDs.
        var allComponentIDs: Set<UUID> = []
        for design in self.designs {
            for instance in design.componentInstances {
                allComponentIDs.insert(instance.definitionUUID)
            }
        }
        
        if !allComponentIDs.isEmpty {
            // Fetch all required component definitions in a single query.
            let componentPredicate = #Predicate<ComponentDefinition> { allComponentIDs.contains($0.uuid) }
            let componentFetchDescriptor = FetchDescriptor<ComponentDefinition>(predicate: componentPredicate)
            let allComponentDefinitions = try context.fetch(componentFetchDescriptor)
            
            // Create a fast lookup dictionary.
            let componentsByID = Dictionary(uniqueKeysWithValues: allComponentDefinitions.map { ($0.uuid, $0) })
            
            // Loop through the project and populate the transient `definition` properties.
            for design in self.designs {
                for instance in design.componentInstances {
                    if let definition = componentsByID[instance.definitionUUID] {
                        // Link the ComponentDefinition to the ComponentInstance
                        instance.definition = definition
                        // Also link the SymbolDefinition to the SymbolInstance
                        instance.symbolInstance.definition = definition.symbol
                    } else {
                        print("Warning: ComponentDefinition with ID \(instance.definitionUUID) not found in library for an instance in design '\(design.name)'.")
                    }
                }
            }
        }
        
        // Collect all unique footprint definition IDs from all component instances.
        var allFootprintIDs: Set<UUID> = []
        for design in self.designs {
            for instance in design.componentInstances {
                if let footprintInstance = instance.footprintInstance {
                    allFootprintIDs.insert(footprintInstance.definitionUUID)
                }
            }
        }
        
        if !allFootprintIDs.isEmpty {
            // Fetch all required footprint definitions in a single query.
            let footprintPredicate = #Predicate<FootprintDefinition> { allFootprintIDs.contains($0.uuid) }
            let footprintFetchDescriptor = FetchDescriptor<FootprintDefinition>(predicate: footprintPredicate)
            let allFootprintDefinitions = try context.fetch(footprintFetchDescriptor)

            // Create a fast lookup dictionary for footprints.
            let footprintsByID = Dictionary(uniqueKeysWithValues: allFootprintDefinitions.map { ($0.uuid, $0) })

            // Loop through the project again and populate the transient `footprintInstance.definition` property.
            for design in self.designs {
                for instance in design.componentInstances {
                    if let footprintInstance = instance.footprintInstance {
                        if let definition = footprintsByID[footprintInstance.definitionUUID] {
                            // Link the FootprintDefinition to the FootprintInstance
                            instance.footprintInstance?.definition = definition
                        } else {
                            print("Warning: FootprintDefinition with ID \(footprintInstance.definitionUUID) not found in library.")
                        }
                    }
                }
            }
        }
    }
}
