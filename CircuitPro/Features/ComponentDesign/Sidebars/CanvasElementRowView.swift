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
    
    private var componentProperties: [PropertyDefinition] {
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
                Text(textNode.textModel.text)
                
            default:
                Label("Unknown Element", systemImage: "questionmark.diamond")
                
            }
        
    }
    
    //    @ViewBuilder
    //    private func textElementRow(_ textElement: TextElement) -> some View {
    //        if let source = editor.textSourceMap[textElement.id] {
    //            switch source {
    //            case .dynamic(.componentName):
    //                Label("Component Name", systemImage: "c.square.fill")
    //            case .dynamic(.reference):
    //                Label("Reference Designator", systemImage: "textformat.alt")
    //            case .dynamic(.property(let definitionID)):
    //                let displayName = componentProperties.first { $0.id == definitionID }?.key.label ?? "Dynamic Property"
    //                Label(displayName, systemImage: "tag.fill")
    //            case .static:
    //                Label("\"\(textElement.text)\"", systemImage: "text.bubble.fill")
    //            }
    //        } else {
    //            Label("\"\(textElement.text)\"", systemImage: "text.bubble.fill")
    //        }
    //    }
}
