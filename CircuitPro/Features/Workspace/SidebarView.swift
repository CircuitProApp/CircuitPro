//
//  SidebarView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 30.05.25.
//

import SwiftUI

struct SidebarView: View {
    @State private var selectedDesign: CircuitDesign?
    
    var document: CircuitProjectDocument
    @Bindable var project: CircuitProject
    
    
    struct ComponentSymbolInstance: Identifiable, Equatable, Hashable {
        var id: UUID = UUID()
        var name: String
        var label: String
        var icon: String
        
    }
    
    @State private var selectedComponentSymbolInstance: ComponentSymbolInstance?
    @State private var componentSymbolInstances: [ComponentSymbolInstance] = [
        .init(name: "Switch", label: "S1", icon: "cpu"),
        .init(name: "Switch", label: "S2", icon: "cpu"),
        .init(name: "Resistor", label: "R1", icon: "poweroutlet.type.f"),
        .init(name: "Resistor", label: "R2", icon: "poweroutlet.type.f"),
        .init(name: "Resistor", label: "R3", icon: "poweroutlet.type.f"),
        .init(name: "Resistor", label: "R4", icon: "poweroutlet.type.f")
    ]

    var body: some View {
        
        VStack(spacing: 0) {
            Divider().foregroundStyle(.quaternary)

            HStack {
                Image(systemName: AppIcons.layoutLayers)
                Image(systemName: AppIcons.board)
                Image(systemName: AppIcons.rectangle)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .foregroundStyle(.secondary)

            Divider().foregroundStyle(.quaternary)

            
            List($project.designs, id: \.self, selection: $selectedDesign) { $design in
                HStack {
                    Image(systemName: AppIcons.design)
                    TextField("Design Name", text: $design.name)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            do {
                                try document.renameDesign(for: design)
                            } catch {
                                print("⚠️ Rename failed: \(error)")
                            }
                        }
                }
         
              
            }
            .frame(height: 180)
        
            

            Divider().foregroundStyle(.quaternary)

            List($componentSymbolInstances, id: \.self, selection: $selectedComponentSymbolInstance) { $componentSymbolInstances in
                HStack {
                    Image(systemName: componentSymbolInstances.icon)
                    Text(componentSymbolInstances.name)
                    Spacer()
                    Text(componentSymbolInstances.label)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
