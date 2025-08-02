//
//  SymbolElementListView.swift
//  CircuitPro
//
//  Created by Gemini on 28.07.25.
//

import SwiftUI

struct SymbolElementListView: View {
    @Environment(\.componentDesignManager) private var componentDesignManager

    private var symbolEditor: CanvasEditorManager {
        componentDesignManager.symbolEditor
    }
    
    private var componentData: (name: String, prefix: String, properties: [PropertyDefinition]) {
        (componentDesignManager.componentName, componentDesignManager.referenceDesignatorPrefix, componentDesignManager.componentProperties)
    }
    
    private var availableTextSources: [(displayName: String, source: TextSource)] {
        var sources: [(String, TextSource)] = []
        if !componentData.name.isEmpty { sources.append(("Name", .dynamic(.componentName))) }
        if !componentData.prefix.isEmpty { sources.append(("Reference", .dynamic(.reference))) }
        for propDef in componentData.properties {
            sources.append((propDef.key.label, .dynamic(.property(definitionID: propDef.id))))
        }
        return sources
    }

    var body: some View {
        @Bindable var manager = symbolEditor
        
        VStack(alignment: .leading, spacing: 0) {
            Text("Symbol Elements")
                .font(.title3.weight(.semibold))
                .padding(10)

            if manager.elements.isEmpty {
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
                    ForEach(manager.elements) { element in
                        rowView(for: element)
                            .tag(element.id)
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
            List {
                ForEach(availableTextSources, id: \.source) { item in
                    HStack {
                        Text(item.displayName)
                        Spacer()
                        Button {
                            symbolEditor.addTextToSymbol(
                                source: item.source,
                                displayName: item.displayName,
                                componentData: componentData
                            )
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .disabled(symbolEditor.placedTextSources.contains(item.source))
                        .help(
                            symbolEditor.placedTextSources.contains(item.source)
                                ? "Property is already on the symbol"
                                : "Add property to symbol"
                        )
                    }
                }
            }
            .listStyle(.bordered(alternatesRowBackgrounds: true))
        }
    }

    @ViewBuilder
    private func rowView(for element: CanvasElement) -> some View {
        switch element {
        case .pin(let pin):
            Label("Pin \(pin.number)", systemImage: CircuitProSymbols.Symbol.pin)
        case .primitive(let primitive):
            Label(primitive.displayName, systemImage: primitive.symbol)
        case .text(let textElement):
            if let source = symbolEditor.textSourceMap[textElement.id] {
                switch source {
                case .dynamic(.componentName):
                    Label("Component Name", systemImage: "c.square.fill")
                case .dynamic(.reference):
                    Label("Reference Designator", systemImage: "textformat.alt")
                case .dynamic(.property(let definitionID)):
                    let displayName = componentData.properties.first { $0.id == definitionID }?.key.label ?? "Dynamic Property"
                    Label(displayName, systemImage: "tag.fill")
                case .static:
                    Label("\"\(textElement.text)\"", systemImage: "text.bubble.fill")
                }
            } else {
                Label("\"\(textElement.text)\"", systemImage: "text.bubble.fill")
            }
        default:
            EmptyView()
        }
    }
}


