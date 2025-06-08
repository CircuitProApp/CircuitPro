//
//  ProjectNavigatorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 01.06.25.
//

import SwiftUI

struct RightArrowDisclosureGroupStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation {
                    configuration.isExpanded.toggle()
                }
            } label: {
                HStack {
                    configuration.label
                    Spacer()
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(configuration.isExpanded ? 90 : 0))
                        .imageScale(.small)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding([.top, .leading, .trailing], 10)
            .padding(.bottom, configuration.isExpanded ? 0 : 10)
  
            if configuration.isExpanded {
                configuration.content
            }
        }
    }
}

struct ProjectNavigatorView: View {
    
    @Environment(\.projectManager)
    private var projectManager
    
    var document: CircuitProjectDocument
    
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
    @State private var isExpanded: Bool = false
    
    
    var body: some View {
        @Bindable var bindableProjectManager = projectManager
        
        Group {
            DisclosureGroup(isExpanded: $isExpanded) {
                List($bindableProjectManager.project.designs, id: \.self, selection: $bindableProjectManager.selectedDesign) { $design in
                    HStack {
                        Image(systemName: AppIcons.design)
                        TextField("Design Name", text: $design.name)
                            .textFieldStyle(.plain)
                            .onSubmit { document.renameDesign(design) }
                    }
                    .frame(height: 14)
                    .listRowSeparator(.hidden)
                   
                    .contextMenu {
                        Button("Delete") { document.deleteDesign(design) }
                    }
                }
                .frame(height: 180)
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                .environment(\.defaultMinListRowHeight, 14)
            
            } label: {
                HStack {
                    Group {
                        if isExpanded {
                            Text("Designs")
                            
                        } else {
                            Menu {
                                ForEach(projectManager.project.designs) { design in
                                    Button(design.name) {
                                        projectManager.selectedDesign = design
                                    }
                                }
                            } label: {
                                Text(projectManager.selectedDesign?.name ?? "New Design")
                            }

                           
                            
                            
                        }
                    }
                    .font(.system(size: 11))
                    .fontWeight(.semibold)
                    
                   
                    Spacer()
                    Button {
                        document.addNewDesign()
                    } label: {
                        Image(systemName: AppIcons.plus)
                    }
                    .buttonStyle(.plain)
                }
            }
            .disclosureGroupStyle(RightArrowDisclosureGroupStyle())
         

            
            
            
            
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
