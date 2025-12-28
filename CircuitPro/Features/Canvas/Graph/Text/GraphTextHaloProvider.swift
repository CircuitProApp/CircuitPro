//
//  GraphTextHaloProvider.swift
//  CircuitPro
//
//  Created by Codex on 9/22/25.
//

import AppKit

struct GraphTextHaloProvider: GraphHaloProvider {
    func haloPrimitives(from graph: CanvasGraph, context: RenderContext, highlightedIDs: Set<UUID>)
        -> [UUID?: [DrawingPrimitive]]
    {
        var primitivesByLayer: [UUID?: [DrawingPrimitive]] = [:]

        for (id, component) in graph.components(GraphTextComponent.self) {
            guard highlightedIDs.contains(id.rawValue) else { continue }
            if highlightedIDs.contains(component.ownerID) {
                continue
            }
            guard component.isVisible else { continue }
            let worldPath = component.worldPath()
            guard !worldPath.isEmpty else { continue }

            let theme = context.environment.canvasTheme
            let textColor = theme.textColor
            let crosshairColor = theme.crosshairColor

            let nsTextColor = NSColor(cgColor: textColor) ?? .labelColor
            var saturation: CGFloat = 0
            var isChromatic = false
            if let sRGBColor = nsTextColor.usingColorSpace(.sRGB) {
                sRGBColor.getHue(nil, saturation: &saturation, brightness: nil, alpha: nil)
                isChromatic = saturation > 0.1
            }

            let baseColor = isChromatic ? textColor : crosshairColor
            let haloColor =
                NSColor(cgColor: baseColor)?.withAlphaComponent(0.4).cgColor ?? baseColor

            let haloPrimitive = DrawingPrimitive.stroke(
                path: worldPath,
                color: haloColor,
                lineWidth: 5.0,
                lineCap: .round,
                lineJoin: .round
            )

            primitivesByLayer[component.layerId, default: []].append(haloPrimitive)
        }

        return primitivesByLayer
    }
}
