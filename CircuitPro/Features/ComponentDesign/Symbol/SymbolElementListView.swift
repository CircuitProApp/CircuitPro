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
        VStack(alignment: .leading) {
            Text("Elements")
                .font(.title2.weight(.semibold))
                .padding(.horizontal)
                .padding(.top)

            if componentDesignManager.symbolElements.isEmpty {
                ContentUnavailableView(
                    "No Symbol Elements",
                    systemImage: "square.on.circle",
                    description: Text("Add pins and primitives to the symbol from the toolbar.")
                )
            } else {
                List(selection: $manager.selectedSymbolElementIDs) {
                    ForEach(componentDesignManager.symbolElements) { element in
                        rowView(for: element)
                            .tag(element.id)
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .frame(minWidth: 220)
    }

    @ViewBuilder
    private func rowView(for element: CanvasElement) -> some View {
        switch element {
        case .pin(let pin):
            Label("Pin \(pin.number)", systemImage: "mappin.and.ellipse")
        case .primitive(let primitive):
            Label(primitive.displayName, systemImage: "square.on.circle")
        case .text(let textElement):
            if textElement.id == componentDesignManager.abbreviationTextElementID {
                Label("Abbreviation Text", systemImage: "textformat.alt")
            } else {
                Label("\"\(textElement.text)\"", systemImage: "text.bubble")
            }
        default:
            // Other canvas element types are not expected in the symbol editor.
            EmptyView()
        }
    }
}

