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
        { isPlaced in
            let location = (editor === componentDesignManager.symbolEditor) ? "symbol" : "footprint"
            if isPlaced {
                return "Remove property from \(location)"
            } else {
                return "Add property to \(location)"
            }
        }
    }

    var body: some View {
        List {
            Section(header: Text("Dynamic Texts")) {
                ForEach(componentDesignManager.availableTextSources, id: \.source) { item in
                    let isPlaced = editor.placedTextSources.contains(item.source)

                    HStack {
                        Text(item.displayName)
                        Spacer()
                        Button {
                            if isPlaced {
                                editor.removeTextFromSymbol(source: item.source)
                            } else {
                                editor.addTextToSymbol(
                                    source: item.source,
                                    displayName: item.displayName,
                                    componentData: componentData
                                )
                            }
                        } label: {
                            Image(systemName: isPlaced ? "minus.circle.fill" : "plus.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .help(helpText(isPlaced))
                    }
                }
            }
        }
        .listStyle(.plain)
        .frame(height: 260)
        .alternatingRowBackgrounds(.enabled)
    }
}
