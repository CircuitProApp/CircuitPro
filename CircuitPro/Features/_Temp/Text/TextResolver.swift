//
//  TextResolver.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/2/25.
//

import Foundation

struct TextResolver {

    /// Resolves all text elements for a symbol and its instance into a list
    /// of display-ready `ResolvedText` view models.
    static func resolve(from symbol: Symbol, and instance: SymbolInstance, with properties: [ResolvedProperty], referenceDesignator: String) -> [ResolvedText] {
        
        let overrideMap = Dictionary(
            uniqueKeysWithValues: instance.textOverrides.map { ($0.definitionID, $0) }
        )

        // Process all text definitions from the library symbol.
        let definitionTexts = symbol.textDefinitions.compactMap { def -> ResolvedText? in
            let override = overrideMap[def.id]
            
            // Handle visibility override.
            if let override, !override.isVisible { return nil }
            
            return ResolvedText(
                origin: .definition(definitionID: def.id),
                text: resolveString(for: def.source, properties: properties, symbolName: symbol.name, reference: referenceDesignator),
                font: def.font,
                color: def.color,
                alignment: def.alignment,
                relativePosition: override?.relativePositionOverride ?? def.relativePosition,
                anchorRelativePosition: def.relativePosition
            )
        }
        
        // Process all instance-specific texts.
        let instanceTexts = instance.textInstances.map { inst -> ResolvedText in
            ResolvedText(
                origin: .instance(instanceID: inst.id),
                text: inst.text,
                font: inst.font,
                color: inst.color,
                alignment: inst.alignment,
                relativePosition: inst.relativePosition,
                anchorRelativePosition: inst.relativePosition // An instance text is its own anchor.
            )
        }
        
        return definitionTexts + instanceTexts
    }
    
    /// Private helper to resolve the final string for a dynamic source.
    private static func resolveString(for source: TextSource, properties: [ResolvedProperty], symbolName: String, reference: String) -> String {
        switch source {
        case .static(let text):
            return text
        case .dynamic(let dynamicProperty):
            switch dynamicProperty {
            case .componentName:
                return symbolName
            case .reference:
                return reference
            case .property(let definitionID):
                guard let prop = properties.first(where: {
                    if case .definition(let defID) = $0.source { return defID == definitionID }
                    else { return false }
                }) else { return "n/a" }
                // This would need to use the displayOptions from the TextDefinition,
                // which requires a more complex implementation, but this shows the principle.
                return prop.value.description
            }
        }
    }
}
