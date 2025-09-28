//
//  CircuitProSymbols.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/6/25.
//

import SwiftUI

struct CircuitProSymbols: RawRepresentable,
                         ExpressibleByStringLiteral,
                         Hashable, CustomStringConvertible {

    let rawValue: String
    init(rawValue: String) { self.rawValue = rawValue }
    init(stringLiteral value: StringLiteralType) { self.rawValue = value }

    var description: String { rawValue }
}

// MARK: – SwiftUI convenience

extension Image {
    /// `Image(symbol: .Generic.plus)`
    init(symbol: CircuitProSymbols) { self.init(systemName: symbol.rawValue) }
}


extension CircuitProSymbols {
    enum Generic {
        static let plus = "plus"
        static let minus = "minus"
        static let gear = "gearshape"
        static let info = "info"
        static let xmark = "xmark"
        static let tray = "tray"
        static let eye = "eye"
        static let chevronDown = "chevron.down"
        static let chevronRight = "chevron.right"
        static let checkmark = "checkmark"
        static let arrowUpRight = "arrow.up.right"
        static let questionmark = "questionmark"
        static let exclamationmark = "exclamationmark"
        static let trash = "trash"
        static let folder = "folder"
    }
    
    enum Workspace {
        static let toggleUtilityArea = "inset.filled.bottomthird.square"
        static let projectNavigator = "list.bullet"
        static let directoryExplorer = "folder"
        static let ruleChecks = "exclamationmark.triangle"
        static let feedbackBubble = "exclamationmark.bubble"
        static let sidebarLeading = "sidebar.leading"
        static let sidebarTrailing = "sidebar.trailing"
    }
    
    enum Canvas {
        static let crosshairs = "dot.scope"
        static let snapping = "dot.squareshape.split.2x2"
        static let backgroundType = "viewfinder.rectangular"
        static let dottedBackground = "squareshape.dotted.split.2x2"
        static let gridBackground = "grid"
        static let axesBackground = "arrow.up.and.down.and.arrow.left.and.right"
        static let gridUnitScaleMedium = "squareshape.split.3x3.badge.magnifyingglass"
        static let gridUnitScaleSmall = "squareshape.split.2x2.badge.magnifyingglass"
    }
    
    enum Layout {
        static let layoutLayers = "square.3.layers.3d"
        static let layoutNets = "point.3.connected.trianglepath.dotted"
    }
    
    enum Schematic {
        static let wire = "schematic.wire"
    }
    
    enum Text {
        static let textBox = "character.textbox"
        static let textBoxSparkle = "character.textbox.badge.sparkles"
    }
    
    enum Graphic {
        static let line = "line.diagonal"
        static let rectangle = "rectangle"
        static let circle = "circle"
        
        static let cursor = "cursorarrow"
        static let ruler = "ruler"
    }
    
    enum Design {
        static let design = "book.pages.fill"
    }
    
    enum Symbol {
        static let pin = "mappin"
    }
    
    enum Footprint {
        static let pad = "dot.squareshape.fill"
    }
    
    enum ComponentParts {
        static let symbol = "dollarsign"
        static let footprint = "pawprint"
        static let model3D = "view.3d"
        static let model3d = "cube"
    }
    
    enum Project {
        static let board = "square"
        static let schematic = "waveform.path.ecg.rectangle"
        static let layout = "rectangle.3.group"
    }
}
