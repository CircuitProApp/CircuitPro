//
//  DesignNavigatorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 09.06.25.
//

import SwiftUI

public struct DesignNavigatorView: View {

    @Environment(\.undoManager) private var undoManager
    @Environment(\.projectManager)
    private var projectManager

    @State private var isExpanded: Bool = true

    var document: CircuitProjectFileDocument

    public var body: some View {
        @Bindable var bindableProjectManager = projectManager

        DisclosureGroup(isExpanded: $isExpanded) {
            List(
                $bindableProjectManager.project.designs,
                id: \.self,
                selection: $bindableProjectManager.selectedDesign
            ) { $design in
                HStack {
                    Image(systemName: CircuitProSymbols.Design.design)
                    TextField("Design Name", text: $design.name)
                        .textFieldStyle(.plain)
                        .onSubmit { /*document.renameDesign(design) */}
                }
                .controlSize(.small)
                .frame(height: 14)
                .listRowSeparator(.hidden)
                .contextMenu {
                    Button("Delete") {
                        if projectManager.selectedDesign == design {
                            projectManager.selectedDesign = nil
                        }
                        document.deleteDesign(design, undoManager: undoManager)

                    }
                }
            }
            .frame(height: 180)
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 14)
            .overlay {
                if projectManager.project.designs.isEmpty {
                    Button("Create a Design") {
                        document.addNewDesign(undoManager: undoManager)
                        projectManager.selectedDesign = projectManager.project.designs.first!
                    }
                }
            }
        } label: {
            HStack {
                Group {
                    if projectManager.project.designs.isEmpty || isExpanded {
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
                                Text(projectManager.selectedDesign?.name ?? "Designs")
                                Image(systemName: CircuitProSymbols.Generic.chevronDown)
                                    .imageScale(.small)
                                    .fontWeight(.regular)
                            }
                            .contentShape(Rectangle())
                        }
                    }
                }
                .font(.system(size: 11))
                .fontWeight(.semibold)

                Spacer()
                Button {
//                    document.addNewDesign()
                } label: {
                    Image(systemName: CircuitProSymbols.Generic.plus)
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.secondary)
        }
        .disclosureGroupStyle(NavigatorDisclosureGroupStyle())
    }
}
