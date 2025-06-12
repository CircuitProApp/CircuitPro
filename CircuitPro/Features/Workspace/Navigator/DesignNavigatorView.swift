//
//  DesignNavigatorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 09.06.25.
//

import SwiftUI

public struct DesignNavigatorView: View {

    @Environment(\.projectManager)
    private var projectManager

    @State private var isExpanded: Bool = true
    
    var document: CircuitProjectDocument

    public var body: some View {
        @Bindable var bindableProjectManager = projectManager
        
        DisclosureGroup(isExpanded: $isExpanded) {
            List($bindableProjectManager.project.designs, id: \.self, selection: $bindableProjectManager.selectedDesign) { $design in
                HStack {
                    Image(systemName: AppIcons.design)
                    TextField("Design Name", text: $design.name)
                        .textFieldStyle(.plain)
                        .onSubmit { document.renameDesign(design) }
                }
                .controlSize(.small)
                .frame(height: 14)
                .listRowSeparator(.hidden)
                .contextMenu {
                    Button("Delete") { document.deleteDesign(design) }
                }
            }
            .frame(height: 180)
            .listStyle(.sidebar)
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
                            HStack(spacing: 5) {
                                Text(projectManager.selectedDesign?.name ?? "New Design")
                                Image(systemName: AppIcons.chevronDown)
                                    .imageScale(.small)
                           
                                    .fontWeight(.regular)
                             
                              
                            }
                            .contentShape(.rect())
                            
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
        .disclosureGroupStyle(NavigatorDisclosureGroupStyle())
    }
}
