//
//  FootprintPropertiesEditorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/28/25.
//


//
//  FootprintPropertiesEditorView.swift
//  CircuitPro
//
//  Created by Gemini on 28.07.25.
//

import SwiftUI

struct FootprintPropertiesEditorView: View {
    @Environment(\.componentDesignManager) private var componentDesignManager

    var body: some View {
        @Bindable var manager = componentDesignManager
        
        VStack {
            // 1. Show a placeholder if no footprint elements are selected.
            if manager.selectedFootprintElementIDs.isEmpty {
                placeholder("No elements selected")
            } else {
                Form {
                    // 2. Section for Pads
                    // Iterate over all footprint elements to find the selected pads.
                    ForEach($manager.footprintElements) { $element in
                        if case .pad(let pad) = element, manager.selectedFootprintElementIDs.contains(pad.id) {
                            // Safely unwrap the binding to the pad.
                            if let padBinding = $element.pad {
                                Section("Pad \(pad.number) Properties") {
                                    // This view will receive the binding and can modify the pad directly.
                                    PadPropertiesView(pad: padBinding)
                                }
                            }
                        }
                    }

                    // 3. Section for Primitives
                    // Iterate again to find the selected primitives.
                    ForEach($manager.footprintElements) { $element in
                        if case .primitive(let primitive) = element, manager.selectedFootprintElementIDs.contains(primitive.id) {
                            // Safely unwrap the binding to the primitive.
                            if let primitiveBinding = $element.primitive {
                                Section("\(primitive.displayName) Properties") {
                                    // This view will receive the binding for the primitive.
                                    PrimitivePropertiesView(primitive: primitiveBinding)
                                }
                            }
                        }
                    }
                }
                .formStyle(.grouped)
                .listStyle(.inset)
            }
        }
    }

    // A helper view for displaying the placeholder text
    private func placeholder(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text)
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
