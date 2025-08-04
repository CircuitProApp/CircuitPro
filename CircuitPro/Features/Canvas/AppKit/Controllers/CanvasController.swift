import AppKit

@Observable
final class CanvasController {

    // MARK: - Core Data Model
    
    let sceneRoot: any CanvasNode = BaseNode()
    var selectedNodes: [any CanvasNode] = []
    var marqueeHoveredNodes: [any CanvasNode] = []

    var highlightedNodeIDs: Set<UUID> {
        let selected = Set(selectedNodes.map { $0.id })
        let hovered = Set(marqueeHoveredNodes.map { $0.id })
        return selected.union(hovered)
    }

    var selectedTool: AnyCanvasTool?
    var selectedLayer: CanvasLayer = .layer0
    var schematicGraph: SchematicGraph = .init()

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

    // MARK: - Rendering & Callbacks
    
    private(set) var renderLayers: [RenderLayer] = []
    var onNeedsRedraw: (() -> Void)?
    var onUpdateSelectedNodes: (([any CanvasNode]) -> Void)?
    var onUpdateSelectedTool: ((AnyCanvasTool) -> Void)?

    init() {
        self.renderLayers = [
            GridRenderLayer(),
            SheetRenderLayer(),
            GuideRenderLayer(),
            ConnectionsRenderLayer(),
            ElementsRenderLayer(),
            PreviewRenderLayer(),
            MarqueeRenderLayer(),
            CrosshairsRenderLayer()
        ]
    }
    
    func redraw() {
        onNeedsRedraw?()
    }
    
    func snap(_ point: CGPoint) -> CGPoint {
        let origin: CGPoint = .zero
        let service = SnapService(gridSize: snapGridSize, isEnabled: isSnappingEnabled, origin: origin)
        return service.snap(point)
    }
    
    func rebuildScene(from designComponents: [DesignComponent]) {
        // Clear existing nodes.
        self.sceneRoot.children.removeAll()
        
//        for dc in designComponents {
//            let instanceID = dc.instance.id
//            
//            // Resolve the data needed to build the node.
//            let resolvedProperties = PropertyResolver.resolve(from: dc.definition, and: dc.instance)
//            
//            let resolvedTexts = TextResolver.resolve(
//                from: dc.definition.symbol!,
//                and: dc.instance.symbolInstance,
//                componentName: dc.definition.name,
//                reference: dc.referenceDesignator,
//                properties: resolvedProperties
//            )
//            
//            // Create the new SymbolNode.
//            // This assumes you will create a `SymbolNode` class similar to `PrimitiveNode`.
//            let newSymbolNode = SymbolNode(
//                id: instanceID,
//                instance: dc.instance.symbolInstance,
//                symbol: dc.definition.symbol!,
//                reference: dc.referenceDesignator,
//                properties: resolvedProperties,
//                resolvedTexts: resolvedTexts
//            )
//            
//            // Add the new node to the scene.
//            self.sceneRoot.addChild(newSymbolNode)
//        }
    }
}
