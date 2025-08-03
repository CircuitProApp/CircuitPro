//
//  DynamicTextSourceListView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/3/25.
//

import SwiftUI

struct DynamicTextSourceListView: View {
    @Environment(ComponentDesignManager.self) private var componentDesignManager
    let editor: CanvasEditorManager

    private var componentData: (name: String, prefix: String, properties: [PropertyDefinition]) {
        (componentDesignManager.componentName, componentDesignManager.referenceDesignatorPrefix, componentDesignManager.componentProperties)
    }

    private var helpText: (_ isPlaced: Bool) -> String {
        return { isPlaced in
            let location = (editor === componentDesignManager.symbolEditor) ? "symbol" : "footprint"
            if isPlaced {
                return "Property is already on the \(location)"
            } else {
                return "Add property to \(location)"
            }
        }
    }

    var body: some View {
        List {
            Section(header: Text("Dynamic Texts")) {
                ForEach(componentDesignManager.availableTextSources, id: \.source) { item in
                    HStack {
                        Text(item.displayName)
                        Spacer()
                        Button {
                            editor.addTextToSymbol(
                                source: item.source,
                                displayName: item.displayName,
                                componentData: componentData
                            )
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .disabled(editor.placedTextSources.contains(item.source))
                        .help(helpText(editor.placedTextSources.contains(item.source)))
                    }
                }
            }
        }
        .listStyle(.plain)
        .frame(height: 260)
        .alternatingRowBackgrounds(.enabled)
    }
}
