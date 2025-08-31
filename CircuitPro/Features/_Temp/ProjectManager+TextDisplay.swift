//
//  ProjectManager+TextDisplay.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/31/25.
//


import Foundation
import SwiftUI

extension ProjectManager {
    enum TextDisplayPart {
        case key, value, unit
    }
    
    func displayOptions(for component: ComponentInstance, source: TextSource) -> TextDisplayOptions {
        guard let definition = component.definition,
              let symbol = definition.symbol else {
            return .default
        }
        
        // Prefer overrides for definition-based texts
        if let def = symbol.textDefinitions.first(where: { $0.contentSource == source }),
           let override = component.symbolInstance.textOverrides.first(where: { $0.definitionID == def.id }),
           let overrideOptions = override.displayOptions {
            return overrideOptions
        }
        
        // Fallback to instance-based text options if present
        if let inst = component.symbolInstance.textInstances.first(where: { $0.contentSource == source }) {
            return inst.displayOptions
        }
        
        // Ultimately default
        return .default
    }
    
    func toggleTextDisplayPart(for component: ComponentInstance, source: TextSource, part: TextDisplayPart) {
        var options = displayOptions(for: component, source: source)
        switch part {
        case .key: options.showKey.toggle()
        case .value: options.showValue.toggle()
        case .unit: options.showUnit.toggle()
        }
        setDisplayOptions(for: component, source: source, options: options)
    }
    
    func setDisplayOptions(for component: ComponentInstance, source: TextSource, options: TextDisplayOptions) {
        guard let definition = component.definition,
              let symbol = definition.symbol else { return }
        
        // Case 1: A definition exists for this text -> use override record.
        if let textDefinition = symbol.textDefinitions.first(where: { $0.contentSource == source }) {
            if let overrideIndex = component.symbolInstance.textOverrides.firstIndex(where: { $0.definitionID == textDefinition.id }) {
                component.symbolInstance.textOverrides[overrideIndex].displayOptions = options
            } else {
                var newOverride = CircuitText.Override(definitionID: textDefinition.id)
                newOverride.displayOptions = options
                component.symbolInstance.textOverrides.append(newOverride)
            }
            rebuildCanvasNodes()
            return
        }
        
        // Case 2: Instance exists -> update it.
        if let instanceIndex = component.symbolInstance.textInstances.firstIndex(where: { $0.contentSource == source }) {
            component.symbolInstance.textInstances[instanceIndex].displayOptions = options
            rebuildCanvasNodes()
            return
        }
        
        // Case 3: No definition or instance -> create a hidden instance with the desired options.
        let existingTextPositions = component.symbolInstance.textInstances.map(\.relativePosition)
        let lowestY = existingTextPositions.map(\.y).min() ?? -20
        let newPosition = CGPoint(x: 0, y: lowestY - 10)
        
        var newTextInstance = CircuitText.Instance(
            id: UUID(),
            contentSource: source,
            relativePosition: newPosition,
            anchorPosition: newPosition,
            font: .init(font: .systemFont(ofSize: 12)),
            color: .init(color: .black),
            anchor: .leading,
            alignment: .left,
            cardinalRotation: .east,
            isVisible: false // do not auto-show when only changing formatting
        )
        newTextInstance.displayOptions = options
        component.symbolInstance.textInstances.append(newTextInstance)
        
        rebuildCanvasNodes()
    }
}
