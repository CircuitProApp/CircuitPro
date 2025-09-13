//
//  TextSourceListView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/3/25.
//

import SwiftUI

struct TextSourceListView: View {
    @Environment(ComponentDesignManager.self) private var componentDesignManager
    
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
            Section(header: Text("Dynamic Texts")) {
                ForEach(componentDesignManager.availableTextSources, id: \.source) { item in

                    let isPlaced = editor.placedTextContents.contains { contentOnCanvas in
                        contentOnCanvas.isSameType(as: item.source)
                    }

                    HStack {
                        Text(item.displayName)
                        Spacer()
                        Button {
                            if isPlaced {
                                editor.removeTextFromSymbol(content: item.source)
                            } else {
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
