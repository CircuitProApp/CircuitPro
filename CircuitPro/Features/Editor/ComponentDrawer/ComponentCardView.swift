//
//  ComponentCardView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/7/25.
//

import SwiftUI
import RealityKit

struct ComponentCardView: View {

    let component: Component

    @State private var selectedViewType: ComponentViewType = .symbol

    var body: some View {
        VStack(spacing: 5) {
            Group {
                if let sym = component.symbol,
                   !(sym.primitives.isEmpty && sym.pins.isEmpty) {

                    SymbolThumbnail(symbol: sym, side: 100)

                } else {
                    Text("No symbol")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 110, height: 110)
            .background(.gray.opacity(0.1))
            .clipAndStroke(with: .rect(cornerRadius: 15))
            .draggableIfPresent(TransferableComponent(component: component), symbol: component.symbol)
            Text(component.name)
                .lineLimit(2)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

}

#Preview {
    ComponentCardView(component: Component(name: "Pololu Distance Sensor", referenceDesignatorPrefix: "VL53L1X"))
}

struct SymbolThumbnail: View {

    let symbol: Symbol               // the real model
    var side: CGFloat = 100
    private let padding: CGFloat = 0.9

    var body: some View {
        Canvas { context, size in
            guard let transform = makeFittingTransform(for: size) else { return }

            context.withCGContext { cgContext in
                cgContext.saveGState()
                cgContext.concatenate(transform)

                // Primitives
//                for primitive in symbol.primitives {
//                    primitive.draw(in: cgContext, selected: false)
//                }

                // Pins (no text → unreadable in 100 pt)
//                for pin in symbol.pins {
//                    pin.draw(in: cgContext, selected: false)
//                }

                cgContext.restoreGState()
            }
        }
        .frame(width: side, height: side)
    }
}

// MARK: - Geometry helpers
private extension SymbolThumbnail {

    func makeFittingTransform(for size: CGSize) -> CGAffineTransform? {

        // 1. collect bounds of everything
        let boxes = symbol.primitives
            .map { $0.makePath().boundingBoxOfPath }
          + symbol.pins
            .flatMap { $0.primitives }
            .map { $0.makePath().boundingBoxOfPath }

        guard let first = boxes.first else { return nil }

        // 2. overall bounds
        let bounds = boxes.dropFirst()
                          .reduce(first, { $0.union($1) })

        guard bounds.width > 0, bounds.height > 0 else { return nil }

        // 3. aspect-preserving scale
        let scale = padding * min(size.width / bounds.width, size.height / bounds.height)

        // 4. resulting size after scale
        let rendered = CGSize(width: bounds.width  * scale, height: bounds.height * scale)

        // 5. build transform: move → scale → centre
        let moveToOrigin = CGAffineTransform(translationX: -bounds.minX, y: -bounds.minY)

        let scaleUp = CGAffineTransform(scaleX: scale, y: scale)

        let centre = CGAffineTransform(
            translationX: (size.width  - rendered.width ) / 2,
            y: (size.height - rendered.height) / 2
        )

        return moveToOrigin.concatenating(scaleUp).concatenating(centre)
    }
}
