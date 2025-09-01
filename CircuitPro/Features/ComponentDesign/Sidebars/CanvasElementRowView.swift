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

        // --- THIS IS THE UPDATED CASE ---
        case let textNode as TextNode:
            // We now switch on the `content` enum to determine the appropriate label.
            switch textNode.resolvedText.content {
            case .static(let text):
                // For static text, show its content, but truncate it if it's too long
                // for an outline view. Provide a placeholder if it's empty.
                Text(text.isEmpty ? "Static Text" : text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    
            case .componentName:
                Text("Component Name")
                
            case .componentReferenceDesignator:
                Text("Reference Designator")
                
            case .componentProperty:
                // We could make this more specific by looking up the property name,
                // but "Component Property" is a safe and clear default for an outline.
                Text("Component Property")
            }
            
        default:
            Label("Unknown Element", systemImage: "questionmark.diamond")
        }
        
    }
    
    //    @ViewBuilder
    //    private func textElementRow(_ textModel: TextElement) -> some View {
    //        if let source = editor.textSourceMap[textModel.id] {
    //            switch source {
    //            case .dynamic(.componentName):
    //                Label("Component Name", systemImage: "c.square.fill")
    //            case .dynamic(.reference):
    //                Label("Reference Designator", systemImage: "textformat.alt")
    //            case .dynamic(.property(let definitionID)):
    //                let displayName = componentProperties.first { $0.id == definitionID }?.key.label ?? "Dynamic Property"
    //                Label(displayName, systemImage: "tag.fill")
    //            case .static:
    //                Label("\"\(textModel.text)\"", systemImage: "text.bubble.fill")
    //            }
    //        } else {
    //            Label("\"\(textModel.text)\"", systemImage: "text.bubble.fill")
    //        }
    //    }
}
