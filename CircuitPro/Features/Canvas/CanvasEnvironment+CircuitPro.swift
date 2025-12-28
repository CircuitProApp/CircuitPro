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
}

struct CanvasGrid {
    var spacing: GridSpacing = .mm1
    var majorLineInterval: Int = 10
    var isVisible: Bool = true
}

struct CanvasTheme {
    var backgroundColor: CGColor
    var gridDotColor: CGColor

    static let `default` = CanvasTheme(
        backgroundColor: CGColor(gray: 1, alpha: 1),
        gridDotColor: CGColor(gray: 0.5, alpha: 1)
    )
}

struct Snapping {
    var isEnabled: Bool = true
    // var snapToGrid: Bool = true
    // var snapToObjects: Bool = false
}

private struct ConfigurationKey: CanvasEnvironmentKey {
    static let defaultValue = CanvasConfiguration()
}

private struct CanvasThemeKey: CanvasEnvironmentKey {
    static let defaultValue = CanvasTheme.default
}

private struct MarqueeRectKey: CanvasEnvironmentKey {
    static let defaultValue: CGRect? = nil
}

private struct WireEngineKey: CanvasEnvironmentKey {
    static let defaultValue: WireEngine? = nil
}

private struct TraceEngineKey: CanvasEnvironmentKey {
    static let defaultValue: TraceEngine? = nil
}

enum CanvasInteractionMode {
    case graphAndScene
    case graphOnly
}

private struct InteractionModeKey: CanvasEnvironmentKey {
    static let defaultValue = CanvasInteractionMode.graphAndScene
}

extension CanvasEnvironmentValues {
    var configuration: CanvasConfiguration {
        get { self[ConfigurationKey.self] }
        set { self[ConfigurationKey.self] = newValue }
    }

    var canvasTheme: CanvasTheme {
        get { self[CanvasThemeKey.self] }
        set { self[CanvasThemeKey.self] = newValue }
    }

    var marqueeRect: CGRect? {
        get { self[MarqueeRectKey.self] }
        set { self[MarqueeRectKey.self] = newValue }
    }

    var wireEngine: WireEngine? {
        get { self[WireEngineKey.self] }
        set { self[WireEngineKey.self] = newValue }
    }

    var traceEngine: TraceEngine? {
        get { self[TraceEngineKey.self] }
        set { self[TraceEngineKey.self] = newValue }
    }

    var interactionMode: CanvasInteractionMode {
        get { self[InteractionModeKey.self] }
        set { self[InteractionModeKey.self] = newValue }
    }

    func withWireEngine(_ engine: WireEngine?) -> CanvasEnvironmentValues {
        var copy = self
        copy.wireEngine = engine
        return copy
    }

    func withTraceEngine(_ engine: TraceEngine?) -> CanvasEnvironmentValues {
        var copy = self
        copy.traceEngine = engine
        return copy
    }

    func withInteractionMode(_ mode: CanvasInteractionMode) -> CanvasEnvironmentValues {
        var copy = self
        copy.interactionMode = mode
        return copy
    }
}
