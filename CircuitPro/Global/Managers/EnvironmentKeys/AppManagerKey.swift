//
//  AppManagerKey.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/17/25.
//

import SwiftUI

private struct AppManagerKey: EnvironmentKey {
    static let defaultValue: AppManager = AppManager()
}

extension EnvironmentValues {
    var appManager: AppManager {
        get { self[AppManagerKey.self] }
        set { self[AppManagerKey.self] = newValue }
    }
}
