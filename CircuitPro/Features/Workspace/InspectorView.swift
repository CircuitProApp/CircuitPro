//
//  InspectorView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/14/25.
//

import SwiftUI

struct InspectorView: View {

    @Environment(\.projectManager)
    private var projectManager

    @State private var selectedLayoutInspector: LayoutInspectorType = .layers
    @Binding var selectedEditor: EditorType

    var body: some View {
        VStack {
            switch selectedEditor {
            case .schematic:
//                NetListView(nets: projectManager.selectedDesign?.schematic?.nets ?? [])
                Text("Jelo")
            case .layout:
                VStack {
                    HStack {
                        Button {
                            selectedLayoutInspector = .layers
                        } label: {
                            Image(systemName: CircuitProSymbols.Layout.layoutLayers)
                                .foregroundStyle(selectedLayoutInspector == .layers ? .primary : .secondary)
                        }

                        Divider()
                            .frame(height: 20)
                        Button {
                            selectedLayoutInspector = .nets
                        } label: {
                            Image(systemName: CircuitProSymbols.Layout.layoutNets)
                                .foregroundStyle(selectedLayoutInspector == .nets ? .primary : .secondary)
                        }
                    }
                    .font(.callout)
                    .buttonStyle(.accessoryBar)
                    switch selectedLayoutInspector {
                    case .layers:
//                        LayerListView(layers: projectManager.selectedDesign?.layout?.layers ?? [])
                        Text("Jelo")
                    case .nets:
//                        NetListView(nets: projectManager.selectedDesign?.schematic?.nets ?? [])
                        Text("melo")
                    }
                }
            }
            Spacer()
        }
        .padding(.top, 10)
        .inspectorColumnWidth(min: 200, ideal: 200, max: 250)
    }
}

#Preview {
    InspectorView(selectedEditor: .constant(.layout))
}
