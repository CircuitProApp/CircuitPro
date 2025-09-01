//
//  TextSourceListView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/3/25.
//

import SwiftUI

struct TextSourceListView: View {
    @Environment(ComponentDesignManager.self) private var componentDesignManager
    
    // The editor is correctly passed in. No change needed here.
    let editor: CanvasEditorManager

    private var componentData: (name: String, prefix: String, properties: [Property.Definition]) {
        (componentDesignManager.componentName, componentDesignManager.referenceDesignatorPrefix, componentDesignManager.componentProperties)
    }

    private var helpText: (_ isPlaced: Bool) -> String {
        { isPlaced in
            let location = (editor === componentDesignManager.symbolEditor) ? "symbol" : "footprint"
            if isPlaced {
                return "Remove this text from the \(location)"
            } else {
                return "Add this text to the \(location)"
            }
        }
    }

    var body: some View {
        List {
            // This section assumes componentDesignManager.availableTextSources now provides
            // an array of a struct like `(displayName: String, source: CircuitTextContent)`.
            Section(header: Text("Dynamic Texts")) {
                ForEach(componentDesignManager.availableTextSources, id: \.source) { item in
                    
                    // --- THIS IS THE FIX ---
                    // 1. Use the new `placedTextContents` property from the editor.
                    // 2. Use `contains(where:)` with the `isSameType` helper to correctly
                    //    check for enum cases while ignoring associated values like display options.
                    let isPlaced = editor.placedTextContents.contains { contentOnCanvas in
                        contentOnCanvas.isSameType(as: item.source)
                    }

                    HStack {
                        Text(item.displayName)
                        Spacer()
                        Button {
                            // --- ALSO UPDATED ---
                            // The method parameter label changed from `source` to `content`.
                            if isPlaced {
                                editor.removeTextFromSymbol(content: item.source)
                            } else {
                                // The `displayName` parameter is no longer needed.
                                editor.addTextToSymbol(
                                    content: item.source,
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
