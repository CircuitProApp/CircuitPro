//
//  SymbolElementListView.swift
//  CircuitPro
//
//  Created by Gemini on 28.07.25.
//

import SwiftUI

struct SymbolElementListView: View {
    @Environment(\.componentDesignManager) private var componentDesignManager

    var body: some View {
        @Bindable var manager = componentDesignManager
        
        VStack(alignment: .leading, spacing: 0) {
            Text("Symbol Elements")
                .font(.title3.weight(.semibold))
                .padding(10)

            if componentDesignManager.symbolElements.isEmpty {
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
                List(selection: $manager.selectedSymbolElementIDs) {
                    ForEach(componentDesignManager.symbolElements) { element in
                        rowView(for: element)
                            .tag(element.id)
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
            List {
                // Iterate through the available sources provided by the manager.
                // We use `source` as the ID because it's unique and Hashable.
                ForEach(componentDesignManager.availableTextSources, id: \.source) { item in
                    HStack {
                        // The user-friendly name of the property.
                        Text(item.displayName)
                        
                        Spacer()
                        
                        // The button to add the text to the canvas.
                        Button {
                            // Call the manager's method to perform the action.
                            componentDesignManager.addTextToSymbol(
                                source: item.source,
                                displayName: item.displayName
                            )
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .buttonStyle(.plain)
                        // Disable the button if the source has already been placed.
                        .disabled(componentDesignManager.placedTextSources.contains(item.source))
                        .help(
                            componentDesignManager.placedTextSources.contains(item.source)
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
                // 1. Look up the semantic source of this text element using its ID.
                if let source = componentDesignManager.textSourceMap[textElement.id] {
                    // This is a dynamic text element managed by our system.
                    // Display a descriptive name based on its source.
                    switch source {
                    case .dynamic(.componentName):
                        Label("Component Name", systemImage: "c.square.fill")
                    case .dynamic(.reference):
                        Label("Reference Designator", systemImage: "textformat.alt")
                    case .dynamic(.property(let definitionID)):
                        // Find the property's user-facing name for the label.
                        let displayName = componentDesignManager.componentProperties.first { $0.id == definitionID }?.key?.label ?? "Dynamic Property"
                        Label(displayName, systemImage: "tag.fill")
                    case .static:
                         // This case is unlikely if only dynamic sources are added to the map,
                         // but it's good practice to handle it.
                        Label("\"\(textElement.text)\"", systemImage: "text.bubble.fill")
                    }
                } else {
                    // 2. This is a static text element drawn manually by the user.
                    Label("\"\(textElement.text)\"", systemImage: "text.bubble.fill")
                }
            default:
                // Other canvas element types are not expected in the symbol editor.
                EmptyView()
            }
        }
}


