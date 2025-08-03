//
//  CanvasController.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/3/25.
//


import AppKit

@Observable
final class CanvasController {
    // MARK: - Canvas Data & State
    var elements: [CanvasElement] = []
    var schematicGraph: SchematicGraph = .init()
    var selectedIDs: Set<UUID> = []
    var marqueeSelectedIDs: Set<UUID> = []
    var selectedTool: AnyCanvasTool?
    var selectedLayer: CanvasLayer = .layer0

    // MARK: - View Configuration
    var magnification: CGFloat = 1.0
    var isSnappingEnabled: Bool = true
    var snapGridSize: CGFloat = 10.0
    var showGuides: Bool = false
    var crosshairsStyle: CrosshairsStyle = .centeredCross
    var paperSize: PaperSize = .iso(.a4)
    var sheetOrientation: PaperOrientation = .landscape
    var sheetCellValues: [String: String] = [:]
    
    // MARK: - Interaction State
    var mouseLocation: CGPoint?
    var marqueeRect: CGRect?

    // MARK: - Rendering
    private(set) var renderLayers: [RenderLayer] = []
    var onNeedsRedraw: (() -> Void)?
    
    var onUpdateElements: (([CanvasElement]) -> Void)?
    var onUpdateSelectedIDs: ((Set<UUID>) -> Void)?
    var onUpdateSelectedTool: ((AnyCanvasTool) -> Void)?
    
    /// Generates the title block values based on the controller's current state.
    var computedSheetCellValues: [(key: String, value: String)] {
        var values: [(key: String, value: String)] = []
        values.append((key: "Size", value: paperSize.name.uppercased()))
        values.append((key: "Units", value: "mm"))
        // Add other key-value pairs here. The order is now preserved.
        return values
    }

    init() {
        // The order here defines the Z-order of the drawing (bottom to top)
        self.renderLayers = [
            GridRenderLayer(),
            SheetRenderLayer(),
            GuideRenderLayer(),
            ConnectionsRenderLayer(),
            ElementsRenderLayer(),
            PreviewRenderLayer(),
            HandlesRenderLayer(),
            MarqueeRenderLayer(),
            CrosshairsRenderLayer()
        ]
    }
    
    /// Call this whenever a state property changes to trigger a visual update.
    func redraw() {
        onNeedsRedraw?()
    }
    
    // MARK: - Business Logic (previously in WorkbenchView)
    
    func snap(_ point: CGPoint) -> CGPoint {
        let origin = showGuides ? CGPoint(x: 0, y: 0) : .zero // Simplified for now
        let service = SnapService(gridSize: snapGridSize, isEnabled: isSnappingEnabled, origin: origin)
        return service.snap(point)
    }

    func syncPinPositionsToGraph() {
        let currentSymbolIDs = Set<UUID>(elements.compactMap {
            guard case .symbol(let symbol) = $0 else { return nil }
            return symbol.id
        })

        let verticesToRemove = schematicGraph.vertices.values.filter { vertex in
            if case .pin(let symbolID, _) = vertex.ownership {
                return !currentSymbolIDs.contains(symbolID)
            }
            return false
        }

        if !verticesToRemove.isEmpty {
            schematicGraph.delete(items: Set(verticesToRemove.map { $0.id }))
        }

        for element in elements {
            guard case .symbol(let symbolElement) = element else { continue }
            let transform = CGAffineTransform(translationX: symbolElement.position.x, y: symbolElement.position.y)
                .rotated(by: symbolElement.rotation)

            for pin in symbolElement.symbol.pins {
                let worldPinPosition = pin.position.applying(transform)
                if let vertexID = schematicGraph.findVertex(ownedBy: symbolElement.id, pinID: pin.id) {
                    schematicGraph.moveVertex(id: vertexID, to: worldPinPosition)
                } else {
                    schematicGraph.getOrCreatePinVertex(at: worldPinPosition, symbolID: symbolElement.id, pinID: pin.id)
                }
            }
        }
    }
}
