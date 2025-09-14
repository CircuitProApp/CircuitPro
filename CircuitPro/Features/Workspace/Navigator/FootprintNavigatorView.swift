//
//  FootprintNavigatorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/14/25.
//

import SwiftUI

struct FootprintNavigatorView: View {
    @BindableEnvironment(\.projectManager) private var projectManager

    private var unplacedComponents: [ComponentInstance] {
        projectManager.componentInstances.filter {
            $0.footprintInstance?.placement == .unplaced
        }
    }
    
    private func placedComponents(on side: BoardSide) -> [ComponentInstance] {
        projectManager.componentInstances.filter { component in
            guard let footprint = component.footprintInstance else { return false }
            if case .placed(let footprintSide) = footprint.placement {
                return footprintSide == side
            }
            return false
        }
    }

    var body: some View {
        List {
            Section("Unplaced") {
                if unplacedComponents.isEmpty {
                    Text("All components placed.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(unplacedComponents) { component in
                        componentRow(for: component)
                            // --- ADDED: Make this row draggable ---
                            .draggable(TransferablePlacement(componentInstanceID: component.id))
                    }
                }
            }
            
            Section("Placed on Front") {
                // ... (rest of the view is unchanged)
                let frontComponents = placedComponents(on: .front)
                if frontComponents.isEmpty {
                    Text("No components on front.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(frontComponents) { component in
                        componentRow(for: component)
                    }
                }
            }
            
            Section("Placed on Back") {
                let backComponents = placedComponents(on: .back)
                if backComponents.isEmpty {
                    Text("No components on back.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(backComponents) { component in
                        componentRow(for: component)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
    
    @ViewBuilder
    private func componentRow(for component: ComponentInstance) -> some View {
        HStack {
            Text(component.referenceDesignator)
            Spacer()
            Text(component.footprintInstance?.definition?.name ?? "Default")
                .foregroundStyle(.secondary)
        }
    }
}
