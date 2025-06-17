//
//  ProjectToolbar.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/14/25.
//

import SwiftUI
import SwiftData

struct ProjectToolbar: ToolbarContent {

    @Binding var selectedEditor: EditorType
    @Binding var isShowingInspector: Bool
    var openWindow: OpenWindowAction
    var modelContext: ModelContext

    var body: some ToolbarContent {
//        ToolbarItem(placement: .navigation) {
//            TextField("Design Name", text: $design.name)
//                .font(.title3)
//                .fontWeight(.semibold)
//        }

        ToolbarItem(placement: .principal) {
            Picker("View", selection: $selectedEditor) {
                Text("Schematics").tag(EditorType.schematic)
                Text("Layout").tag(EditorType.layout)
            }
            .pickerStyle(.segmented)
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                openWindow(id: "SecondWindow")
            } label: {
                Label("Board Setup", systemImage: AppIcons.gear)
            }
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                isShowingInspector.toggle()
            } label: {
                Label("\(isShowingInspector ? "Hide" : "Show") Inspector", systemImage: AppIcons.infoCircle)
                    .labelStyle(.iconOnly)
            }
        }

        ToolbarItem(placement: .navigation) {
            Button {
                // 1) Define your graphic primitives
                let primitives: [AnyPrimitive] = [
                    .rectangle(
                        .init(
                            uuid: UUID(),
                            position: .zero,
                            size: .init(width: 40, height: 20),
                            rotation: .zero,
                            strokeWidth: 1,
                            color: .init(color: .red),
                            filled: false
                        )
                    )
                ]

                // 2) Create the Component (no symbol yet)
                let newComponent = Component(name: "Resistor 2")

                // 3) Create its Symbol, pointing back at that Component
                let newSymbol = Symbol(
                    name: "Resistor",
                    component: newComponent,
                    primitives: primitives
                )

                // 4) Wire the back‑link
                newComponent.symbol = newSymbol

                // 5) Insert both into SwiftData
                modelContext.insert(newComponent)
                modelContext.insert(newSymbol)
            } label: {
                Image(systemName: AppIcons.plus)
            }
        }

    }
}
