//
//  CanvasHitTestControllerDataSource.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 12.07.25.
//

import Foundation

protocol CanvasHitTestControllerDataSource: AnyObject {
    func elementsForHitTesting() -> [CanvasElement]
    func magnificationForHitTesting() -> CGFloat
}