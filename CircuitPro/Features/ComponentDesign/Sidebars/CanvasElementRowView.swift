//
//  CanvasElementRowView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/3/25.
//

import SwiftUI

struct CanvasElementRowView: View {
    @Environment(ComponentDesignManager.self) private var componentDesignManager
    let element: any CanvasNode
    let editor: CanvasEditorManager
    
    private var componentProperties: [Property.Definition] {
        componentDesignManager.componentProperties
    }
    
   
    var body: some View {
        
    
        switch element {
        case let primitiveNode as PrimitiveNode:
            Label(primitiveNode.displayName, systemImage: primitiveNode.symbol)
        case let pinNode as PinNode:
            Label("Pin \(pinNode.pin.number)", systemImage: CircuitProSymbols.Symbol.pin)
        case let padNode as PadNode:
            Label("Pin \(padNode.pad.number)", systemImage: CircuitProSymbols.Footprint.pad)

        case let textNode as TextNode:
            switch textNode.resolvedText.content {
            case .static(let text):
                Label("\"\(text)\"", systemImage: "text.bubble.fill")

            case .componentName:
                Label("Component Name", systemImage: "c.square.fill")
                
            case .componentReferenceDesignator:
                Label("Reference Designator", systemImage: "textformat.alt")
                
            case .componentProperty(let definitionID, _):
                let displayName = componentProperties.first { $0.id == definitionID }?.key.label ?? "Dynamic Property"
                Label(displayName, systemImage: "tag.fill")
            }
            
        default:
            Label("Unknown Element", systemImage: "questionmark.diamond")
        }
        
    }
}
