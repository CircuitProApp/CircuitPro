//
//  ProjectNavigatorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 01.06.25.
//

import SwiftUI

struct ProjectNavigatorView: View {
    
    @State private var selectedDesign: CircuitDesign?
    
    var document: CircuitProjectDocument
    @Bindable var project: CircuitProject
    
    @State private var selectedComponentSymbolInstance: ComponentSymbolInstance?

    struct ComponentSymbolInstance: Identifiable, Hashable {
        var id: UUID = UUID()
        var name: String
        var label: String
        var icon: String

        static func == (lhs: ComponentSymbolInstance, rhs: ComponentSymbolInstance) -> Bool {
            lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    

    @State private var componentSymbolInstances: [ComponentSymbolInstance] = [
        .init(name: "Switch", label: "S1", icon: "cpu"),
        .init(name: "Switch", label: "S2", icon: "cpu"),
        .init(name: "Resistor", label: "R1", icon: "poweroutlet.type.f"),
        .init(name: "Resistor", label: "R2", icon: "poweroutlet.type.f"),
        .init(name: "Resistor", label: "R3", icon: "poweroutlet.type.f"),
        .init(name: "Resistor", label: "R4", icon: "poweroutlet.type.f")
    ]

    
    var body: some View {
        Group {
            List($project.designs, id: \.self, selection: $selectedDesign) { $design in
                HStack {
                    Image(systemName: AppIcons.design)
                    TextField("Design Name", text: $design.name)
                        .textFieldStyle(.plain)
                        .onSubmit {
//                            do {
//                                try document.renameDesign(for: design)
//                            } catch {
//                                print("⚠️ Rename failed: \(error)")
//                            }
                        }
                }
                .frame(height: 14)
                .listRowSeparator(.hidden)
              
            }
            .frame(height: 180)
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
      
            .environment(\.defaultMinListRowHeight, 14)
            .overlay {
                Button {
                    do {
                            try document.addNewDesign()
                        } catch {
                            // You might use an alert/toast here for real apps
                            print("Failed to create new design: \(error)")
                        }
                } label: {
                    Text("Add")
                }

            }
        
            

            Divider().foregroundStyle(.quaternary)

            List($componentSymbolInstances, id: \.self, selection: $selectedComponentSymbolInstance) { $componentSymbolInstance in
                HStack {
                    Image(systemName: componentSymbolInstance.icon)
                    TextField("Symbol Name", text: $componentSymbolInstance.name)
                        .textFieldStyle(.plain)
                        .onSubmit {
                
                                print("Rename")
                           
                        }
                            
                    Spacer()
                    Text(componentSymbolInstance.label)
                        .foregroundStyle(.secondary)
                    
                }
                .frame(height: 14)
                .listRowSeparator(.hidden)
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
      
            .environment(\.defaultMinListRowHeight, 14)
    
        }
    }
}

//#Preview {
//    ProjectNavigatorView()
//}
