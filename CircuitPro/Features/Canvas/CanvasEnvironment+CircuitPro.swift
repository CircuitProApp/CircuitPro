//
//  Grid.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/5/25.
//


import CoreGraphics

struct CanvasConfiguration {
    var grid = CanvasGrid()
    var snapping = Snapping()
    var crosshairsStyle = CrosshairsStyle.centeredCross
    // Future settings go here, e.g.:
    // var theme = Theme()
    // var guides = Guides()
}

struct CanvasGrid {
    var spacing: GridSpacing = .mm1
    var majorLineInterval: Int = 10
    var isVisible: Bool = true
}

struct Snapping {
    var isEnabled: Bool = true
    // var snapToGrid: Bool = true
    // var snapToObjects: Bool = false
}

private struct ConfigurationKey: CanvasEnvironmentKey {
    static let defaultValue = CanvasConfiguration()
}

private struct MarqueeRectKey: CanvasEnvironmentKey {
    static let defaultValue: CGRect? = nil
}

private struct WireGraphKey: CanvasEnvironmentKey {
    static let defaultValue: WireGraph? = nil
}

extension CanvasEnvironmentValues {
    var configuration: CanvasConfiguration {
        get { self[ConfigurationKey.self] }
        set { self[ConfigurationKey.self] = newValue }
    }

    var marqueeRect: CGRect? {
        get { self[MarqueeRectKey.self] }
        set { self[MarqueeRectKey.self] = newValue }
    }

    var wireGraph: WireGraph? {
        get { self[WireGraphKey.self] }
        set { self[WireGraphKey.self] = newValue }
    }

    func withWireGraph(_ graph: WireGraph?) -> CanvasEnvironmentValues {
        var copy = self
        copy.wireGraph = graph
        return copy
    }
}
