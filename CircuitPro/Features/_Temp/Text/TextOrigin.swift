//
//  TextOrigin.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/2/25.
//

import SwiftUI

/// The origin of a resolved text object, crucial for saving edits correctly.
enum TextOrigin: Hashable {
    case definition(definitionID: UUID)
    case instance(instanceID: UUID)
}

