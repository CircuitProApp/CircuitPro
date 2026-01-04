import SwiftUI

struct ZoomControlView: View {

    @Environment(CanvasManager.self)
    private var canvasManager

    var currentZoom: CGFloat {
        canvasManager.viewport.magnification
    }

    var clampedZoomText: String {
        let clamped = max(ZoomStep.allCases.first!.rawValue, min(currentZoom, ZoomStep.allCases.last!.rawValue))
        return "\(Int(clamped * 100))%"
    }

    private func zoomOut() {
        let current = currentZoom
        if let currentIndex = ZoomStep.allCases.firstIndex(where: { $0.rawValue >= current }), currentIndex > 0 {
            let newZoom = ZoomStep.allCases[currentIndex - 1].rawValue
            canvasManager.viewport.magnification = newZoom
        }
    }

    private func zoomIn() {
        let current = currentZoom
        if let currentIndex = ZoomStep.allCases.firstIndex(where: { $0.rawValue > current }),
           currentIndex < ZoomStep.allCases.count {
            let newZoom = ZoomStep.allCases[currentIndex].rawValue
            canvasManager.viewport.magnification = newZoom
        }
    }

    var body: some View {
        HStack {
            zoomButton(action: zoomOut, systemImage: CircuitProSymbols.Generic.minus)
            Menu {
                ForEach(ZoomStep.allCases) { step in
                    Button {
                        canvasManager.viewport.magnification = step.rawValue
                    } label: {
                        Text(step.label)
                    }
                }
            } label: {
                HStack(spacing: 2.5) {
                    Text(clampedZoomText)
                        .font(.system(size: 12))
                    Image(systemName: CircuitProSymbols.Generic.chevronDown)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 7, height: 7)
                        .fontWeight(.medium)
                }
            }
            zoomButton(action: zoomIn, systemImage: CircuitProSymbols.Generic.plus)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }

    private func zoomButton(action: @escaping () -> Void, systemImage: String) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 13, height: 13)
                .fontWeight(.light)
                .contentShape(Rectangle())
        }
    }
}
