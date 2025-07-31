//
//  FootprintPropertiesEditorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/28/25.
//

import SwiftUI

struct FootprintPropertiesEditorView: View {
    @Environment(\.componentDesignManager) private var componentDesignManager
    
    var body: some View {
        @Bindable var manager = componentDesignManager
        
        
        ScrollView {
            // 2. Section for Pads
            // Iterate over all footprint elements to find the selected pads.
            ForEach($manager.footprintElements) { $element in
                if case .pad(let pad) = element, manager.selectedFootprintElementIDs.contains(pad.id) {
                    // Safely unwrap the binding to the pad.
                    if let padBinding = $element.pad {
                        
                        
                        PadPropertiesView(pad: padBinding)
                        
                    }
                } else if case .primitive(let primitive) = element, manager.selectedFootprintElementIDs.contains(primitive.id) {
                    // Safely unwrap the binding to the primitive.
                    if let primitiveBinding = $element.primitive {
                        
                        // This view will receive the binding for the primitive.
                        PrimitivePropertiesView(primitive: primitiveBinding)
                        
                    }
                }
            }
            
            
            
        }
    }
}
