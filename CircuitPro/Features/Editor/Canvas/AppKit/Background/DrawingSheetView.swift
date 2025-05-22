import SwiftUI

struct DrawingSheetView: View {

    @Environment(\.projectManager)
    private var projectManager
    @Environment(\.colorScheme)
    private var colorScheme

    @State private var sheetSize: PaperSize = .a4

    var graphicColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private let inset: CGFloat = 15

    var body: some View {
        Canvas { context, size in
            // Outer rectangle covering the entire canvas.
            let outerRect = CGRect(origin: .zero, size: size)
            context.stroke(Path(outerRect), with: .color(graphicColor), lineWidth: 1)

            // Inner rectangle inset from the outer border.
            let insetMargin: CGFloat = inset  // Adjust as needed.
            let innerRect = outerRect.insetBy(dx: insetMargin, dy: insetMargin)
            context.stroke(Path(innerRect), with: .color(graphicColor), lineWidth: 1)

            // Parameters for tick marks.
            let tickSpacing: CGFloat = 100.0

            // --- TOP EDGE ---
            // Create an array of x positions along the top edge from innerRect.minX to innerRect.maxX.
            let topTickPositions = stride(from: innerRect.minX, through: innerRect.maxX, by: tickSpacing).map { $0 }

            // Draw the tick marks along the top edge (ticks extend upward toward the outer rectangle).
            for tickX in topTickPositions {
                var tickPath = Path()
                tickPath.move(to: CGPoint(x: tickX, y: innerRect.minY))
                tickPath.addLine(to: CGPoint(x: tickX, y: outerRect.minY))
                context.stroke(tickPath, with: .color(graphicColor), lineWidth: 1)
            }

            // For each consecutive pair, draw the label centered in the gap.
            for i in 0..<topTickPositions.count - 1 {
                let midX = (topTickPositions[i] + topTickPositions[i+1]) / 2
                // Center the label vertically within the sliver (between outer and inner top edges).
                let midY = (innerRect.minY + outerRect.minY) / 2
                let labelPos = CGPoint(x: midX, y: midY)
                let label = Text("\(i + 1)")
                    .font(.caption2)
                    .foregroundColor(graphicColor)
                context.draw(label, at: labelPos)
            }

            // --- LEFT EDGE ---
            // Create an array of y positions along the left edge from innerRect.minY to innerRect.maxY.
            let leftTickPositions = stride(from: innerRect.minY, through: innerRect.maxY, by: tickSpacing).map { $0 }

            // Draw the tick marks along the left edge (ticks extend leftward toward the outer rectangle).
            for tickY in leftTickPositions {
                var tickPath = Path()
                tickPath.move(to: CGPoint(x: innerRect.minX, y: tickY))
                tickPath.addLine(to: CGPoint(x: outerRect.minX, y: tickY))
                context.stroke(tickPath, with: .color(graphicColor), lineWidth: 1)
            }

            // For each consecutive pair, draw the label centered in the gap.
            for i in 0..<leftTickPositions.count - 1 {
                let midY = (leftTickPositions[i] + leftTickPositions[i+1]) / 2
                // Center the label horizontally within the sliver (between outer and inner left edges).
                let midX = (innerRect.minX + outerRect.minX) / 2
                let labelPos = CGPoint(x: midX, y: midY)
                let label = Text("\(i + 1)")
                    .font(.caption2)
                    .foregroundColor(graphicColor)
                context.draw(label, at: labelPos)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            HStack(spacing: 0) {
                // Overlay cell views.
                cellView(cellTitle: "Title", text: "Test Layout/Sheet")
                cellView(cellTitle: "Project", text: projectManager.project?.name ?? "N/A")
                cellView(
                    cellTitle: "Last Updated",
                    text: projectManager.selectedDesign?.timestamps.dateModified.formatted() ?? "N/A"
                )
                cellView(cellTitle: "Units", text: "mm")
                cellView(cellTitle: "Size", text: sheetSize.name.uppercased())
            }
            .padding(inset)
            .foregroundStyle(graphicColor)
        }
        .frame(width: sheetSize.dimensions.height * 4, height: sheetSize.dimensions.width * 4)
        .border(graphicColor)

    }

    private func cellView(cellTitle: String, text: String) -> some View {
        VStack(alignment: .leading) {
            Text(cellTitle)
                .textCase(.uppercase)
                .font(.caption2)
                .fontDesign(.monospaced)
            Text(text)
                .font(.body)
                .fontDesign(.monospaced)
        }
        .frame(maxWidth: .infinity, minHeight: 25, alignment: .leading)
        .padding(10)
        .overlay(
            Rectangle().stroke(graphicColor, lineWidth: 1)
        )
    }
}

#Preview {
    DrawingSheetView()
}
