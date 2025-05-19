//
//  FootprintDesignView.swift
//  Electron
//
//  Created by Giorgi Tchelidze on 5/7/25.
//

import SwiftUI

struct FootprintDesignView: View {
    @Environment(CanvasManager.self) private var canvasManager
    @Environment(\.componentDesignManager) private var componentDesignManager
    
    var body: some View {
        @Bindable var bindableComponentDesignManager = componentDesignManager

        CanvasView(manager: canvasManager, elements: $bindableComponentDesignManager.footprintElements, selectedIDs: $bindableComponentDesignManager.selectedFootprintElementIDs, selectedTool: $bindableComponentDesignManager.selectedFootprintTool, selectedLayer: $bindableComponentDesignManager.selectedFootprintLayer, layerAssignments: $bindableComponentDesignManager.layerAssignments)
        
        .clipAndStroke(with: .rect(cornerRadius: 20))
        .overlay {
            VStack {
                Button {
                    print(componentDesignManager.layerAssignments.debugDescription)
                    for element in componentDesignManager.footprintElements {
                        print(element.id)
                    }
    
                } label: {
                    Text("Log Layers and Elements")
                }
                CanvasOverlayView(enableComponentDrawer: false) {
                    FootprintDesignToolbarView()
                }
                .padding(10)
            }
        }
    }
}

