//
//  CanvasManager 2.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/5/25.
//
import SwiftUI
import Observation
import SwiftData

@Observable
final class ProjectManager {

    private let modelContext: ModelContext
    var project: CircuitProject
    var selectedDesign: CircuitDesign?

    init(project: CircuitProject,
         selectedDesign: CircuitDesign? = nil,
         modelContext: ModelContext) {
        self.project        = project
        self.selectedDesign = selectedDesign
        self.modelContext   = modelContext
    }

    // 1. Convenience
    var componentInstances: [ComponentInstance] {
        selectedDesign?.componentInstances ?? []
    }

    // 2. Centralised lookup
    var designComponents: [DesignComponent] {
        // 2.1 gather the UUIDs the design references
        let uuids = Set(componentInstances.map(\.componentUUID))
        guard !uuids.isEmpty else { return [] }

        // 2.2 fetch all definitions in ONE round-trip
        let request = FetchDescriptor<Component>(predicate: #Predicate { uuids.contains($0.uuid) })
        let defs = (try? modelContext.fetch(request)) ?? []

        // 2.3 build a dictionary for fast lookup
        let dict = Dictionary(uniqueKeysWithValues: defs.map { ($0.uuid, $0) })

        // 2.4 zip every instance with its definition (skip dangling refs gracefully)
        return componentInstances.compactMap { inst in
            guard let def = dict[inst.componentUUID] else { return nil }
            return DesignComponent(definition: def, instance: inst)
        }

    }
}
