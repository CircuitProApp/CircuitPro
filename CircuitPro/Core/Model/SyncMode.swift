//
//  SyncMode.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/17/25.
//

import Foundation

/// Defines the operational mode for how changes are applied to the main data model.
enum SyncMode {
    /// Changes are applied immediately to the data model.
    case automatic
    
    /// Changes are recorded and must be manually applied by the user via an ECO timeline.
    case manualECO
}
