//
//  PropertySource.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/2/25.
//

import Foundation

/// Represents the source of a resolved property, which is crucial for determining how to save edits.
enum PropertySource: Hashable {
    /// The property is defined in the component library and has a stable definition ID.
    case definition(definitionID: UUID)
    /// The property is an ad-hoc creation, unique to this component instance.
    case instance(instanceID: UUID)
}
