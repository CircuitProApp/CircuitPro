import AppKit

struct PadView: CKView {
    @CKContext var context
    let pad: Pad

    var showHalo: Bool {
        context.highlightedItemIDs.contains(pad.id) ||
            context.selectedItemIDs.contains(pad.id)
    }

    var placementSide: BoardSide = .front

    var padColor: CGColor {
        placementSide == .front ? NSColor.systemRed.cgColor : NSColor.systemBlue.cgColor
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
