//
//  ComponentDesignManager.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/19/25.
//

import SwiftUI

private struct ComponentDesignManagerKey: EnvironmentKey {
    static let defaultValue: ComponentDesignManager = ComponentDesignManager()
}

extension EnvironmentValues {
    var componentDesignManager: ComponentDesignManager {
        get { self[ComponentDesignManagerKey.self] }
        set { self[ComponentDesignManagerKey.self] = newValue }
    }
}
