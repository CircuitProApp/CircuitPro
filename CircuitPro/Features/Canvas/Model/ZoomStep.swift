//
//  ZoomStep.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//

import SwiftUI

enum ZoomStep: CGFloat, Displayable, Comparable {
    // swiftlint:disable identifier_name
//  case x0_1 = 0.1
    case x0_25 = 0.25
    case x0_5 = 0.5
    case x0_75 = 0.75
    case x1 = 1.0
    case x1_25 = 1.25
    case x1_5 = 1.5
    case x2 = 2.0
    case x3 = 3.0
    case x4 = 4.0
    case x5 = 5.0
    case x10 = 10.0
    case x25 = 25.0
    // swiftlint:enable identifier_name

    static func < (lhs: ZoomStep, rhs: ZoomStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let percent = rawValue * 100
        return "\(formatter.string(from: NSNumber(value: Double(percent))) ?? "\(Int(percent))")%"
    }
}

extension ZoomStep {
    static var sortedSteps: [ZoomStep] {
        allCases.sorted()
    }

    static var minZoom: CGFloat {
        sortedSteps.first!.rawValue
    }

    static var maxZoom: CGFloat {
        sortedSteps.last!.rawValue
    }

    static var allRawValues: [CGFloat] {
        sortedSteps.map(\.rawValue)
    }
}
