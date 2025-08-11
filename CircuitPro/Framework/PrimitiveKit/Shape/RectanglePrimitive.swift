//
//  RectanglePrimitive.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//

import CoreGraphics

public struct RectanglePrimitive: Codable, Hashable {
    public var size: CGSize
    public var cornerRadius: CGFloat

    public init(size: CGSize, cornerRadius: CGFloat) {
        self.size = size
        self.cornerRadius = cornerRadius
    }
    
    public var maximumCornerRadius: CGFloat {
        return min(size.width, size.height) / 2
    }
}
