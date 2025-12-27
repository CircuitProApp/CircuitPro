//
//  SymbolElementListView.swift
//  CircuitPro
//
//  Created by Gemini on 28.07.25.
//

import SwiftUI

struct SymbolElementListView: View {

    @BindableEnvironment(CanvasEditorManager.self)
    private var symbolEditor

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Symbol Elements")
                .font(.headline)
                .padding(10)

            if symbolEditor.elementItems.isEmpty {
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
                List(selection: $symbolEditor.selectedElementIDs) {
                    ForEach(symbolEditor.elementItems) { element in
                        CanvasElementRowView(element: element)
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
