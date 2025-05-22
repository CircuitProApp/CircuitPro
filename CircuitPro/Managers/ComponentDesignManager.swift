//
//  ComponentDesignManager.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/19/25.
//

import SwiftUI
import Observation

@Observable
final class ComponentDesignManager {

    var componentName: String = ""
    var componentAbbreviation: String = ""
    var selectedCategory: ComponentCategory?
    var selectedPackageType: PackageType?
    var componentProperties: [ComponentProperty] = [ComponentProperty(key: nil, value: .single(nil), unit: .init())]

    // MARK: - Symbol
    var symbolElements: [CanvasElement] = []
    var selectedSymbolElementIDs: Set<UUID> = []
    var selectedSymbolTool: AnyCanvasTool = AnyCanvasTool(CursorTool())

    // MARK: - Footprint
    var footprintElements: [CanvasElement] = []
    var selectedFootprintElementIDs: Set<UUID> = []
    var selectedFootprintTool: AnyCanvasTool = AnyCanvasTool(CursorTool())

    var selectedFootprintLayer: LayerKind? = .copper
    var layerAssignments: [UUID: LayerKind] = [:]
}

extension ComponentDesignManager {
    var pins: [Pin] {
        symbolElements.compactMap {
            if case .pin(let pin) = $0 {
                return pin
            }
            return nil
        }
    }

    var selectedPins: [Pin] {
        symbolElements.compactMap {
            if case .pin(let pin) = $0, selectedSymbolElementIDs.contains(pin.id) {
                return pin
            }
            return nil
        }
    }

    func bindingForPin(with id: UUID) -> Binding<Pin>? {
        guard let index = symbolElements.firstIndex(where: {
            if case .pin(let pin) = $0 { return pin.id == id }
            return false
        }) else {
            return nil
        }

        guard case .pin = symbolElements[index] else {
            return nil
        }

        return Binding<Pin>(
            get: {
                if case .pin(let pin) = self.symbolElements[safe: index] {
                    return pin
                } else {
                    return Pin(name: "T", number: 0, position: .zero, type: .unknown) // fallback (or throw)
                }
            },
            set: { newValue in
                if self.symbolElements.indices.contains(index) {
                    self.symbolElements[index] = .pin(newValue)
                }
            }
        )
    }
}

extension ComponentDesignManager {
    var pads: [Pad] {
        footprintElements.compactMap {
            if case .pad(let pad) = $0 {
                return pad
            }
            return nil
        }
    }

    var selectedPads: [Pad] {
        footprintElements.compactMap {
            if case .pad(let pad) = $0, selectedFootprintElementIDs.contains(pad.id) {
                return pad
            }
            return nil
        }
    }

    func bindingForPad(with id: UUID) -> Binding<Pad>? {
        guard let index = footprintElements.firstIndex(where: {
            if case .pad(let pad) = $0 { return pad.id == id }
            return false
        }) else {
            return nil
        }

        guard case .pad = footprintElements[safe: index] else {
            return nil
        }

        return Binding<Pad>(
            get: {
                if case .pad(let pad) = self.footprintElements[safe: index] {
                    return pad
                } else {
                    return Pad(number: 0, position: .zero) // fallback default or handle as needed
                }
            },
            set: { newValue in
                if self.footprintElements.indices.contains(index) {
                    self.footprintElements[index] = .pad(newValue)
                }
            }
        )
    }
}
