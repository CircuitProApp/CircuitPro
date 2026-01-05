//
//  Grid.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/5/25.
//

import AppKit
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
    var gridPrimaryColor: CGColor
    var textColor: CGColor
    var sheetMarkerColor: CGColor
    var crosshairColor: CGColor

    static let `default` = CanvasTheme(
        backgroundColor: CGColor(gray: 1, alpha: 1),
        gridPrimaryColor: CGColor(gray: 0.5, alpha: 1),
        textColor: CGColor(gray: 0.1, alpha: 1),
        sheetMarkerColor: CGColor(gray: 0.2, alpha: 1),
        crosshairColor: NSColor.systemBlue.cgColor
    )
}

struct Snapping {
    var isEnabled: Bool = true
    // var snapToGrid: Bool = true
    // var snapToObjects: Bool = false
}

typealias DefinitionTextResolver = (_ text: CircuitText.Definition) -> String

private struct ConfigurationKey: CanvasEnvironmentKey {
    static let defaultValue = CanvasConfiguration()
}

private struct CanvasThemeKey: CanvasEnvironmentKey {
    static let defaultValue = CanvasTheme.default
}

private struct MarqueeRectKey: CanvasEnvironmentKey {
    static let defaultValue: CGRect? = nil
}

private struct TextTargetKey: CanvasEnvironmentKey {
    static let defaultValue: TextTarget = .symbol
}

private struct DefinitionTextResolverKey: CanvasEnvironmentKey {
    static let defaultValue: DefinitionTextResolver? = nil
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

    var textTarget: TextTarget {
        get { self[TextTargetKey.self] }
        set { self[TextTargetKey.self] = newValue }
    }

    var definitionTextResolver: DefinitionTextResolver? {
        get { self[DefinitionTextResolverKey.self] }
        set { self[DefinitionTextResolverKey.self] = newValue }
    }

    var interactionMode: CanvasInteractionMode {
        get { self[InteractionModeKey.self] }
        set { self[InteractionModeKey.self] = newValue }
    }

    func withInteractionMode(_ mode: CanvasInteractionMode) -> CanvasEnvironmentValues {
        var copy = self
        copy.interactionMode = mode
        return copy
    }

    func withTextTarget(_ target: TextTarget) -> CanvasEnvironmentValues {
        var copy = self
        copy.textTarget = target
        return copy
    }

    func withDefinitionTextResolver(_ resolver: DefinitionTextResolver?) -> CanvasEnvironmentValues {
        var copy = self
        copy.definitionTextResolver = resolver
        return copy
    }

    // Renderables removed; canvas items should live in the graph.
}
