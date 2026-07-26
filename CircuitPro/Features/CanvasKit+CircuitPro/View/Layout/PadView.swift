import AppKit

struct PadView: CKView {
    @CKContext var context
    @CKEnvironment var environment
    let pad: Pad

    var showHalo: Bool {
        context.highlightedItemIDs.contains(pad.id) ||
            context.selectedItemIDs.contains(pad.id)
    }

    var placementSide: BoardSide = .front

    /// Pads always sit on the outer copper of whichever side they're placed on, so their
    /// color follows that copper layer rather than being stored on the pad itself. In
    /// single-sided design contexts (e.g. footprint authoring) the copper layer has no
    /// `layerSide`, so a front pad also matches that unsided layer.
    var padColor: CGColor {
        let copperLayers = context.layers.compactMap { $0 as? PCBLayer }.filter { $0.layerKind == .copper }
        let matchedLayer: PCBLayer?
        switch placementSide {
        case .front:
            matchedLayer = copperLayers.first { $0.layerSide == .front } ?? copperLayers.first { $0.layerSide == nil }
        case .back:
            matchedLayer = copperLayers.first { $0.layerSide == .back }
        }
        return matchedLayer?.color ?? environment.canvasTheme.textColor
    }

    var body: some CKView {
        CKComposite(rule: .evenOdd) {
            switch pad.shape {
            case .rect(let width, let height):
                CKRectangle(width: width, height: height)
            case .circle(let radius):
                CKCircle(radius: radius)
            }
            if pad.type == .throughHole, let drillDiameter = pad.drillDiameter, drillDiameter > 0 {
                CKCircle(radius: drillDiameter / 2)
            }
        }
        .position(pad.position)
        .rotation(pad.rotation)
        .fill(padColor)
        .halo(showHalo ? padColor.copy(alpha: 0.4) ?? .clear : .clear, width: 5.0)
    }
}
