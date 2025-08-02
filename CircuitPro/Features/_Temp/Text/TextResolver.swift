//
//  TextResolver.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/2/25.
//

import Foundation

struct TextResolver {

    /// Resolves all text elements for a symbol and its instance into a single list
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
            
            // THIS IS THE FIX (Part 1): Pass the entire `def` object to the helper.
            let resolvedString = resolveString(
                for: def, // Pass the whole definition
                properties: properties,
                symbolName: symbol.name,
                reference: referenceDesignator
            )
            
            return ResolvedText(
                origin: .definition(definitionID: def.id),
                text: resolvedString,
                font: def.font,
                color: def.color,
                alignment: def.alignment,
                relativePosition: override?.relativePositionOverride ?? def.relativePosition,
                anchorRelativePosition: def.relativePosition
            )
        }
        
        // Process all instance-specific texts (this part remains unchanged).
        let instanceTexts = instance.textInstances.map { inst -> ResolvedText in
            ResolvedText(
                origin: .instance(instanceID: inst.id),
                text: inst.text,
                font: inst.font,
                color: inst.color,
                alignment: inst.alignment,
                relativePosition: inst.relativePosition,
                anchorRelativePosition: inst.relativePosition
            )
        }
        
        return definitionTexts + instanceTexts
    }
    
    /// Private helper to resolve the final string for a dynamic source.
    // THIS IS THE FIX (Part 2): The helper now accepts the full `TextDefinition`.
    private static func resolveString(for definition: TextDefinition, properties: [ResolvedProperty], symbolName: String, reference: String) -> String {
        
        switch definition.source {
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
                
                // THIS IS THE FIX (Part 3): The full, correct string-building logic.
                var parts: [String] = []
                let options = definition.displayOptions
                
                if options.showKey {
                    parts.append("\(prop.key.label):")
                }
                
                if options.showValue {
                    parts.append(prop.value.description)
                }
                
                // CRUCIAL FIX: Check if the unit should be shown and if it's not empty.
                if options.showUnit, !prop.unit.symbol.isEmpty {
                    parts.append(prop.unit.symbol)
                }
                
                return parts.joined(separator: " ")
            }
        }
    }
}
