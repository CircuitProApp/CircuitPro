//
//  SymbolElementListView.swift
//  CircuitPro
//
//  Created by Gemini on 28.07.25.
//

import SwiftUI

struct SymbolElementListView: View {
    @Environment(ComponentDesignManager.self) private var componentDesignManager

    private var symbolEditor: CanvasEditorManager {
        componentDesignManager.symbolEditor
    }

    var body: some View {
        @Bindable var manager = symbolEditor
        
        VStack(alignment: .leading, spacing: 0) {
            Text("Symbol Elements")
                .font(.headline)
                .padding(10)

            if manager.canvasNodes.isEmpty {
                ContentUnavailableView {
                    Label {
                        Text("No Symbol Elements")
                            .font(.headline)
                    } icon: {
                        Image(systemName: "square.on.circle")
                    }
                } description: {
                    Text("Add pins and primitives to the symbol from the toolbar.")
                        .font(.callout)
                        .fontWeight(.semibold)
                }
                .frame(maxHeight: .infinity)
            } else {
                List(selection: $manager.selectedElementIDs) {
                    ForEach(manager.canvasNodes) { element in
                        CanvasElementRowView(element: element, editor: symbolEditor)
                            .tag(element.id)
                    }
                 
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
            TextSourceListView(editor: symbolEditor)
        }
    }
}
