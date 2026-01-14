//
//  Grid.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/5/25.
//

import AppKit
import CoreGraphics

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

struct SchematicTheme {
    var symbolColor: CGColor
    var pinColor: CGColor
    var textColor: CGColor
    var wireColor: CGColor

    static let `default` = SchematicTheme(
        symbolColor: NSColor.labelColor.cgColor,
        pinColor: NSColor.systemBlue.cgColor,
        textColor: NSColor.labelColor.cgColor,
        wireColor: NSColor.systemBlue.cgColor
    )
}

struct Snapping {
    var isEnabled: Bool = true
    // var snapToGrid: Bool = true
    // var snapToObjects: Bool = false
}

typealias DefinitionTextResolver = (_ text: CircuitText.Definition) -> String

private struct GridKey: CanvasEnvironmentKey {
    static let defaultValue = CanvasGrid()
}

private struct SnappingKey: CanvasEnvironmentKey {
    static let defaultValue = Snapping()
}

private struct CrosshairsStyleKey: CanvasEnvironmentKey {
    static let defaultValue = CrosshairsStyle.centeredCross
}

private struct CanvasThemeKey: CanvasEnvironmentKey {
    static let defaultValue = CanvasTheme.default
}

private struct SchematicThemeKey: CanvasEnvironmentKey {
    static let defaultValue = SchematicTheme.default
}

private struct TextTargetKey: CanvasEnvironmentKey {
    static let defaultValue: TextTarget = .symbol
}

private struct DefinitionTextResolverKey: CanvasEnvironmentKey {
    static let defaultValue: DefinitionTextResolver? = nil
}

extension CanvasEnvironmentValues {
    var grid: CanvasGrid {
        get { self[GridKey.self] }
        set { self[GridKey.self] = newValue }
    }

    var snapping: Snapping {
        get { self[SnappingKey.self] }
        set { self[SnappingKey.self] = newValue }
    }

    var crosshairsStyle: CrosshairsStyle {
        get { self[CrosshairsStyleKey.self] }
        set { self[CrosshairsStyleKey.self] = newValue }
    }

    var canvasTheme: CanvasTheme {
        get { self[CanvasThemeKey.self] }
        set { self[CanvasThemeKey.self] = newValue }
    }

    var schematicTheme: SchematicTheme {
        get { self[SchematicThemeKey.self] }
        set { self[SchematicThemeKey.self] = newValue }
    }

    var textTarget: TextTarget {
        get { self[TextTargetKey.self] }
        set { self[TextTargetKey.self] = newValue }
    }

    var definitionTextResolver: DefinitionTextResolver? {
        get { self[DefinitionTextResolverKey.self] }
        set { self[DefinitionTextResolverKey.self] = newValue }
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
