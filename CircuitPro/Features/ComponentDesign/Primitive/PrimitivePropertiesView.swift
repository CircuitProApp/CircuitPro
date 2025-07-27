//
//  PrimitivePropertiesView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/27/25.
//

import SwiftUI

struct PrimitivePropertiesView: View {
    // 1. Binding to the selected primitive
    @Binding var primitive: AnyPrimitive

    var body: some View {
        // 2. Show a read-only summary based on the concrete primitive
        switch primitive {
        case .rectangle(let rect):
            rectangleSummary(rect)
        case .circle(let circ):
            circleSummary(circ)
        case .line(let line):
            lineSummary(line)
        default:
            Text("Unsupported primitive")
                .foregroundStyle(.secondary)
        }
    }

    // 3. Rectangle summary
    private func rectangleSummary(_ rect: RectanglePrimitive) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Rectangle")
                .font(.headline)
            Text("Origin: (\(rect.position.x.formatted()), \(rect.position.y.formatted()))")
            Text("Size: \(rect.size.width.formatted()) × \(rect.size.height.formatted())")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(6)
    }

    // 4. Circle summary
    private func circleSummary(_ circ: CirclePrimitive) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Circle")
                .font(.headline)
            Text("Center: (\(circ.position.x.formatted()), \(circ.position.y.formatted()))")
            Text("Radius: \(circ.radius.formatted())")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(6)
    }
    
    private func lineSummary(_ line: LinePrimitive) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Line")
                .font(.headline)
            Text("Start: (\(line.start.x.formatted()), \(line.start.y.formatted()))")
        }
    }
}
