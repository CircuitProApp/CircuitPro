//
//  ProjectView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/1/25.
//

import SwiftUI
import SwiftData

public struct ProjectView: View {

    @Environment(\.projectManager)
    private var projectManager

    @Environment(\.openWindow)
    private var openWindow

    @Environment(\.modelContext)
    private var modelContext

    let project: Project

    @State private var selectedEditor: EditorType = .schematic
    @State private var isShowingInspector: Bool = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            if project.designs.isNotEmpty {
                List {
                    Section {
                        ForEach(project.designs) { design in
                                Text(design.name)
                                .directionalPadding(vertical: 5, horizontal: 7.5)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(projectManager.selectedDesign == design ? .blue : .clear)
                                .foregroundStyle(projectManager.selectedDesign == design ? .white : .primary)
                                .clipShape(.rect(cornerRadius: 5))
                                    .onTapGesture {
                                        projectManager.selectedDesign = design
                                    }
                        }
                    } header: {
                        HStack {
                            Text("Designs")
                            Spacer()
//                            Button {
//                                
//                            } label: {
//                                Image(systemName: "plus")
//                            }
                        }
                    }
                }
            } else {
                Button("Add a new Design") {
                    // Your action for adding a design
                }
            }
        } detail: {
            projectDetail
        }
    }
    var projectDetail: some View {
        VStack {
            if projectManager.selectedDesign != nil {
                switch selectedEditor {
                case .schematic:
                    SchematicView()
                case .layout:
                    LayoutView()
                }
            } else {
                if project.designs.isNotEmpty {
                    ForEach(project.designs) { design in
                        Text("Design \(design.name)")
                            .onTapGesture {
                                projectManager.selectedDesign = design
                            }
                    }
                } else {
                    Button {
                    } label: {
                        Text("Add a new Design")
                    }
                }
            }
        }
        .inspector(isPresented: $isShowingInspector) {
            InspectorView(selectedEditor: $selectedEditor)
        }
        .toolbar {
            if let selectedDesign = projectManager.selectedDesign {
                ProjectToolbar(
                    design: selectedDesign,
                    selectedEditor: $selectedEditor,
                    isShowingInspector: $isShowingInspector,
                    openWindow: openWindow,
                    modelContext: modelContext
                )
            }
        }
        .navigationTitle("")
    }
}

#Preview {
    ProjectView(project: Project(name: "Test Project", designs: []))
}
